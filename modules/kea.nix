{ config, pkgs, hostVars, ... }:

{
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [
          "${hostVars.ifLan1}"
        ];
      };
      lease-database = {
        name = "/var/lib/kea/dhcp4.leases";
        persist = true;
        type = "memfile";
      };
      rebind-timer = 2000;
      renew-timer = 1000;
      subnet4 = [
        {
          id = 1;
          pools = [
            {
              pool = "${hostVars.ipLan1DhcpRange}";
            }
          ];
          subnet = "${hostVars.ipLan1Cidr}";
        }
      ];
      valid-lifetime = 4000;
      option-data = [
        {
          name = "routers";
          data = "${hostVars.ipLan1}";
        }
        {
          name = "domain-name-servers";
          data = "${hostVars.ipLan1}";
        }
      ];
    };
  };
}