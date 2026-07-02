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
      ];
    };
  };
}
