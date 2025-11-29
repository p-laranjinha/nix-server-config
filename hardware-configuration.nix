{ config, lib, pkgs, modulesPath, ... }: {
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # I could've let disko configure everything, besides /home
  #  (because I have make zfs not mount it, as systemd also
  #  tries to mount it for some reason and causes problems)
  #  including swap, but this is pretty simple, and I don't
  #  really know how disko would work with future disk additions.
  fileSystems = {
    "/home" = {
      device = "zdata/home";
      fsType = "zfs";
    };
    "/" = {
      device = "zroot/root";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/nix" = {
      device = "zroot/nix";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/var" = {
      device = "zroot/var";
      fsType = "zfs";
      options = ["zfsutil"];
    };
    "/boot" = {
      device = "/dev/disk/by-id/nvme-Lexar_SSD_NM620_256GB_QAG282R016101P1157-part1";
      fsType = "vfat";
    };
  };
  swapDevices = [{
    device = "/dev/disk/by-id/nvme-Lexar_SSD_NM620_256GB_QAG282R016101P1157-part2";
  }];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0f0u4.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp9s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
