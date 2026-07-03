{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-26.05
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"; # Stable channel

    sops-nix.url = "github:Mic92/sops-nix";       # For secrets
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";  # See https://github.com/mic92/sops-nix
  };
  outputs = inputs@{ self, nixpkgs, sops-nix, ... }: {
    # NOTE: 'nixos' is the default hostname

    # Gateway 2
    nixosConfigurations.gateway-2 = nixpkgs.lib.nixosSystem {
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/gateway-2/configuration.nix
        ./modules/common.nix
        ./modules/btrfs.nix
        ./modules/gateway.nix
        ./modules/adguardhome_custom.nix
        ./modules/adguardhome.nix
        ./modules/kea.nix
        ./modules/fail2ban.nix
        ./modules/netdata.nix
        ./modules/danted.nix
        ./modules/squid.nix
      ];

      specialArgs = {
        hostVars = {
            inetIngressSpeedInMB = "500";
            inetEngressSeeedInMB = "50";

            ifInternet = "enp3s0f0";
            ifLan1 = "enp3s0f1";
            ifLan2 = "enp4s0f0";

            ipDesktop1 = "192.168.11.36";
            ipNginx = "192.168.11.23";
            ipLan1 = "192.168.1.1";          # home
            ipLan1Cidr = "192.168.1.0/24";
            ipLan1DhcpRange = "192.168.1.100 - 192.168.1.200";
            ipLan2 = "192.168.9.1";          # homelab
            ipLan2Cidr = "192.168.8.0/22";
            ipVpnProxy1 = "192.168.11.230";
            ipServer1 = "192.168.11.245";
            ipServer2 = "192.168.11.246";
        };
      };
    };
  };
}
