{ config, pkgs, sops, hostVars,  ... }:

let
  acme_domain = builtins.getEnv "ACME_DOMAIN";
  acme_default_email = builtins.getEnv "ACME_DEFAULT_EMAIL";
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
    defaults.email = "${acme_default_email}";
    certs."${acme_domain}" = {
      domain = "${acme_domain}";
      extraDomainNames = [ "*.${acme_domain}" ];
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."cloudflare.env".path;
    };
  };

  services.nginx = {
    enable = true;
    enableReload = true;
  };
}
