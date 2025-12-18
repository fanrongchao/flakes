{ config, pkgs, lib, ... }:
{
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://hs.zhsjf.cn";
      listen_addr = "127.0.0.1:8080";
    };
  };
}
