{ config, pkgs, hostVars, ... }:

{
  services.dante = {
    enable = true;
    config = ''
      logoutput: syslog
      user.privileged: root
      user.unprivileged: nobody
      internal: ${hostVars.ifLan1} port = 1080
      internal: ${hostVars.ifLan2} port = 1080
      external: ${hostVars.ifInternet}
      socksmethod: none
      clientmethod: none

      client pass {
          from: 0.0.0.0/0 to: 0.0.0.0/0
          log: connect disconnect error
      }

      socks pass {
          from: 0.0.0.0/0 to: 0.0.0.0/0
          log: connect disconnect error
      }
    '';
  };
}