{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-26.05
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"; # Stable channel
  };
  outputs = inputs@{ self, nixpkgs, nix-flatpak, ... }: {
    # NOTE: 'nixos' is the default hostname

    # Gateway 2
    nixosConfigurations.gateway-2 = nixpkgs.lib.nixosSystem {
      modules = [
        ./hosts/gateway-2/configuration.nix
      ];
    };
  };
}
