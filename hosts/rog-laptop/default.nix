{config, pkgs, ...}:
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/gnome
    ../../profiles/workstation-ui/gnome/auto-login.nix
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];
}
