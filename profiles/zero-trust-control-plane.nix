{ config, pkgs, lib, ... }:

let
  cfg = config.services.zeroTrustControlPlane;
  headscaleBin = lib.getExe pkgs.headscale;
  jqBin = lib.getExe pkgs.jq;
  sedBin = lib.getExe' pkgs.gnused "sed";
  trBin = lib.getExe' pkgs.coreutils "tr";
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
  invalidHostnameReconcileScript = pkgs.writeShellScript "headscale-invalid-hostname-reconcile" ''
    set -euo pipefail

    ${headscaleBin} nodes list -o json \
      | ${jqBin} -r '.[] | select((.name // "") | startswith("invalid-")) | [.id, (.user.name // ""), (.name // "")] | @tsv' \
      | while IFS=$'\t' read -r node_id user_name current_name; do
        [ -n "$node_id" ] || continue

        raw_base="$user_name"
        if [ -z "$raw_base" ]; then
          raw_base="node"
        fi

        safe_base="$(printf '%s' "$raw_base" \
          | ${trBin} '[:upper:]' '[:lower:]' \
          | ${sedBin} -E 's/[^a-z0-9.-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g; s/\.+/./g; s/^[.]+//; s/[.]+$//')"
        if [ -z "$safe_base" ]; then
          safe_base="node"
        fi

        suffix="$current_name"
        suffix="''${suffix#invalid-}"
        if [ -z "$suffix" ] || [ "$suffix" = "$current_name" ]; then
          suffix="n$node_id"
        fi

        max_base_len=$((63 - 1 - ''${#suffix}))
        if [ ''${#safe_base} -gt "$max_base_len" ]; then
          safe_base="''${safe_base:0:$max_base_len}"
        fi

        new_name="''${safe_base}-''${suffix}"
        if [ "$new_name" != "$current_name" ]; then
          ${headscaleBin} nodes rename --identifier "$node_id" "$new_name"
        fi
      done
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

    oidc = {
      enable = lib.mkEnableOption "OIDC-backed Headscale login";

      issuer = lib.mkOption {
        type = lib.types.str;
        example = "https://auth.example.com/realms/company";
        description = "OIDC issuer used by Headscale.";
      };

      onlyStartIfOidcIsAvailable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether Headscale should block startup when the OIDC provider is unavailable.
          Defaults to false so an IdP outage does not automatically interrupt the
          existing control plane during the rollout phase.
        '';
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "headscale";
        description = "OIDC client ID used by Headscale.";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/secrets/headscale/oidc_client_secret";
        description = "Runtime path to the Headscale OIDC client secret.";
      };

      allowedGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "OIDC groups allowed to join the tailnet.";
      };

      scope = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "openid" "profile" "email" "groups" ];
        description = "OIDC scopes requested by Headscale.";
      };

      extraParams = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Extra query parameters forwarded to the OIDC authorization endpoint.
          Useful for forcing a fresh login prompt when switching accounts.
        '';
      };

      expiry = lib.mkOption {
        type = lib.types.str;
        default = "30d";
        description = "Headscale node re-authentication interval when using OIDC.";
      };

      emailVerifiedRequired = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether Headscale requires the provider to mark email as verified.";
      };

      pkce.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable PKCE for the Headscale OIDC client.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = (!cfg.oidc.enable) || (cfg.oidc.clientSecretFile != null);
        message = "services.zeroTrustControlPlane.oidc.clientSecretFile must be set when OIDC is enabled.";
      }
    ];

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
      } // lib.optionalAttrs cfg.oidc.enable {
        oidc = {
          only_start_if_oidc_is_available = cfg.oidc.onlyStartIfOidcIsAvailable;
          issuer = cfg.oidc.issuer;
          client_id = cfg.oidc.clientId;
          client_secret_path = "\${CREDENTIALS_DIRECTORY}/headscale_oidc_client_secret";
          scope = cfg.oidc.scope;
          extra_params = cfg.oidc.extraParams;
          allowed_groups = cfg.oidc.allowedGroups;
          expiry = cfg.oidc.expiry;
          email_verified_required = cfg.oidc.emailVerifiedRequired;
          pkce.enabled = cfg.oidc.pkce.enable;
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

    systemd.services.headscale-invalid-hostname-reconcile = {
      description = "Rename Headscale invalid-* hostnames to safe ASCII names";
      wants = [ "headscale.service" ];
      after = [ "headscale.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = invalidHostnameReconcileScript;
      };
    };

    systemd.timers.headscale-invalid-hostname-reconcile = {
      description = "Periodically reconcile invalid Headscale hostnames";
      wantedBy = [ "timers.target" ];
      partOf = [ "headscale.service" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "1m";
        RandomizedDelaySec = "15s";
      };
    };

    systemd.services.headscale = lib.mkIf cfg.oidc.enable {
      serviceConfig.LoadCredential = lib.mkAfter [
        "headscale_oidc_client_secret:${cfg.oidc.clientSecretFile}"
      ];
    };
  };
}
