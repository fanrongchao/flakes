{ ... }:
{
  services.caddy = {
    enable = true;

    virtualHosts."hs.zhsjf.cn".extraConfig = ''
      reverse_proxy 127.0.0.1:8080
    '';
  };
}
