{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-26.05
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"; # Stable channel

    # For secrets
    # See https://github.com/mic92/sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For docker
    compose2nix = {
      url = "github:aksiksi/compose2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Vscode remote editing -- https://github.com/nix-community/nixos-vscode-server
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };
  outputs = inputs@{ self, nixpkgs, sops-nix, vscode-server, ... }: {
    # format nix files
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

    # NOTE: 'nixos' is the default hostname

    # Gateway 2
    nixosConfigurations.gateway-2 = nixpkgs.lib.nixosSystem {
      modules = [
        sops-nix.nixosModules.sops  # For secrets
        # vscode-server.nixosModules.default
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
        ./modules/traefik.nix
      ];

      specialArgs = {
        hostVars = {
            inetIngressSpeedInMB = "500";
            inetEgressSpeedInMB = "50";

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
