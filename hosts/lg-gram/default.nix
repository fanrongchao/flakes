{config, pkgs, lib, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    ../../profiles/container-runtime
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];

  containerRuntime = {
    enable = true;
    dockerCompat = true;
  };
}
