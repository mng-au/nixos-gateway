{ config, pkgs, hostVars, ... }:

{
  services.squid = {
    enable = true;
    extraConfig = ''
      # Rules
      acl localnet src ${hostVars.ipLan2Cidr}
      http_access allow localnet
      http_access deny all

      # Listen
      http_port ${hostVars.ipLan2}:3128

      # Dns
      dns_nameservers 1.1.1.1 1.0.0.1

      # Disable headers
      httpd_suppress_version_string on
      forwarded_for delete
      via off


      # Disable cache
      cache deny all
      cache_dir null /tmp

      # Quick restart
      shutdown_lifetime 5 seconds
    '';
  };
}
