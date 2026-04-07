{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.services.mihomoEgress;
  mihomoCli = inputs.mihomo-cli.packages.${pkgs.stdenv.hostPlatform.system}.mihomo-cli;
  mihomoCliExe = lib.getExe' mihomoCli "mihomo-cli";
  runDir = "/var/lib/mihomo/.config/mihomocli";
  resourcesDir = "${runDir}/resources";
  configPath = "${resourcesDir}/config.yaml";

  customRuleCommands = lib.concatMapStringsSep "\n" (rule: ''
    ${mihomoCliExe} manage custom add \
      --domain ${lib.escapeShellArg rule.domain} \
      --kind ${lib.escapeShellArg rule.kind} \
      --via ${lib.escapeShellArg rule.via} 2>/dev/null || true
  '') (cfg.customRules ++ cfg.directRules);

  manualServerArgCommands = lib.concatStringsSep "\n" (
    [
      "    manual_server_args=("
      "      --name ${lib.escapeShellArg cfg.manualServerName}"
      "      --file \"$manual_links_path\""
      "    )"
    ]
    ++ map (group: "    manual_server_args+=( --attach-group ${lib.escapeShellArg group} )") cfg.manualServerAttachGroups
    ++ [
      "    ${mihomoCliExe} manage server add \"\${manual_server_args[@]}\" --replace >/dev/null"
    ]
  );

  mergeArgCommands = lib.concatStringsSep "\n" (
    [
      "    merge_args=("
      "      --subscription \"$sub_url\""
      "      --output \"$tmp_config\""
      "      --mode ${lib.escapeShellArg cfg.mode}"
      "      --sniffer-preset ${lib.escapeShellArg cfg.snifferPreset}"
      "      --external-controller-url ${lib.escapeShellArg cfg.externalControllerBindAddress}"
      "      --external-controller-port 9090"
      "      --external-controller-secret \"$secret\""
      "    )"
    ]
    ++ lib.optionals cfg.tailscaleCompatible [
      "    merge_args+=( --tailscale-compatible )"
    ]
    ++ map (domain: "    merge_args+=( --fake-ip-bypass ${lib.escapeShellArg domain} )") cfg.fakeIpBypassDomains
    ++ map (cidr: "    merge_args+=( --k8s-cidr-exclude ${lib.escapeShellArg cidr} )") cfg.k8sExcludeCidrs
    ++ map (cidr: "    merge_args+=( --route-exclude-address-add ${lib.escapeShellArg cidr} )") cfg.routeExcludeCidrs
    ++ map (suffix: "    merge_args+=( --tailscale-tailnet-suffix ${lib.escapeShellArg suffix} )") cfg.tailscaleTailnetSuffixes
    ++ map (domain: "    merge_args+=( --tailscale-direct-domain ${lib.escapeShellArg domain} )") cfg.tailscaleDirectDomains
  );

  updateScript = pkgs.writeShellScript "mihomo-egress-update" ''
    set -euo pipefail

    export HOME=/var/lib/mihomo
    export XDG_CONFIG_HOME=/var/lib/mihomo/.config

    sub_url="$(cat "${config.sops.secrets."mihomo/subscription_url".path}")"
    secret="$(cat "${config.sops.secrets."mihomo/external_controller_secret".path}")"

    manual_links_path="${config.sops.secrets."mihomo/manual_share_links".path}"

    mkdir -p "${resourcesDir}"

    tmp_config="$(mktemp "${resourcesDir}/config.yaml.XXXXXX")"

${manualServerArgCommands}

${customRuleCommands}

${mergeArgCommands}

    if ! ${mihomoCliExe} merge "''${merge_args[@]}"; then
      rm -f "$tmp_config"
      if [ -s "${configPath}" ]; then
        echo "mihomo update failed; keeping existing config" >&2
        exit 0
      fi
      echo "mihomo update failed and no existing config is available" >&2
      exit 1
    fi


    mv -f "$tmp_config" "${configPath}"

    # Validate config before applying it.
    ${lib.getExe pkgs.mihomo} \
      -d "${resourcesDir}" \
      -f "${configPath}" \
      -m \
      -t

    if [ "${"$"}{1:-}" != "reload" ]; then
      exit 0
    fi

    # If mihomo isn't up yet, treat as success (config was generated).
    if ! ${lib.getExe pkgs.curl} -fsS \
      -H "Authorization: Bearer $secret" \
      "http://127.0.0.1:9090/version" >/dev/null 2>&1; then
      exit 0
    fi

    ${lib.getExe pkgs.curl} -fsS \
      -X PUT "http://127.0.0.1:9090/configs" \
      -H "Authorization: Bearer $secret" \
      -H "Content-Type: application/json" \
      --data "{\"path\":\"${configPath}\"}"
  '';
in
{
  options.services.mihomoEgress = {
    manualServerName = lib.mkOption {
      type = lib.types.str;
      default = "manual-server";
      description = "Logical name used for the manual share-link source injected by mihomo-cli.";
    };

    manualServerAttachGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Proxy groups that should receive the manual server entries managed by mihomo-cli.";
    };

    customRules = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ ... }: {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Domain or suffix to inject as a Mihomo custom rule.";
          };
          kind = lib.mkOption {
            type = lib.types.enum [ "domain" "suffix" "keyword" ];
            default = "suffix";
            description = "Rule kind passed to mihomo-cli manage custom add.";
          };
          via = lib.mkOption {
            type = lib.types.str;
            default = "Proxy";
            description = "Target policy/group for the injected rule.";
          };
        };
      }));
      default = [];
      description = "Additional custom rules to inject before merging the Mihomo egress config.";
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "rule" "global" "direct" ];
      default = "rule";
      description = "Final Mihomo mode passed to mihomo-cli merge.";
    };

    snifferPreset = lib.mkOption {
      type = lib.types.enum [ "tun" "off" ];
      default = "tun";
      description = "Transparent traffic sniffer preset passed to mihomo-cli merge.";
    };

    externalControllerBindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Bind address passed to Mihomo's external controller listener.";
    };

    tailscaleCompatible = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable mihomo-cli's Tailscale compatibility patch set for this host.";
    };

    tailscaleTailnetSuffixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Tailnet suffixes passed to --tailscale-tailnet-suffix for host-owned MagicDNS domains.";
    };

    tailscaleDirectDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Exact domains or suffixes passed to --tailscale-direct-domain for host-owned control-plane and DERP endpoints.";
    };

    fakeIpBypassDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "+.tailscale.com"
        "+.tailscale.io"
        "+.ts.net"
      ];
      description = "Domains to append to Mihomo fake-ip bypass when building the egress config.";
    };

    k8sExcludeCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.42.0.0/16"
        "10.43.0.0/16"
      ];
      description = "Kubernetes Pod/Service CIDRs passed through --k8s-cidr-exclude.";
    };

    routeExcludeCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
      description = "Additional CIDRs to keep out of Mihomo TUN routing on the host.";
    };

    directRules = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ ... }: {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Domain or suffix to inject as a Mihomo custom rule.";
          };
          kind = lib.mkOption {
            type = lib.types.enum [ "domain" "suffix" "keyword" ];
            default = "suffix";
            description = "Rule kind passed to mihomo-cli manage custom add.";
          };
          via = lib.mkOption {
            type = lib.types.str;
            default = "DIRECT";
            description = "Target policy/group for the injected rule.";
          };
        };
      }));
      default = [
        { domain = "tailscale.com"; kind = "suffix"; via = "DIRECT"; }
        { domain = "tailscale.io"; kind = "suffix"; via = "DIRECT"; }
        { domain = "ts.net"; kind = "suffix"; via = "DIRECT"; }
      ];
      description = "Custom rules to inject before merging the Mihomo egress config.";
    };
  };

  config = {
    networking.firewall.enable = false;

    environment.systemPackages = with pkgs; [
      mihomo
    ];

    sops.age.keyFile = "/var/lib/sops/age/keys.txt";
    sops.secrets."mihomo/subscription_url" = {
      sopsFile = ../secrets/mihomo-egress.yaml;
      owner = "mihomo";
      group = "mihomo";
      mode = "0400";
    };
    sops.secrets."mihomo/external_controller_secret" = {
      sopsFile = ../secrets/mihomo-egress.yaml;
      owner = "mihomo";
      group = "mihomo";
      mode = "0400";
    };

    sops.secrets."mihomo/manual_share_links" = {
      sopsFile = ../secrets/mihomo-egress.yaml;
      owner = "mihomo";
      group = "mihomo";
      mode = "0400";
    };

    users.groups.mihomo = {};
    users.users.mihomo = {
      isSystemUser = true;
      group = "mihomo";
      home = "/var/lib/mihomo";
      createHome = true;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/mihomo 0750 mihomo mihomo -"
      "d /var/lib/mihomo/.config 0750 mihomo mihomo -"
      "d /var/lib/mihomo/.config/mihomocli 0750 mihomo mihomo -"
      "d ${resourcesDir} 0750 mihomo mihomo -"
    ];

    systemd.services.mihomo = {
      description = "Mihomo (egress proxy/controller)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Ensure nixos-rebuild reapplies subscription-derived config when the
      # update script or its secret inputs change.
      reloadTriggers = [
        updateScript
        config.sops.secrets."mihomo/subscription_url".path
        config.sops.secrets."mihomo/external_controller_secret".path
        config.sops.secrets."mihomo/manual_share_links".path
      ];

      serviceConfig = {
        Type = "simple";
        User = "mihomo";
        Group = "mihomo";
        Restart = "on-failure";
        RestartSec = "5s";

        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];

        ExecStartPre = [ "${updateScript}" ];
        ExecStart = "${lib.getExe pkgs.mihomo} -d ${resourcesDir} -f ${configPath} -m";
        ExecReload = "${updateScript} reload";
      };
    };

    systemd.services.mihomo-update = {
      description = "Update Mihomo subscription and reload";
      serviceConfig = {
        Type = "oneshot";
        User = "mihomo";
        Group = "mihomo";
        ExecStart = "${updateScript} reload";
      };
    };

    systemd.timers.mihomo-update = {
      description = "Hourly Mihomo subscription update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "1h";
        Persistent = true;
        Unit = "mihomo-update.service";
      };
    };
  };
}
