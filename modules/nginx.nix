{ config, lib, sops, hostVars,  ... }:

let
  vars = {
    acme_domain = builtins.getEnv "ACME_DOMAIN";
    acme_default_email = builtins.getEnv "ACME_DEFAULT_EMAIL";

    domain_1 = builtins.getEnv "NGINX_DOMAIN_1";
    domain_1_dest_host = "192.168.11.36:4567";
  };

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
in
{
  users.groups.acme = {};
  users.users.acme = {
   isSystemUser = true;
   group = "acme";
  };

  sops.secrets."vars/cloudflare_dns_api_key" = {}; # Must declare the secret first
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
      ${snippets.hsts}
    '';

    # Add any further config to match your needs, e.g.:
    virtualHosts = let
      base = locations: {
        inherit locations;

        forceSSL = true;
        useACMEHost = vars.acme_domain;
      };
      proxy = host: base {
        "/".proxyPass = "http://" + host + "/";
      };
    in {
      "${vars.domain_1}" = lib.recursiveUpdate (proxy vars.domain_1_dest_host) {
          # default = false;
          extraConfig = ''
            ${snippets.internal_only}
            ${snippets.authelia_location}
          '';
          locations."/" = {
            extraConfig = ''
              ${snippets.authelia_authrequest}
            '';
          };
          locations."/api/graphql" = {
            proxyPass = "http://${vars.domain_1_dest_host}";
            proxyWebsockets = true;
          };
       };
    };
  };
}
