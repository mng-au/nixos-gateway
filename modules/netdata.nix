{ config, pkgs, ... }:

{
  services.netdata = {
    enable = true;
    config = {
      global = {
        "debug log" = "none";
        "access log" = "none";
        "error log" = "syslog";
      };

      db = {
        "mode" = "ram";
        "history" = "600";
      };
    };
  };
}
