{ config, pkgs, lib, inputs, ... }:

let
  mihomoCli = inputs.mihomo-cli.packages.${pkgs.system}.mihomo-cli;
  runDir = "/var/lib/mihomo/.config/mihomocli";
  resourcesDir = "${runDir}/resources";
  configPath = "${resourcesDir}/config.yaml";

  updateScript = pkgs.writeShellScript "mihomo-egress-update" ''
    set -euo pipefail

    export HOME=/var/lib/mihomo
    export XDG_CONFIG_HOME=/var/lib/mihomo/.config

    sub_url="$(cat "${config.sops.secrets."mihomo/subscription_url".path}")"
    secret="$(cat "${config.sops.secrets."mihomo/external_controller_secret".path}")"

    mkdir -p "${resourcesDir}"

    tmp_config="$(mktemp "${resourcesDir}/config.yaml.XXXXXX")"
    if ! ${lib.getExe' mihomoCli "mihomo-cli"} merge \
      --subscription "$sub_url" \
      --output "$tmp_config" \
      --external-controller-url 0.0.0.0 \
      --external-controller-port 9090 \
      --external-controller-secret "$secret" \
      --fake-ip-bypass '+.zhsjf.cn'; then
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
}
