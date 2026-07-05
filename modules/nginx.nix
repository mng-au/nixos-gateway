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

        ## Basic Proxy Configuration
        proxy_pass_request_body off;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
        proxy_redirect http:// $scheme://;
        proxy_http_version 1.1;
        proxy_cache_bypass $cookie_session;
        proxy_no_cache $cookie_session;
        proxy_buffers 4 32k;
        client_body_buffer_size 128k;

  snippets = import ./nginx_snippets.nix;
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
    recommendedProxySettings = true;
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
          '';
          locations."/" = {
            extraConfig = ''
              ${snippets.authelia_authrequest}
            '';
            proxyPass = "http://" + domain.dest_host + "/";
          };
          locations."/api/graphql" = {
            proxyPass = "http://${vars.domain_1_dest_host}";
            proxyWebsockets = true;
          };
       };
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
      };
  };
}
