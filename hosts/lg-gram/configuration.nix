# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  # enable flake
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "lg-gram"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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

  # 2) 固件（建议明确加上）
  hardware.enableAllFirmware = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # 3) 用更新的内核（非常关键：新平台/新网卡）
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # 4) 常见 Intel 蓝牙问题：禁用 btusb autosuspend（可显著提高成功率）
  boot.kernelParams = [ "btusb.enable_autosuspend=0" ];

  # 5) blueman 可有可无（不冲突，但不是根因）
  services.blueman.enable = true;

  # 6) 工具（方便排查）
  # Audio: PipeWire with PulseAudio compatibility
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.pulseaudio.enable = false;

  # Speaker amp init for ALC298 on some LG Gram models.
  systemd.services.alc298-speaker-fix = let
    verbs = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/joshuagrisham/galaxy-book2-pro-linux/main/sound/necessary-verbs.sh";
      hash = "sha256-vH2jn8rgznzmKZA96DVaLX0wMB+Cu7uIU4cyP1fSqcc=";
    };
    fixScript = pkgs.writeShellScript "alc298-speaker-fix" ''
      set -euo pipefail
      if [ ! -e /dev/snd/hwC0D0 ]; then
        exit 0
      fi
      export PATH=${pkgs.alsa-tools}/bin:$PATH
      ${pkgs.bash}/bin/bash ${verbs}
    '';
  in {
    description = "ALC298 speaker initialization (hda-verb)";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = fixScript;
    };
  };




  # Touchpad: flip scroll direction (natural scrolling).
  services.libinput = {
    enable = true;
    touchpad.naturalScrolling = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.frc = {
    isNormalUser = true;
    description = "Rongchao Fan";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Allow wheel (including frc) to use sudo without a password.
  security.sudo.wheelNeedsPassword = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    alsa-utils
    easyeffects
    #bluetooth utils
    bluez
  #  wget
  ];
  # Install clash-verge
  programs.clash-verge = {
    enable = true;
    tunMode = true;
    serviceMode = true;
    autoStart = false;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
