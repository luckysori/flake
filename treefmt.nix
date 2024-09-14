{...}: {
  # Used to find the project root
  projectRootFile = "flake.nix";
  # Enable the alejandra formatter
  programs.alejandra.enable = true;
}
