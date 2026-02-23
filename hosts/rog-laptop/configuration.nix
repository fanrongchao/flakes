# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "rog-laptop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://192.168.1.251:7897";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

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

  # Allow wheel (including frc) to use sudo without a password.
  security.sudo.wheelNeedsPassword = false;

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Install clash-verge
  programs.clash-verge = {
    enable = true;
    tunMode = true;
    serviceMode = true;
    autoStart = false;
  };
  # Install git
  programs.git = {
    enable = true;
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    pciutils
    cudaPackages.cudatoolkit
    mesa-demos
    asusctl
  #  wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  services.asusd.enable = true;

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
  
  #install nvidia driver
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.blacklistedKernelModules = [ "nouveau" ];

  # This host currently runs X11 + dwm with PRIME offload.
  # Forcing NVIDIA GLX/GBM variables globally can break X11 apps that need a GL
  # context (kitty was failing with GLXBadFBConfig). Keep only generic vars here.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  hardware.nvidia = {
    # 必须项
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    nvidiaSettings = true;

    # 必须关闭 open 驱动
    open = false;

    powerManagement.enable = false;

    ########################################
    # PRIME（Intel + NVIDIA 双显卡）
    ########################################
    prime = {
      # offload 模式：显示走 Intel，算力走 NVIDIA
      offload.enable = true;
      offload.enableOffloadCmd = true;

      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  hardware.graphics = {
    enable = true;
  };

}
