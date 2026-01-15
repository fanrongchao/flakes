{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    ../../profiles/workstation-ui/gnome
    ../../profiles/workstation-ui/gnome/auto-login.nix
    ../../profiles/workstation-ui/gnome/gsconnect.nix
    ../../profiles/workstation-input.nix
  ];

  # input-leap (client) -> Windows server
  workstation.inputLeap = {
    enable = true;
    server = "192.168.0.150";
    extraArgs = [ "--no-tray" "--use-x11" ];
  };

  # Avoid RemoteDesktop portal prompts; use Xorg session.
  services.xserver.displayManager.gdm.wayland = false;
}
