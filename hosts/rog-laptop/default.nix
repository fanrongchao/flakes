{ config, pkgs, lib, ... }:
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/hypr
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];

  home-manager.backupFileExtension = "bak";
}
