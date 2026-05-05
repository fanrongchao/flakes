{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "infra-zero";
  networking.networkmanager.enable = false;
  networking.interfaces.eno1np0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "192.168.3.88";
        prefixLength = 24;
      }
    ];
  };
  networking.defaultGateway = "192.168.3.1";
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.xfa = {
    isNormalUser = true;
    description = "XFA";
    home = "/home/xfa";
    createHome = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDXoqVPBveyZUHa0hUrOUlE3h1HXsqs/cT7TbY4VjLKS XFA AI SERVER"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "25.11";
}
