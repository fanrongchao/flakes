{config, pkgs, ...}:

{
  aiInference.vllmMinimaxM2Awq.enable = true;

  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/ai-inference
    ../../profiles/hardware-acceleration.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/network-ingress-proxy.nix
    ../../profiles/ingress-haproxy-sni.nix
    ../../profiles/zero-trust-control-plane.nix
    ../../profiles/zero-trust-node.nix
  ];
}
