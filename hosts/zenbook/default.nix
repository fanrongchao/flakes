{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/network-egress-proxy.nix
    ../../profiles/zero-trust-node.nix
  ];
}
