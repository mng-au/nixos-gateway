{ config, pkgs, lib, sops, hostVars, ... }:

let
  env = name: builtins.getEnv name;

  domainEnv = index: {
    name = env "NGINX_DOMAIN_${toString index}";
    dest_host = env "NGINX_DOMAIN_${toString index}_DEST_HOST";
  };

  domains = {
    "1" = domainEnv 1;
    "2" = domainEnv 2;
    "3" = domainEnv 3;
    "4" = domainEnv 4;
    "5" = domainEnv 5;
    "6" = domainEnv 6;
    "7" = domainEnv 7;
    "8" = domainEnv 8;
    "9" = domainEnv 9;
    "10" = domainEnv 10;
    "11" = domainEnv 11;
    "12" = domainEnv 12;
    "13" = domainEnv 13;
    "14" = domainEnv 14;
    "15" = domainEnv 15;

  vars = {
    acme_domain = env "ACME_DOMAIN";
    acme_default_email = env "ACME_DEFAULT_EMAIL";
  };
  snippets = {
    hsts = pkgs.writeText "nginx_hsts.conf" ''
       # Add HSTS header with preloading to HTTPS requests.
       # Adding this header to HTTP requests is discouraged
       map $scheme $hsts_header {
           https   "max-age=31536000; includeSubdomains; preload";
       }
       add_header Strict-Transport-Security $hsts_header;

       # Enable CSP for your services.
       #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

       # Minimize information leaked to other domains
       add_header 'Referrer-Policy' 'origin-when-cross-origin';

       # Disable embedding as a frame
       add_header X-Frame-Options DENY;

       # Prevent injection of code in other mime types (XSS Attacks)
       add_header X-Content-Type-Options nosniff;

       # This might create errors
       proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
     '';

    proxy = pkgs.writeText "nginx_proxy.conf" ''
     ## Headers
     proxy_set_header Host $host;
     proxy_set_header X-Original-URL $scheme://$host$request_uri;
     proxy_set_header X-Forwarded-Proto $scheme;
     proxy_set_header X-Forwarded-Host $host;
     proxy_set_header X-Forwarded-URI $request_uri;
     proxy_set_header X-Forwarded-Ssl on;
     proxy_set_header X-Forwarded-For $remote_addr;
     proxy_set_header X-Real-IP $remote_addr;

     ## Basic Proxy Configuration
     client_body_buffer_size 128k;
     proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; ## Timeout if the real server is dead.
     proxy_redirect  http://  $scheme://;
     proxy_cache_bypass $cookie_session;
     proxy_no_cache $cookie_session;
     proxy_buffers 64 256k;

     ## Trusted Proxies Configuration
     ## Please read the following documentation before configuring this:
     ##     https://www.authelia.com/integration/proxies/nginx/#trusted-proxies-and-integration-security
     # set_real_ip_from 10.0.0.0/8;
     # set_real_ip_from 172.16.0.0/12;
     # set_real_ip_from 192.168.0.0/16;
     # set_real_ip_from fc00::/7;
     real_ip_header X-Forwarded-For;
     real_ip_recursive on;

     ## Advanced Proxy Configuration
     send_timeout 5m;
     proxy_read_timeout 360;
     proxy_send_timeout 360;
     proxy_connect_timeout 360;
    '';

    internal_only = pkgs.writeText "nginx_internal_only.conf" ''
        allow  127.0.0.1;
        allow  192.168.1.0/24;
        allow  192.168.8.0/22;
        allow  100.64.0.0/10;
        allow  192.168.240.0/20; # docker
        allow  172.0.0.0/8; # docker
        deny   all;
    '';

    # TODO: fix upstream value
    authelia_location = pkgs.writeText "nginx_authelia_location.conf" ''
        set $upstream_authelia http://${domains."2".dest_host}/api/verify;

        location /authelia {
          ## Essential Proxy Configuration
          internal;
          proxy_pass $upstream_authelia;

          ## Headers
          ## The headers starting with X-* are required.
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Original-Method $request_method;
          proxy_set_header X-Forwarded-Method $request_method;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $http_host;
          proxy_set_header X-Forwarded-Uri $request_uri;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header Content-Length "";
          proxy_set_header Connection "";

          ## Basic Proxy Configuration
          proxy_pass_request_body off;
          proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
          proxy_redirect http:// $scheme://;
          proxy_http_version 1.1;
          proxy_cache_bypass $cookie_session;
          proxy_no_cache $cookie_session;
          proxy_buffers 4 32k;
          client_body_buffer_size 128k;

          ## Advanced Proxy Configuration
          send_timeout 5m;
          proxy_read_timeout 240;
          proxy_send_timeout 240;
          proxy_connect_timeout 240;
        }
    '';

    ## Send a subrequest to Authelia to verify if the user is authenticated and has permission to access the resource.
    authelia_authrequest = pkgs.writeText "nginx_authelia_authrequest.conf" ''
        auth_request /authelia;

        ## Set the $target_url variable based on the original request.

        ## Comment this line if you're using nginx without the http_set_misc module.
        # set_escape_uri $target_url $scheme://$http_host$request_uri;

        ## Uncomment this line if you're using NGINX without the http_set_misc module.
        set $target_url $scheme://$http_host$request_uri;

        ## Save the upstream response headers from Authelia to variables.
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;

        ## Inject the response headers from the variables into the request made to the backend.
        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;

        ## If the subrequest returns 200 pass to the backend, if the subrequest returns 401 redirect to the portal.
        error_page 401 =302 https://auth.${vars.acme_domain}/?rd=$target_url;
    '';
  };
in
{
  users.groups.acme = { };
  users.users.acme = {
    isSystemUser = true;
    group = "acme";
  };

  sops.secrets."vars/cloudflare_dns_api_key" = { }; # Must declare the secret first
  sops.templates."cloudflare.env" = {
    content = ''
      CLOUDFLARE_DNS_API_TOKEN='${config.sops.placeholder."vars/cloudflare_dns_api_key"}'
    '';
    owner = "acme";
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "${vars.acme_default_email}";
    certs."${vars.acme_domain}" = {
      domain = "${vars.acme_domain}";
      extraDomainNames = [ "*.${vars.acme_domain}" ];
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."cloudflare.env".path;
      reloadServices = [ "nginx" ];
      group = "nginx";
    };
  };

  # From https://wiki.nixos.org/wiki/Nginx#Hardened_setup_with_TLS_and_HSTS_preloading
  services.nginx = {
    enable = true;
    enableReload = true;

    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    # recommendedProxySettings = true; # Conflict with Authelia setup
    recommendedTlsSettings = true;

    appendHttpConfig = ''
      include ${snippets.hsts};
    '';

    virtualHosts =
      let
        sslHost = locations: {
          inherit locations;

          forceSSL = true;
          useACMEHost = vars.acme_domain;
        };

        proxyHostByDestHost = host: sslHost {
          "/".proxyPass = "http://" + host + "/";
        };

        internalProxiedHostByDomain = domain: {
          forceSSL = true;
          useACMEHost = vars.acme_domain;
          extraConfig = ''
            include ${snippets.internal_only};
            include ${snippets.authelia_location};
          '';
          locations."/" = {
            proxyPass = "http://" + domain.dest_host + "/";
            extraConfig = ''
              include ${snippets.proxy};
              include ${snippets.authelia_authrequest};
            '';
          };
        };
      in
      {
        "_" = {
          default = true;
          locations = {
            "/" = {
              return = "404";
            };
          };
        };
        "${domains."1".name}" = (
          lib.recursiveUpdate (internalProxiedHostByDomain domains."1") {
            locations."/api/graphql" = {
              proxyPass = "http://${domains."1".dest_host}";
              proxyWebsockets = true;
            };
          }
        );
        # authelia
        "${domains."2".name}" = (
          lib.recursiveUpdate (proxyHostByDestHost domains."2".dest_host) {
            extraConfig = ''
              include ${snippets.internal_only};
            '';
          }
        );
      };
  };
}
