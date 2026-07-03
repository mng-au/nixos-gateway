{ config, pkgs, hostVars, ... }:

{
    services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "${hostVars.ipLan1Cidr}"
      "${hostVars.ipLan2Cidr}"
    ];
    bantime = "24h";
  };
}
