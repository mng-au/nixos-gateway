{ config, pkgs, ... }:

{
  services.netalertx = {
    enable = true;
    imageTag = "26.9";
  };
}

