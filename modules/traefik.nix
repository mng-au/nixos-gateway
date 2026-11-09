{ config, pkgs, lib, sops, hostVars, ... }:

let
  env = name: builtins.getEnv name;
  vars = {
    acme_domain = env "ACME_DOMAIN";
    acme_default_email = env "ACME_DEFAULT_EMAIL";
    traefik_redis_password = env "TRAEFIK_REDIS_PASSWORD";
  };

  templateVars = [
    "SERVER_2_DEST_IP"
    "INTERNAL_SUBNET_1"
    "INTERNAL_SUBNET_2"
    "INTERNAL_SUBNET_3"
    "AUTHELIA_DEST_HOST"
    "TRAEFIK_REDIS_PASSWORD"
  ];

  # templateEnv feeds every envsubst template below: the variables read from ./.env,
  # merged with anything derived in Nix (here: the sops placeholder, which sops swaps
  # for the secret at runtime, matching services.redis.servers."traefik".requirePass).
  templateEnv =
    builtins.listToAttrs (map (name: { inherit name; value = env name; }) templateVars)
    // {
      REDIS_PASSWORD_PLACEHOLDER = config.sops.placeholder."cloudflare/dns_api_key";
    };

  missingTemplateVars = builtins.filter (name: templateEnv.${name} == "") templateVars;

  renderTemplate = name: src:
    if missingTemplateVars != [ ] then
      throw "Missing environment variables (${builtins.concatStringsSep " " missingTemplateVars}): source ./.env before running nixos-rebuild --impure"
    else
      pkgs.runCommand name templateEnv ''
        ${pkgs.envsubst}/bin/envsubst -i "${src}" > "$out"
      '';

  aoe_yaml = renderTemplate "aoe.yaml" ./traefik/aoe.yaml;
  authelia_yaml = renderTemplate "authelia.yaml" ./traefik/authelia.yaml;
  static_config_yaml = renderTemplate "static_config.yaml" ./traefik/static_config.yaml;
in {
  # Acme
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
      reloadServices = [ "traefik" ];
      group = "traefik";
    };
  };

  # Redis for Traefik Kop
  services.redis.servers."traefik" = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1 192.168.9.1";
    requirePass = "${vars.traefik_redis_password}";
  };

  # Traefik
  services.traefik = {
    enable = true;
    staticConfigFile = static_config_yaml;
  };

  environment.etc."traefik/dynamic/authelia.yaml" = {
    user = config.systemd.services.traefik.serviceConfig.User;
    group = config.systemd.services.traefik.serviceConfig.Group;
    mode = "600";
    source = authelia_yaml;
  };

  environment.etc."traefik/dynamic/certs.yaml" = {
    user = config.systemd.services.traefik.serviceConfig.User;
    group = config.systemd.services.traefik.serviceConfig.Group;
    mode = "600";
    source = ./traefik/certs.yaml;
  };

  environment.etc."traefik/dynamic/aoe.yaml" = {
    user = config.systemd.services.traefik.serviceConfig.User;
    group = config.systemd.services.traefik.serviceConfig.Group;
    mode = "600";
    source = aoe_yaml;
  };
}
