nixos-rebuild-build:
  source ./.env && nixos-rebuild build --flake --impure

nixos-rebuild-switch:
  source ./.env && nixos-rebuild switch --flake --impure

sops-edit:
  nix-shell -p sops --run "sops /root/.sops/secrets/vars.yaml"

sops-updatekeys:
  nix-shell -p sops --run "sops updatekeys /root/.sops/secrets/vars.yaml"
