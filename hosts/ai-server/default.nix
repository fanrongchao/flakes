{ config, pkgs, lib, ... }:

let
  site = {
    apexDomain = "zhsjf.cn";
    headscaleHost = "hs.zhsjf.cn";
    tailnetBaseDomain = "tail.zhsjf.cn";
    derpHostname = "derp.zhsjf.cn";
    derpIPv4 = "218.11.1.14";
    publicIPv4 = "218.11.1.14";
    tailnetIPv4 = "100.64.0.3";
    mihomoControllerHost = "mihomo.zhsjf.cn";
  };

  tailnetSuffix = lib.removePrefix "tail." site.tailnetBaseDomain;

  publicIngressUpstreams = {
    "${site.headscaleHost}" = "127.0.0.1:8080";
    "${site.derpHostname}" = "127.0.0.1:8080";
    "git.${site.apexDomain}" = "192.168.3.100:8080";
    "m2.${site.apexDomain}" = "127.0.0.1:8000";
  };

  tailnetIngressVirtualHosts = {
    "${site.mihomoControllerHost}" = {
      upstream = "127.0.0.1:9090";
      bindAddress = site.tailnetIPv4;
    };
  };
in

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
    ../../profiles/ai-relay-services.nix
    ../../profiles/sub2api.nix
    ../../profiles/zero-trust-control-plane.nix
    ../../profiles/zero-trust-node.nix
    ../../profiles/devops-baseline.nix
  ];

  services.aiRelayServices.enable = true;
  services.aiRelayServices.domain = "airs.zhsjf.cn";
  services.sub2api.enable = true;
  services.sub2api = {
    domain = "aiapi.${site.apexDomain}";
    adminEmail = "admin@${site.apexDomain}";
  };
  services.zeroTrustNode.loginServerUrl = "https://${site.headscaleHost}";
  services.zeroTrustControlPlane = {
    serverUrl = "https://${site.headscaleHost}";
    tailnetBaseDomain = site.tailnetBaseDomain;
    derp = {
      hostname = site.derpHostname;
      ipv4 = site.derpIPv4;
    };
  };
  services.networkIngressProxy.virtualHosts =
    (lib.mapAttrs (_: upstream: { inherit upstream; }) publicIngressUpstreams)
    // tailnetIngressVirtualHosts;
  services.ingressHaproxySni = {
    publicHttpBindAddresses = [ "${site.publicIPv4}:80" ];
    publicTlsBindAddresses = [ "${site.publicIPv4}:443" ];
    tlsServerNames = builtins.attrNames publicIngressUpstreams;
    tailnetTlsBindAddresses = [ "${site.tailnetIPv4}:443" ];
    tailnetTlsServerNames = [ site.mihomoControllerHost ];
    tailnetCaddyBackend = "${site.tailnetIPv4}:8443";
    gitSshBackend = "192.168.3.100:2222";
  };
  services.mihomoEgress = {
    mode = "rule";
    snifferPreset = "tun";
    tailscaleCompatible = true;
    tailscaleTailnetSuffixes = [ tailnetSuffix ];
    tailscaleDirectDomains = [
      site.headscaleHost
      site.derpHostname
    ];
    manualServerName = "jp-vultr";
    manualServerAttachGroups = [ "BosLife" ];
    customRules = [
      { domain = "antigravity-unleash.goog"; kind = "suffix"; via = "BosLife"; }
      { domain = "antigravity-auto-updater"; kind = "keyword"; via = "BosLife"; }
    ];
    routeExcludeCidrs = [
      "${site.derpIPv4}/32"
    ];
  };
}
