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

  networking.hostName = "ai-server"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # add interface to network
  networking.useNetworkd = true;
  networking.interfaces.ens5f0np0 = {
    ipv4.addresses = [
      { 
        address = "192.168.3.111";
        prefixLength = 24;
      }
    ];
  };
  networking.defaultGateway = {
    address = "192.168.3.1";
    interface = "ens5f0np0";
  };
  networking.nameservers = ["8.8.8.8" "1.1.1.1"];
  services.resolved.enable = false;
  # --finish adding

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = false;
  environment.etc."resolv.conf".text = ''
    nameserver 8.8.8.8
    nameserver 1.1.1.1
    options edns0
  '';

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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  #sops
  #sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  #sops.secrets.authorized_keys = {
  #  sopsFile = ../../secrets/authorized_keys.yaml;
  #  neededForUsers = true;
  #};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.xfa = {
    isNormalUser = true;
    description = "XFA";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    hashedPassword = "$6$toGeXv0PFQQfHdcs$aOVEx8Rvet6KyvWA14hHHXklaPRW/arErA83a6MtKZKfEH4xE1RvzxYPgQYAzJTUNmcdtZfzmJZUW1Fjy4Rz7.";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKf2wHEXcRzC89DQP168jR190qJYvnLGL5KDPc9i18Kr frc@rog-laptop-nixos"	
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYn2d7QD2XXmprwG37RDGanwFBRU8Qu1hRDcx1W5uTa fanrongchao@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9OCVuX2JqNJ7JDQNGIcrgOwPe4zMd1qQZHmUzw35g1 f@xfa.cn"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHIOzn2pFMA7MdcC2q6PNQmaWsh1uVDlmVhl1ikuppUn pve-dev-01"
    ];
  };
  programs.zsh.enable = true;
  
  # Enable automatic login for the user.
  services.getty.autologinUser = "xfa";

  security.sudo.wheelNeedsPassword = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    kitty.terminfo
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
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  #static ip no need wait online
  systemd.network.wait-online.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
