{ config, pkgs, lib, ... }:
{
  services.headscale = {
    enable = true;

    settings = {
      server_url  = "https://hs.zhsjf.cn";
      listen_addr = "127.0.0.1:8080";

      dns = {
        magic_dns = true;

        # ✅ 必须是 FQDN，且不能和 server_url 的域相同/包含
        base_domain = "tail.zhsjf.cn";

        # 可选：给客户端注入搜索域
        # search_domains = [ "tail.zhsjf.cn" ];
      };
    };
  };
}
