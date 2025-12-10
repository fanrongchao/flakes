{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/network-egress-proxy.nix
  ];
}
