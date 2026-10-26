{ config, pkgs, lib, ... }:

let
  cfg = config.services.nginx;
in
{
  # 1. Declare the options
  options.services.myService = {
    enable = lib.mkEnableOption "Enable my custom service";

    greeting = lib.mkOption {
      type = lib.types.str;
      default = "Hello, NixOS!";
      description = "The greeting string used by the service.";
    };
  };

  # 2. Define the resulting configuration
  config = lib.mkIf cfg.enable {
    # Example: Write a file in /etc using the option
    # environment.etc."my-service-greeting.text".text = cfg.greeting;
  };
}
