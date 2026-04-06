{ config, pkgs, lib, ... }:

let
  cfg = config.services.zeroTrustControlPlane;
  derpBypassScript = pkgs.writeShellScript "headscale-derp-route-bypass" ''
    set -euo pipefail

    ip_cmd="${lib.getExe' pkgs.iproute2 "ip"}"
    nft_cmd="${lib.getExe pkgs.nftables}"
    headscale_uid="$(id -u headscale)"

    # Headscale's embedded DERP/STUN responses must bypass Mihomo's TUN routes
    # so the server replies with its real public source address.
    "$ip_cmd" rule del pref 5204 uidrange "${"$"}{headscale_uid}-${"$"}{headscale_uid}" lookup main 2>/dev/null || true
    "$ip_cmd" rule add pref 5204 uidrange "${"$"}{headscale_uid}-${"$"}{headscale_uid}" lookup main
    "$ip_cmd" -6 rule del pref 5204 uidrange "${"$"}{headscale_uid}-${"$"}{headscale_uid}" lookup main 2>/dev/null || true
    "$ip_cmd" -6 rule add pref 5204 uidrange "${"$"}{headscale_uid}-${"$"}{headscale_uid}" lookup main

    # Clean up one-off debugging rules if they still exist.
    "$ip_cmd" rule del pref 5205 fwmark 0x3478 lookup main 2>/dev/null || true
    "$ip_cmd" -6 rule del pref 5205 fwmark 0x3478 lookup main 2>/dev/null || true
    "$nft_cmd" delete table inet headscale_derp_bypass 2>/dev/null || true
  '';
in
{
  options.services.zeroTrustControlPlane = {
    serverUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://hs.example.com";
      description = "Public Headscale control-plane URL.";
    };

    tailnetBaseDomain = lib.mkOption {
      type = lib.types.str;
      example = "tail.example.com";
      description = "Base domain advertised by MagicDNS.";
    };

    derp = {
      hostname = lib.mkOption {
        type = lib.types.str;
        example = "derp.example.com";
        description = "Public hostname for the self-hosted DERP endpoint.";
      };

      ipv4 = lib.mkOption {
        type = lib.types.str;
        example = "203.0.113.10";
        description = "Public IPv4 address advertised for the DERP endpoint.";
      };

      regionId = lib.mkOption {
        type = lib.types.int;
        default = 902;
        description = "DERP region ID advertised to clients.";
      };

      regionCode = lib.mkOption {
        type = lib.types.str;
        default = "cn-ai-server";
        description = "DERP region code advertised to clients.";
      };

      regionName = lib.mkOption {
        type = lib.types.str;
        default = "China AI Server";
        description = "DERP region display name advertised to clients.";
      };

      stunPort = lib.mkOption {
        type = lib.types.port;
        default = 3478;
        description = "Public UDP STUN port advertised for the DERP node.";
      };

      derpPort = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "Public TCP DERP port advertised for the DERP node.";
      };
    };
  };

  config = {
    environment.etc."headscale/derp.yaml".text = ''
      regions:
        ${toString cfg.derp.regionId}:
          regionid: ${toString cfg.derp.regionId}
          regioncode: ${cfg.derp.regionCode}
          regionname: ${cfg.derp.regionName}
          nodes:
            - name: ${toString cfg.derp.regionId}a
              regionid: ${toString cfg.derp.regionId}
              hostname: ${cfg.derp.hostname}
              ipv4: ${cfg.derp.ipv4}
              stunport: ${toString cfg.derp.stunPort}
              derpport: ${toString cfg.derp.derpPort}
              canport80: false
    '';

    services.headscale = {
      enable = true;

      settings = {
        server_url = cfg.serverUrl;
        listen_addr = "127.0.0.1:8080";

        derp = {
          server = {
            enabled = true;
            region_id = cfg.derp.regionId;
            region_code = cfg.derp.regionCode;
            region_name = cfg.derp.regionName;
            verify_clients = true;
            stun_listen_addr = "0.0.0.0:${toString cfg.derp.stunPort}";
            private_key_path = "/var/lib/headscale/derp_server_private.key";
            automatically_add_embedded_derp_region = false;
            ipv4 = cfg.derp.ipv4;
          };
          urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
          paths = [ "/etc/headscale/derp.yaml" ];
        };

        dns = {
          magic_dns = true;

          # ✅ 必须是 FQDN，且不能和 server_url 的域相同/包含
          base_domain = cfg.tailnetBaseDomain;
          override_local_dns = false;

          # 可选：给客户端注入搜索域
          # search_domains = [ cfg.tailnetBaseDomain ];
        };
      };
    };

    systemd.services.headscale-derp-route-bypass = {
      description = "Keep Headscale DERP/STUN replies off Mihomo TUN";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" "mihomo.service" ];
      after = [ "network-online.target" "mihomo.service" ];
      before = [ "headscale.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = derpBypassScript;
      };
    };
  };
}
