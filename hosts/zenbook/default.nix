{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/gnome
    ../../profiles/network-egress-proxy.nix
    ../../profiles/zero-trust-node.nix
  ];
}
