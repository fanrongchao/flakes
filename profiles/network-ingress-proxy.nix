{ config, pkgs, ... }:
{
  sops.age.keyFile = "/var/lib/sops/age/keys.txt";
  sops.secrets."dns/ak" = {
    sopsFile = ../secrets/aliyun.yaml;
    owner = "caddy";
    group = "caddy";
  };
  sops.secrets."dns/as" = {
    sopsFile = ../secrets/aliyun.yaml;
    owner = "caddy";
    group = "caddy";
  };
  sops.templates."caddy-alidns.env" = {
    owner = "caddy";
    group = "caddy";
    mode = "0400";
    content = ''
      ALICLOUD_ACCESS_KEY=${config.sops.placeholder."dns/ak"}
      ALICLOUD_SECRET_KEY=${config.sops.placeholder."dns/as"}
    '';
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      # 建议先用“Latest 稳定版”tag（目前仓库的 Latest 是 v1.0.26；beta 版本也有）
      # 你也可以换成更新的 tag（比如 v1.0.28-beta.*），但我建议先用 Latest 稳定版
      plugins = [ "github.com/caddy-dns/alidns@v1.0.26" ];
      # 第一次把 hash 留空或随便写，nixos-rebuild 会报出正确的 hash，你再填回来
      hash = "sha256-U8uzVMPKfAMgCv1M6WIsiaLuzLbJftS87mGLeySK3FI=";
    };

    virtualHosts."hs.zhsjf.cn".extraConfig = ''
      tls {
        dns alidns {
          access_key_id {env.ALICLOUD_ACCESS_KEY}
          access_key_secret {env.ALICLOUD_SECRET_KEY}
        }
      }
      reverse_proxy 127.0.0.1:8080
    '';
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile =
    config.sops.templates."caddy-alidns.env".path;
}
