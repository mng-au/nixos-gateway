{ config, pkgs, lib, sops, hostVars, ... }:

let
  env = name: builtins.getEnv name;

  getDomainByEnv = index: {
    name = env "NGINX_DOMAIN_${toString index}";
    dest_host = env "NGINX_DOMAIN_${toString index}_DEST_HOST";
  };

  domains = {
    "1" = getDomainByEnv 1;

    authelia = getDomainByEnv "AUTHELIA";
    forgejo = getDomainByEnv "FORGEJO";
    filebrowser = getDomainByEnv "FILEBROWSER";
    freshrss = getDomainByEnv "FRESHRSS";
    grafana = getDomainByEnv "GRAFANA";
    homepage = getDomainByEnv "HOMEPAGE";
    jellyfin = getDomainByEnv "JELLYFIN";
    kavita = getDomainByEnv "KAVITA";
    kestra = getDomainByEnv "KESTRA";
    keycloak = getDomainByEnv "KEYCLOAK";
    komodo = getDomainByEnv "KOMODO";
    netbird = {
      name = env "NGINX_DOMAIN_NETBIRD";
      dashboard_host = env "NGINX_DOMAIN_NETBIRD_DASHBOARD_HOST";
      signal_host = env "NGINX_DOMAIN_NETBIRD_SIGNAL_HOST";
      management_host = env "NGINX_DOMAIN_NETBIRD_MANAGEMENT_HOST";
      relay_host = env "NGINX_DOMAIN_NETBIRD_RELAY_HOST";
    };
    nocodb = getDomainByEnv "NOCODB";
    vaultWarden = getDomainByEnv "VAULTWARDEN";
    uptimeKuma = getDomainByEnv "UPTIMEKUMA";
    webdav = getDomainByEnv "WEBDAV";
  };

  snippets = {
    hsts = pkgs.writeText "nginx_hsts.conf" ''
       # Add HSTS header with preloading to HTTPS requests.
       # Adding this header to HTTP requests is discouraged
       map $scheme $hsts_header {
           https   "max-age=31536000; includeSubDomains; preload";
       }
       add_header Strict-Transport-Security $hsts_header;

       # Enable CSP for your services.
       #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

       # Minimize information leaked to other domains
       add_header 'Referrer-Policy' 'origin-when-cross-origin';

       # Disable embedding as a frame
       add_header X-Frame-Options DENY;

       # Prevent injection of code in other mime types (XSS Attacks)
       add_header X-Content-Type-Options nosniff always;

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
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
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
        allow  172.16.0.0/12; # docker
        deny   all;
    '';

    authelia_location = pkgs.writeText "nginx_authelia_location.conf" ''
        set $upstream_authelia http://${domains.authelia.dest_host}/api/verify;

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
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
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
        error_page 401 =302 https://${domains.authelia.name}/?rd=$target_url;
    '';
  };

  getDomainNames = builtins.map (entry: entry.value.name) (lib.attrsToList domains);

  getSslHost = locations: {
    inherit locations;

    forceSSL = true;
    useACMEHost = vars.acme_domain;
  };

  getProxyHostByDestHost = host: getSslHost {
    "/".proxyPass = "http://" + host + "/";
    "/".extraConfig = ''
        include ${snippets.proxy};
    '';
  };

  getInternalProxiedHostByDomain = domain: {
    forceSSL = true;
    useACMEHost = vars.acme_domain;
    extraConfig = ''
      include ${snippets.internal_only};
    '';
    locations."/" = {
      proxyPass = "http://" + domain.dest_host + "/";
      extraConfig = ''
        include ${snippets.proxy};
      '';
    };
  };

  getInternalProxiedHostWithAuthByDomain = domain: {
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

  virtualHostFactories = {
    authelia = domain: {
      "${domain.name}" = getProxyHostByDestHost domain.dest_host;
    };

    filebrowser = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    forgejo = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    freshrss = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    grafana = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    homepage = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    jellyfin = domain: {
      "${domain.name}" = (lib.recursiveUpdate (getInternalProxiedHostWithAuthByDomain domain) {
        locations."/socket" = {
          proxyPass = "http://${domain.dest_host}";
          proxyWebsockets = true;
        };
      });
    };

    keycloak = domain: {
      "${domain.name}" = getProxyHostByDestHost domain.dest_host;
    };

    kavita = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    kestra = domain: {
      "${domain.name}" = getInternalProxiedHostWithAuthByDomain domain;
    };

    komodo = domain: {
      "${domain.name}" = lib.recursiveUpdate (getInternalProxiedHostWithAuthByDomain domain) {
        locations."/ws" = {
          proxyPass = "http://${domain.dest_host}";
          proxyWebsockets = true;
        };
      };
    };

    netbird = netbirdDomain: {
      "${netbirdDomain.name}" = lib.recursiveUpdate (getProxyHostByDestHost netbirdDomain.dashboard_host) {
          # This is necessary so that grpc connections do not get closed early
          # see https://stackoverflow.com/a/67805465
          extraConfig = ''
            client_header_timeout 1d;
            client_body_timeout 1d;
          '';

          locations = {
            # Dashboard
            # Using upstream declaration

            # Signal WS
            "/ws-proxy/signal" = {
              proxyPass = "http://${netbirdDomain.signal_host}";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_read_timeout 1d;
              '';
            };

            # Signal gRPC
            "/signalexchange.SignalExchange/" = {
              extraConfig = ''
                grpc_pass grpc://${netbirdDomain.signal_host};
                grpc_ssl_verify off;
                grpc_read_timeout 1d;
                grpc_send_timeout 1d;
                grpc_socket_keepalive on;
              '';
            };

            # Management API
            "/api" = {
              proxyPass = "http://${netbirdDomain.management_host}";
            };

            # Management WS
            "/ws-proxy/management" = {
              proxyPass = "http://${netbirdDomain.management_host}";
              proxyWebsockets = true;
            };

            # Management grpc endpoint
            "/management.ManagementService/" = {
              extraConfig = ''
                grpc_pass grpc://${netbirdDomain.management_host};
                grpc_ssl_verify off;
                grpc_read_timeout 1d;
                grpc_send_timeout 1d;
                grpc_socket_keepalive on;
              '';
            };

            # Relay
            "/relay" = {
              proxyPass = "http://${netbirdDomain.relay_host}";
              proxyWebsockets = true;
            };
          };
        };
    };

    nocodb = domain: {
      "${domain.name}" = (
        lib.recursiveUpdate (getInternalProxiedHostByDomain domain) {
          locations."/" = {
            proxyWebsockets = true;
          };
        }
      );
    };

    uptimeKuma = domain: {
      "${domain.name}" = (
        lib.recursiveUpdate (getProxyHostByDestHost domain.dest_host) {
          locations."/api" = {
            proxyPass = "http://${domain.dest_host}";
            proxyWebsockets = true;
          };
        }
      );
    };

    vaultWarden = domain: {
      "${domain.name}" = (lib.recursiveUpdate
        (getProxyHostByDestHost domain.dest_host)
        {
          extraConfig = ''
            include ${snippets.internal_only};
          '';
        }
      );
    };

    webdav = domain: {
      "${domain.name}" = (
        lib.recursiveUpdate (getProxyHostByDestHost domain.dest_host) {
          locations."/" = {
            extraConfig = ''
              include ${snippets.proxy};

              # Ensure COPY and MOVE commands work
              set $dest $http_destination;
              if ($http_destination ~ "^https://${domain.name}/(?<path>(.+))") {
                set $dest /$path;
              }
              proxy_set_header Destination $dest;
            '';
          };
        }
      );
    };

    private_1 = domain: {
      "${domain.name}" = (lib.recursiveUpdate (getInternalProxiedHostWithAuthByDomain domain) {
        locations."/api/graphql" = {
          proxyPass = "http://${domain.dest_host}";
          proxyWebsockets = true;
        };
      });
    };
  };

  vars = {
    acme_domain = env "ACME_DOMAIN";
    acme_default_email = env "ACME_DEFAULT_EMAIL";
  };
in
{
  ## Add domains as localhost to /etc/hosts
  networking.hosts = {
    "127.0.0.1" = getDomainNames;
  };

  ## Settings fro LetsEncrypt SSL certificate
  users.groups.acme = { };
  users.users.acme = {
    isSystemUser = true;
    group = "acme";
  };

  sops.secrets."cloudflare/dns_api_key" = { }; # Must declare the secret first
  sops.templates."cloudflare.env" = {
    content = ''
      CLOUDFLARE_DNS_API_TOKEN='${config.sops.placeholder."cloudflare/dns_api_key"}'
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

  ## Nginx settings
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

      upstream netbird_dashboard {
        server ${domains.netbird.dashboard_host};

        # Improve performance by keeping some connections alive
        keepalive 10;
      }
    '';

    virtualHosts =
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
          lib.recursiveUpdate (getInternalProxiedHostWithAuthByDomain domains."1") {
            locations."/api/graphql" = {
              proxyPass = "http://${domains."1".dest_host}";
              proxyWebsockets = true;
            };
          }
        );
      } //
      virtualHostFactories.authelia domains.authelia //
      virtualHostFactories.forgejo domains.forgejo //
      virtualHostFactories.filebrowser domains.filebrowser //
      virtualHostFactories.freshrss domains.freshrss //
      virtualHostFactories.grafana domains.grafana //
      virtualHostFactories.homepage domains.homepage //
      virtualHostFactories.jellyfin domains.jellyfin //
      virtualHostFactories.kavita domains.kavita //
      virtualHostFactories.kestra domains.kestra //
      virtualHostFactories.keycloak domains.keycloak //
      virtualHostFactories.komodo domains.komodo //
      virtualHostFactories.netbird domains.netbird //
      virtualHostFactories.nocodb domains.nocodb //
      virtualHostFactories.vaultWarden domains.vaultWarden //
      virtualHostFactories.uptimeKuma domains.uptimeKuma //
      virtualHostFactories.private_1 domains."1";
  };
}
