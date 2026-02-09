{ config, pkgs, lib, ... }:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/hypr
    ../../profiles/container-runtime
    ../../profiles/compute-cluster-control-plane.nix
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
