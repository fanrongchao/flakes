{ lib, pkgs, config, ... }:

let
  cfg = config.services.sing-box;
  configFile =
    if cfg.config != null then
      # 直接用 Nix attrset 写 JSON
      (pkgs.writeText "sing-box.json" (builtins.toJSON cfg.config))
    else if cfg.configFile != null then
      # 也可指向已有的 JSON 文件路径
      cfg.configFile
    else
      # 占位，避免空配置
      (pkgs.writeText "sing-box.json" ''{"log": {"level":"info"} }'');
in
{
  options.services.sing-box = {
    enable = lib.mkEnableOption "Enable sing-box system service";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sing-box;
      description = "sing-box package to use";
    };
    # 二选一：
    config = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "sing-box JSON config expressed as a Nix attrset (will be toJSON).";
    };
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a JSON file for sing-box config.";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra CLI args for sing-box run";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "singbox";
      description = "System user running sing-box";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "singbox";
      description = "System group running sing-box";
    };
    wantsNetworkOnline = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Wait for network-online before starting";
    };
    enableTun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Grant CAP_NET_ADMIN and /dev/net/tun for TUN mode";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.config != null || cfg.configFile != null;
      message = "services.sing-box: either `config` or `configFile` must be set.";
    }];

    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    # 如需把 JSON 暴露到 /etc，便于排查
    environment.etc."sing-box/config.json".source = configFile;

    # TUN 设备（大多数内核已内建，无需额外模块；这里仅确保创建规则）
    boot.kernelModules = lib.mkIf cfg.enableTun [ "tun" ];

    # 可选：若做透明代理/路由，打开转发（视需求开启）
    # networking.enableIPv4 = true;
    # networking.enableIPv6 = lib.mkDefault false;
    # networking.ip_forward = lib.mkDefault true;

    systemd.services.sing-box = {
      description = "sing-box Service";
      wantedBy = [ "multi-user.target" ];
      after = lib.mkIf cfg.wantsNetworkOnline [ "network-online.target" ];
      wants = lib.mkIf cfg.wantsNetworkOnline [ "network-online.target" ];

      serviceConfig = {
        ExecStart = ''
          ${cfg.package}/bin/sing-box run \
            -c /etc/sing-box/config.json ${lib.concatStringsSep " " cfg.extraArgs}
        '';

        # 安全/权限
        User = cfg.user;
        Group = cfg.group;
        AmbientCapabilities = lib.mkIf cfg.enableTun "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = lib.mkIf cfg.enableTun "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        DeviceAllow = lib.mkIf cfg.enableTun "/dev/net/tun rw";
        # 若需要 TPROXY 或低端口监听，保留 NET_BIND_SERVICE
        NoNewPrivileges = true;
        LockPersonality = true;

        # 目录
        RuntimeDirectory = "sing-box";
        StateDirectory = "sing-box";
        CacheDirectory = "sing-box";

        # 可靠性
        Restart = "always";
        RestartSec = "3s";

        # 限权（可按需放宽）
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = false; # 为了允许 /dev/net/tun
        ReadWritePaths = [ "/var/lib/sing-box" ];
      };
    };
  };
}

