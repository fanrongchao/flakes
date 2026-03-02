{config, pkgs, lib, ...}:

{
  imports = [
    ./configuration.nix
    ../../profiles/workstation-ui/dwm
    ../../profiles/workstation-input.nix
    ../../profiles/container-runtime
    ../../profiles/network-egress-proxy.nix
    ../../profiles/devops-baseline.nix
    ../../profiles/openclaw-gateway.nix
  ];

  home-manager.backupFileExtension = "hm-bak";
  home-manager.users.frc.home.packages = lib.mkAfter [ pkgs.antigravity ];

  # input-leap (client) -> Windows server
  workstation.inputLeap = {
    enable = true;
    server = "192.168.0.150";
    # Avoid system-level X11 input capture on this host; keep Input Leap in the
    # user session only so dwm focus/click behavior stays local.
    enablePreLogin = false;
    # Backend is auto-selected in the service (EI if portal is available, else X11).
    extraArgs = [ "--no-tray" "--no-daemon" ];
  };

  containerRuntime = {
    enable = true;
    dockerCompat = true;
  };

  # Allow gateway to start before first-time interactive setup so the web UI is reachable.
  home-manager.users.frc.systemd.user.services.openclaw-gateway.Service.ExecStart =
    lib.mkForce "${pkgs.openclaw}/bin/openclaw gateway --port 18789 --bind lan --allow-unconfigured";
}
