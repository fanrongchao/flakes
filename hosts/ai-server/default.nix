{ config, pkgs, lib, ... }:

let
  site = {
    apexDomain = "zhsjf.cn";
    authHost = "auth.zhsjf.cn";
    headscaleHost = "hs.zhsjf.cn";
    tailnetBaseDomain = "tail.zhsjf.cn";
    derpHostname = "derp.zhsjf.cn";
    aiRelayHost = "airs.zhsjf.cn";
    derpIPv4 = "218.11.1.14";
    ingressIPv4 = "192.168.3.111";
    tailnetIPv4 = "100.64.0.3";
    mihomoControllerHost = "mihomo.zhsjf.cn";
  };

  tailnetSuffix = lib.removePrefix "tail." site.tailnetBaseDomain;

  publicIngressUpstreams = {
    "${site.authHost}" = "127.0.0.1:8081";
    "${site.headscaleHost}" = "127.0.0.1:8080";
    "${site.derpHostname}" = "127.0.0.1:8080";
    "git.${site.apexDomain}" = "192.168.3.100:8080";
    "m2.${site.apexDomain}" = "127.0.0.1:8000";
  };
in

{
  aiInference.vllmMinimaxM2Awq.enable = true;

  networking.hosts."${site.ingressIPv4}" = [
    site.authHost
    site.headscaleHost
  ];

  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/ai-inference
    ../../profiles/hardware-acceleration.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/network-ingress-proxy.nix
    ../../profiles/ingress-haproxy-sni.nix
    ../../profiles/ai-relay-services.nix
    ../../profiles/company-identity-keycloak.nix
    ../../profiles/zero-trust-control-plane.nix
    ../../profiles/zero-trust-node.nix
    ../../profiles/devops-baseline.nix
  ];

  services.aiRelayServices = {
    enable = true;
    domain = site.aiRelayHost;
    bindAddress = site.tailnetIPv4;
  };
  services.zeroTrustNode.loginServerUrl = "https://${site.headscaleHost}";
  services.companyIdentityKeycloak = {
    enable = true;
    host = site.authHost;
    realm = "zhsjf";
    headscaleHost = site.headscaleHost;
  };
  services.zeroTrustControlPlane = {
    serverUrl = "https://${site.headscaleHost}";
    tailnetBaseDomain = site.tailnetBaseDomain;
    derp = {
      hostname = site.derpHostname;
      ipv4 = site.derpIPv4;
    };
    oidc = {
      enable = true;
      issuer = "https://${site.authHost}/realms/zhsjf";
      clientId = "headscale";
      clientSecretFile = config.sops.secrets."headscale/oidc_client_secret".path;
      allowedGroups = [ "headscale_users" ];
      scope = [ "openid" "profile" "email" "groups" ];
      expiry = "30d";
      emailVerifiedRequired = false;
      onlyStartIfOidcIsAvailable = false;
      pkce.enable = true;
    };
  };
  services.networkIngressProxy.virtualHosts =
    lib.mapAttrs (_: upstream: { inherit upstream; }) publicIngressUpstreams;
  services.ingressHaproxySni = {
    publicHttpBindAddresses = [ "${site.ingressIPv4}:80" ];
    publicTlsBindAddresses = [ "${site.ingressIPv4}:443" ];
    tlsServerNames = builtins.attrNames publicIngressUpstreams;
    tailnetHttpBindAddresses = [ "${site.tailnetIPv4}:80" ];
    tailnetTlsBindAddresses = [ "${site.tailnetIPv4}:443" ];
    tailnetTlsServerNames = [
      site.mihomoControllerHost
      site.aiRelayHost
    ];
    tailnetCaddyBackend = "${site.tailnetIPv4}:8443";
    gitSshBackend = "192.168.3.100:2222";
  };
  services.mihomoEgress = {
    mode = "rule";
    snifferPreset = "tun";
    externalControllerBindAddress = "127.0.0.1";
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

  sops.templates."caddy-mihomo-controller.env" = {
    owner = "caddy";
    group = "caddy";
    mode = "0400";
    content = ''
      MIHOMO_CONTROLLER_SECRET=${config.sops.placeholder."mihomo/external_controller_secret"}
    '';
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = lib.mkAfter [
    config.sops.templates."caddy-mihomo-controller.env".path
  ];
  systemd.services.caddy.reloadTriggers = lib.mkAfter [
    config.sops.templates."caddy-mihomo-controller.env".path
  ];

  services.caddy.virtualHosts."${site.mihomoControllerHost}".extraConfig = ''
    bind ${site.tailnetIPv4}
    tls {
      dns alidns {
        access_key_id {env.ALICLOUD_ACCESS_KEY}
        access_key_secret {env.ALICLOUD_SECRET_KEY}
      }
      resolvers 1.1.1.1 8.8.8.8
    }
    encode zstd gzip

    @apiVersionHead {
      method HEAD
      path /api/version
    }
    handle @apiVersionHead {
      respond "" 200
    }

    @api path /api*
    handle @api {
      uri strip_prefix /api
      uri query token {env.MIHOMO_CONTROLLER_SECRET}
      reverse_proxy 127.0.0.1:9090 {
        header_up Authorization "Bearer {env.MIHOMO_CONTROLLER_SECRET}"
      }
    }

    handle_path /zashboard/* {
      root * ${pkgs.mihomo-dashboards}/zashboard
      try_files {path} {path}/ /index.html
      file_server
    }

    handle_path /metacubexd/* {
      root * ${pkgs.mihomo-dashboards}/metacubexd
      try_files {path} {path}/ /index.html
      file_server
    }

    handle_path /yacd/* {
      root * ${pkgs.mihomo-dashboards}/yacd
      try_files {path} {path}/ /index.html
      file_server
    }

    handle {
      root * ${pkgs.mihomo-dashboards}
      try_files {path} /index.html
      file_server
    }
  '';
}
