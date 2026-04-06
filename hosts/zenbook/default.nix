{ config, pkgs, lib, ... }:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/hypr
    ../../profiles/network-egress-proxy.nix
    ../../profiles/zero-trust-node.nix
    ../../profiles/devops-baseline.nix
  ];

  # Host-specific Home Manager overrides go here when needed.
  services.zeroTrustNode.loginServerUrl = "https://hs.zhsjf.cn";
}
