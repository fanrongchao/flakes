{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/network-egress-proxy.nix
    ../../profiles/network-ingress-proxy.nix
    ../../profiles/ingress-haproxy-sni.nix
    ../../profiles/zero-trust-control-plane.nix
    ../../profiles/zero-trust-node.nix
  ];
}
