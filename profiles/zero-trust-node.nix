{ config, pkgs, lib, ... }:
let
  cfg = config.services.zeroTrustNode;
in {
  options.services.zeroTrustNode.loginServerUrl = lib.mkOption {
    type = lib.types.str;
    example = "https://hs.example.com";
    description = "Headscale/Tailscale login-server URL used by this node.";
  };

  config = {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";

      # 指向自建 Headscale 控制面
      extraUpFlags = [
        "--login-server=${cfg.loginServerUrl}"
      ];
    };

    # 确保 tailscaled 在 mihomo/clash 之后启动，
    # 让 Tailscale 的更精确路由覆盖 TUN 的兜底路由。
    systemd.services.tailscaled = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
