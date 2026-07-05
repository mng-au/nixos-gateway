{ config, pkgs, hostVars, sops, ... }:

{
  users.groups.adguardhome = {};
  users.users.adguardhome = {
   isSystemUser = true;
   group = "adguardhome";
  };

  # Create a adguardhome template with secrets
  sops.secrets."adguard/user_password" = {}; # Must declare the secret first
  sops.templates."AdGuardHome.yaml" = {
    content = ''
http:
  address: 0.0.0.0:3000
users:
  - name: user
    password: "${config.sops.placeholder."adguard/user_password"}"
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  upstream_dns:
    - 1.1.1.1
    - 1.0.0.1
filtering:
  protection_enabled: true
  filtering_enabled: true
  parental_enabled: false
    '';
    owner = "adguardhome";
  };

  services.adguardhome = {
    enable = true;
  };
}
