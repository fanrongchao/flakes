# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  #enable flake
  nix.settings.experimental-features = ["nix-command" "flakes"];
  #nix proxy
  systemd.services.nix-daemon.environment = {
    HTTP_PROXY  = "http://192.168.0.150:7897";
    HTTPS_PROXY = "http://192.168.0.150:7897";
    ALL_PROXY   = "socks5://192.168.0.150:7897";
    NO_PROXY    = "127.0.0.1,localhost,192.168.0.0/16";
  };
  environment.variables = {
    HTTP_PROXY  = "http://192.168.0.150:7897";
    HTTPS_PROXY = "http://192.168.0.150:7897";
    ALL_PROXY   = "socks5://192.168.0.150:7897";

    http_proxy  = "http://192.168.0.150:7897";
    https_proxy = "http://192.168.0.150:7897";
    all_proxy   = "socks5://192.168.0.150:7897";

    NO_PROXY    = "127.0.0.1,localhost,::1,192.168.0.0/16";
    no_proxy    = "127.0.0.1,localhost,::1,192.168.0.0/16";
  };

  

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.frc = {
    isNormalUser = true;
    description = "frc";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git

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
  services.openssh.enable = true;
  #nvidia
   # 1️⃣ 禁用 nouveau（必须）
  boot.blacklistedKernelModules = [ "nouveau" ];

  # 2️⃣ NVIDIA 官方驱动
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;   # Wayland 必须
    powerManagement.enable = false;
    open = false;                # RTX 4090 必须 false
    nvidiaSettings = true;
  };

  # 3️⃣ NVIDIA DRM（Wayland 必须）
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
  ];


  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
