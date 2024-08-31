{
  description = "nixlab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    impermanence.url = "github:Nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    valheim-server = {
      url = "github:aidalgol/valheim-server-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    valheim-server,
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
        valheim-server.nixosModules.default
      ];
    };
  };
}
