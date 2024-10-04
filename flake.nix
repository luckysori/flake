{
  description = "Nix stuff";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    impermanence.url = "github:Nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    valheim-server = {
      url = "github:aidalgol/valheim-server-flake";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mysecrets = {
      url = "git+ssh://git@gitea.com/luckysori/nix-secrets.git?ref=main&shallow=1";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-stable,
    valheim-server,
    nixos-hardware,
    treefmt-nix,
    systems,
    rust-overlay,
    ...
  }: let
    configuration = {
      # To get the generation's configuration commit hash when using `nixos-version --configuration-revision`.
      system.configurationRevision = self.rev or "dirty";
    };
    system = "x86_64-linux";

    # Stuff for treefmt.
    # Small tool to iterate over each systems
    eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    # Eval the treefmt modules from ./treefmt.nix
    treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in {
    nixosConfigurations = {
      nixlab = nixpkgs-stable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          configuration
          ./hosts/nixlab
          valheim-server.nixosModules.default
        ];
      };

      fmwk = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          configuration
          ./hosts/fmwk
          ({pkgs, ...}: {
            nixpkgs.overlays = [rust-overlay.overlays.default];
            environment.systemPackages = [pkgs.rust-bin.stable.latest.default];
          })
        ];
      };
    };

    formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
  };
}
