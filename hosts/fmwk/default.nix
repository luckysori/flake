{
  inputs,
  config,
  pkgs,
  ...
}: let
  secretsPath = builtins.toString inputs.mysecrets;
in {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = "${secretsPath}/secrets.yaml";
    # TODO: Replace key.
    age.keyFile = /persist/sops-nix/key.txt;

    secrets."wg-sk/fmwk" = {};
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  nix = {
    settings = let
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.garnix.io"
      ];
    in {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "lucas"];
      extra-substituters = substituters;
      trusted-substituters = substituters;
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {
      lucas = import ./home.nix;
    };
  };

  # Enable the gnome-keyring secrets vault.
  # Will be exposed through DBus to programs willing to store secrets.
  # services.gnome.gnome-keyring.enable = true;

  programs.zsh.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # enable Sway window manager
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  programs.steam.enable = true;
  # NOTE: Taken from hawkw/flake. May not be needed.
  hardware.graphics = {
    extraPackages32 = with pkgs.pkgsi686Linux; [libva];
    enable32Bit = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fmwk";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  console.useXkbConfig = true;

  # To be able to update Framework laptop firmware.
  services.fwupd.enable = true;

  # Fingerprint reader.
  services.fprintd.enable = true;
  security.pam.services.swaylock = {};
  security.pam.services.swaylock.fprintAuth = true;

  # AMD has better battery life with PPD over TLP.
  services.power-profiles-daemon.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment. TODO: Try greetd.
  services.xserver.displayManager.gdm.enable = true;

  # Sound with Pipewire.

  security.rtkit.enable = true;
  hardware.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Bluetooth stuff.

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/home/lucas";
    configDir = "/home/lucas/.config/syncthing";
    user = "lucas";
    group = "users";
  };
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder

  users.users.lucas = {
    isNormalUser = true;
    extraGroups = ["networkmanager" "wheel" "audio" "docker"];
    # I wanted to set this via home-manager, but the login shell is set at the system level.
    shell = pkgs.zsh;
  };

  # Docker stuff.
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    # Prune the docker registry weekly.
    autoPrune.enable = true;
    extraOptions = ''
      --experimental
    '';
  };
  virtualisation.oci-containers = {
    backend = "docker";
  };

  environment.systemPackages = with pkgs; [
    (tree-sitter.withPlugins (_: tree-sitter.allGrammars))
    ((emacsPackagesFor (pkgs.emacs29-pgtk.override {
        withTreeSitter = true;
      }))
      .emacsWithPackages
      (epkgs: [epkgs.vterm epkgs.dap-mode epkgs.treesit-grammars.with-all-grammars]))
    alacritty
    brightnessctl
    calibre
    chromium
    cliphist
    cmake
    delta
    firefox
    fuzzel # Better than rofi.
    fzf
    git
    grim
    home-manager
    ispell
    mako # Notification system developed by swaywm maintainer.
    pavucontrol
    pet
    pipewire
    pulseaudio # To get pactl.
    pulsemixer # This is actually better than pactl.
    # TODO: Maybe we can get rid of this here. We need python for elisp-autofmt, but there must be a
    # better way.
    python3Full
    ripgrep
    slurp
    swappy
    swaylock
    swayr
    waybar
    webcord # Discord client.
    wget
    wl-clipboard
    xdg-desktop-portal-gtk # for waybar to work?
  ];

  fonts.packages = with pkgs; [
    hack-font
  ];

  nixpkgs.config.chromium.commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
  nixpkgs.config.webcord.commandLineArgs = "--enable-features=WaylandWindowDecorations --ozone-platform-hint=wayland --enable-wayland-ime --enable-features=WebRTCPipeWireCapturer";

  programs.ssh.startAgent = true;

  networking.wg-quick.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP/IPv6 address and subnet of the client's end of the tunnel interface
      address = ["10.100.0.2/32"];
      # The port that WireGuard listens to - recommended that this be changed from default
      listenPort = 51820;

      privateKeyFile = config.sops.secrets."wg-sk/fmwk".path;

      peers = [
        {
          # Name = nixlab
          publicKey = "9MDDlDjyXtbzcDkUppxig0MHlXkkCJC/lR26wfBwsw8=";
          allowedIPs = ["10.100.0.1/24"];
          endpoint = "valheim.twiggy.dev:51821";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
