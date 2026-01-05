{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/gnome
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];
}
