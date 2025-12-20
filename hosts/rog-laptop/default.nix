{config, pkgs, ...}:
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];
}
