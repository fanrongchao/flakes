{ pkgs, ... }:
{
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      # 建议先用“Latest 稳定版”tag（目前仓库的 Latest 是 v1.0.26；beta 版本也有）
      # 你也可以换成更新的 tag（比如 v1.0.28-beta.*），但我建议先用 Latest 稳定版
      plugins = [ "github.com/caddy-dns/alidns@v1.0.26" ];
      # 第一次把 hash 留空或随便写，nixos-rebuild 会报出正确的 hash，你再填回来
      hash = "";
    };

    virtualHosts."hs.zhsjf.cn".extraConfig = ''
      reverse_proxy 127.0.0.1:8080
    '';
  };
}
