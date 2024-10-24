{
  config,
  pkgs,
  inputs,
  ...
}: let
  secretsPath = builtins.toString inputs.mysecrets;
in {
  imports = [
    ./hardware-configuration.nix
    inputs.impermanence.nixosModules.impermanence
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = "${secretsPath}/secrets.yaml";
    age.keyFile = "/persist/sops-nix/key.txt";

    secrets."lucas-password".neededForUsers = true;

    secrets."restic-backups/repo-name" = {};
    secrets."restic-backups/password" = {};

    secrets."restic-backups/env/b2-account-id" = {};
    secrets."restic-backups/env/b2-account-key" = {};
    templates."restic-backups.env" = {
      content = ''
        B2_ACCOUNT_ID=${config.sops.placeholder."restic-backups/env/b2-account-id"}
        B2_ACCOUNT_KEY=${config.sops.placeholder."restic-backups/env/b2-account-key"}
      '';
    };

    secrets."valheim/server" = {};
    secrets."valheim/world" = {};
    secrets."valheim/password" = {};
    secrets."valheim/me" = {};
    secrets."valheim/bb" = {};
    templates."valheim.env" = {
      content = ''
        VALHEIM_SERVER=${config.sops.placeholder."valheim/server"}
        VALHEIM_WORLD=${config.sops.placeholder."valheim/world"}
        VALHEIM_PASS=${config.sops.placeholder."valheim/password"}
        VALHEIM_ME=${config.sops.placeholder."valheim/me"}
        VALHEIM_BB=${config.sops.placeholder."valheim/bb"}
      '';
      owner = "valheim";
    };

    secrets."wg-sk/nixlab" = {};
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = ["ip=dhcp"];
  boot.initrd = {
    # The ethernet driver: `readlink /sys/class/net/eno1/device/driver`
    availableKernelModules = ["e1000e"];
    systemd.users.root.shell = "/bin/cryptsetup-askpass";
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = config.users.users.lucas.openssh.authorizedKeys.keys;
        hostKeys = [
          # TODO: Use dedicated host key during early boot.
          "/persist/etc/ssh/ssh_host_ed25519_key"
        ];
      };
    };
  };

  # Note `lib.mkBefore` is used instead of `lib.mkAfter` here.
  boot.initrd.postDeviceCommands = pkgs.lib.mkBefore ''
    mkdir -p /mnt

    # We first mount the btrfs root to /mnt
    # so we can manipulate btrfs subvolumes.
    mount -o subvol=/ /dev/mapper/enc /mnt

    # While we're tempted to just delete /root and create
    # a new snapshot from /root-blank, /root is already
    # populated at this point with a number of subvolumes,
    # which makes `btrfs subvolume delete` fail.
    # So, we remove them first.
    #
    # /root contains subvolumes:
    # - /root/var/lib/portables
    # - /root/var/lib/machines
    #
    # I suspect these are related to systemd-nspawn, but
    # since I don't use it I'm not 100% sure.
    # Anyhow, deleting these subvolumes hasn't resulted
    # in any issues so far, except for fairly
    # benign-looking errors from systemd-tmpfiles.
    btrfs subvolume list -o /mnt/root |
    cut -f9 -d' ' |
    while read subvolume; do
      echo "deleting /$subvolume subvolume..."
      btrfs subvolume delete "/mnt/$subvolume"
    done &&
    echo "deleting /root subvolume..." &&
    btrfs subvolume delete /mnt/root

    echo "restoring blank /root subvolume..."
    btrfs subvolume snapshot /mnt/root-blank /mnt/root

    # Once we're done rolling back to a blank snapshot,
    # we can unmount /mnt and continue on the boot process.
    umount /mnt
  '';

  console.useXkbConfig = true;

  networking.hostName = "nixos"; # Define your hostname.
  networking.nameservers = ["192.168.1.104"];
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "altgr-intl";
    xkb.options = "ctrl:swapcaps";
  };

  users.mutableUsers = false;
  users.users.lucas = {
    isNormalUser = true;
    description = "Lucas";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.sops.secrets."lucas-password".path;
  };

  security.sudo.extraRules = [
    {
      users = ["lucas"];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["SETENV" "NOPASSWD"];
        }
      ];
    }
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "valheim-server"
      "steamworks-sdk-redist"
    ];

  systemd.services.valheim.serviceConfig.EnvironmentFile = config.sops.templates."valheim.env".path;
  services.valheim = {
    enable = true;
    serverName = "\${VALHEIM_SERVER}";
    worldName = "\${VALHEIM_WORLD}";
    password = "\${VALHEIM_PASS}";
    permittedList = [
      "\${VALHEIM_ME}"
      "\${VALHEIM_BB}"
    ];
    adminList = [
      "\${VALHEIM_ME}"
      "\${VALHEIM_BB}"
    ];
    openFirewall = true;
  };

  networking.nat.enable = true;
  networking.nat.externalInterface = "eth0";
  networking.nat.internalInterfaces = ["wg0"];
  networking.firewall = {
    allowedUDPPorts = [51820];
  };

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = ["10.100.0.1/24"];

      # The port that WireGuard listens to. Must be accessible by the client.
      listenPort = 51820;

      privateKeyFile = config.sops.secrets."wg-sk/nixlab".path;

      peers = [
        # List of allowed peers.
        {
          # Name = me
          publicKey = "NgrNCV+3BQopZkh/ziRDPg/0jNBJAv9j7dc5pmccAGw=";
          allowedIPs = ["10.100.0.2/32"];
        }
        {
          # Name = bb
          publicKey = "l4VsT21UCKPUT7GQNcHSaryAT8v99ecVYkoyWkbv2jI=";
          allowedIPs = ["10.100.0.3/32"];
        }
      ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    wget
    emacs
  ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos/"
      "/etc/NetworkManager/system-connections"
      "/var/lib/valheim"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  services.restic.backups = {
    daily = {
      initialize = true;

      repositoryFile = config.sops.secrets."restic-backups/repo-name".path;
      environmentFile = config.sops.templates."restic-backups.env".path;
      passwordFile = config.sops.secrets."restic-backups/password".path;

      paths = [
        "/persist/"
        "/home/"
      ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];
    };
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/home/lucas";
    configDir = "/home/lucas/.config/syncthing";
    user = "lucas";
    group = "users";

    settings = {
      devices = {
        "desktop" = { id = "BWWBXPV-ULE3ECP-F3534GX-ITNZCLM-4LX4RID-VNSQITK-5MVWOPK-55A3WQD"; };
      };
      folders = {
        "docs" = {
          path = "/home/lucas/docs";
          devices = [ "desktop" ];
        };
      };
    };
  };
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder

  users.users."lucas".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxfASmrb46pekfGht2eINx1+ZsJwbvNm0EE51a1nXOu lucas_soriano@fastmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZ0NsISOxHGxgfRqxPJ231m2JB77paAc0MriW78L3z8 fmwk"
  ];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [22];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
