{ config, pkgs, lib, ... }:
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/hypr
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/devops-baseline.nix
  ];

  home-manager.backupFileExtension = "bak";
}
