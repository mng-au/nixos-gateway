{ config, pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Netbird
  services.netbird = {
    enable = true;
  };

  # Shell
  programs.fish.enable = true;

  # Keep bash but start fish. See https://nixos.wiki/wiki/Fish
  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  # Network
  services.resolved.enable = false; # Disable systemd-resolved dns service

  environment.systemPackages = with pkgs; [
    age
    borgbackup
    borgmatic
    btop
    dig
    git
    just
    lazygit
    pciutils    # for lspci
    wget
    tmux
  ];
}
