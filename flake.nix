{
  description = "nixlab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    impermanence.url = "github:Nix-community/impermanence";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    configuration = {
      # To get the generation's configuration commit hash when using `nixos-version --configuration-revision`.
      system.configurationRevision = self.rev or "dirty";
    };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        configuration
        ./configuration.nix
      ];
    };
  };
}
