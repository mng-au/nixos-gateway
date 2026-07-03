{ config, pkgs, ... }:

{
  fileSystems."/".options = [ "compress=zstd" ];
  fileSystems."/home".options = [ "compress=zstd" ];
  fileSystems."/nix".options = [ "compress=zstd" ];
}
