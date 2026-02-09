# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running nixos-help).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # enable flake
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  boot.loader.systemd-boot.xbootldrMountPoint = "/boot";
  # /boot on this device is small; keep only a few generations on the ESP.
  boot.loader.systemd-boot.configurationLimit = 3;

  networking.hostName = "gpd";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  hardware.alsa.enablePersistence = true;

  #bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.enableAllFirmware = true;
  hardware.firmware = [ pkgs.linux-firmware pkgs.sof-firmware ];
  services.udev.packages = [ pkgs.iio-sensor-proxy ];

  # Use a recent kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Common btusb issue workaround.
  boot.kernelParams = [ "btusb.enable_autosuspend=0" ];

  services.blueman.enable = true;

  # Touchpad.
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      tappingButtonMap = "lrm";
      clickMethod = "clickfinger";
    };
  };

  services.accounts-daemon.enable = true;
  services.power-profiles-daemon.enable = true;
  systemd.services.power-profiles-daemon.wantedBy = [ "multi-user.target" ];

  users.users.frc = {
    isNormalUser = true;
    description = "Rongchao Fan";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9OCVuX2JqNJ7JDQNGIcrgOwPe4zMd1qQZHmUzw35g1 f@xfa.cn"
    ];
    packages = with pkgs; [
      # host-specific user packages
    ];
  };

  programs.firefox.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  nixpkgs.config.allowUnfree = true;

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim
    git
    alsa-utils
    easyeffects
    bluez
    bun
    iio-sensor-proxy
  ];

  services.openssh.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "25.05";
}
