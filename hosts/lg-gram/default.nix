{config, pkgs, lib, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    ../../profiles/container-runtime
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/devops-baseline.nix
    ../../profiles/voice-input
  ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];

  containerRuntime = {
    enable = true;
    dockerCompat = true;
  };

  voiceInput = {
    enable = true;
    engine = "fw-streaming";
    model = "medium";
    device = "cpu";
    computeType = "int8";
    hotkey = "meta";
    autoStart = true;
    backend = "x11";
  };
}
