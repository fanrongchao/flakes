{ config, pkgs, lib, ... }:
{
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://hs.zhsjf.cn";
      dns_config = {
        magic_dns = true;
        base_domain = "zhsjf.cn";   # ✅ 必填：用于 MagicDNS
      };   listen_addr = "127.0.0.1:8080";
    };
   
  };
}
