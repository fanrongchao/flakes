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
    # Wayland-safe path: use EI backend + RemoteDesktop portal.
    extraArgs = [ "--no-tray" "--use-ei" ];
  };
}
