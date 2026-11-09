{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.watchyourlan ];

  systemd.services.watchyourlan = {
    description = "WatchYourLAN Network IP Scanner";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
  
    # Needs root permissions to capture arp packages via raw sockets
    serviceConfig = {
      ExecStart = "${pkgs.watchyourlan}/bin/WatchYourLAN";
      Restart = "always";
      User = "root";
    };

    # Environment variables for configuration
    environment = {
      IFACES = "enp4s0f0 enp3s0f1";
      TZ = "Australia/Sydney";
    };
  };
}
