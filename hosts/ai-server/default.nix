{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/network-egress-proxy.nix
    ../../profiles/network-ingress-proxy.nix
    ../../profiles/zero-trust-control-plane.nix
    ../../profiles/zero-trust-node.nix
  ];
}
