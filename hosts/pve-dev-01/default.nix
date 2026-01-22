{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    ../../profiles/workstation-ui/dwm
    ../../profiles/workstation-input.nix
    ../../profiles/container-runtime
  ];

  home-manager.backupFileExtension = "hm-bak";

  # input-leap (client) -> Windows server
  workstation.inputLeap = {
    enable = true;
    server = "192.168.0.150";
    # Start as a system service so mouse/keyboard works on LightDM login screen.
    enablePreLogin = true;
    # Backend is auto-selected in the service (EI if portal is available, else X11).
    extraArgs = [ "--no-tray" "--no-daemon" ];
  };

  containerRuntime = {
    enable = true;
    dockerCompat = true;
  };
}
