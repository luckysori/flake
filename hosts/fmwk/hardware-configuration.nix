{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "uas" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/bbafc1df-9962-4a92-a239-dfd2f4ea84e4";
    fsType = "btrfs";
    options = ["subvol=@root"];
  };

  boot.initrd.luks.devices."crypted".device = "/dev/disk/by-uuid/d2d9fccc-1fd4-4d97-8ea3-43f7e6e9b691";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A01D-0878";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/bbafc1df-9962-4a92-a239-dfd2f4ea84e4";
    fsType = "btrfs";
    options = ["subvol=@home" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/bbafc1df-9962-4a92-a239-dfd2f4ea84e4";
    fsType = "btrfs";
    options = ["subvol=@nix" "compress=zstd" "noatime"];
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-uuid/bbafc1df-9962-4a92-a239-dfd2f4ea84e4";
    fsType = "btrfs";
    options = ["subvol=@persist" "compress=zstd" "noatime"];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/bbafc1df-9962-4a92-a239-dfd2f4ea84e4";
    fsType = "btrfs";
    options = ["subvol=@log" "compress=zstd" "noatime"];
    neededForBoot = true;
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/7fad24c9-c064-4e7f-a1d3-b25350aba4bb";}
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
