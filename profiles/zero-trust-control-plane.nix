{ config, pkgs, lib, ... }:
{
  services.headscale = {
    enable = true;

    settings = {
      server_url = "https://hs.zhsjf.cn";
      listen_addr = "127.0.0.1:8080";

      derp = {
        # Keep the embedded DERP on the same hostname as the control plane so
        # existing TLS and reverse proxying continue to work unchanged.
        server = {
          enabled = true;
          region_id = 901;
          region_code = "cn-bgp-jf";
          region_name = "China BGP JF";
          stun_listen_addr = "0.0.0.0:3478";
          automatically_add_embedded_derp_region = true;
        };
      };

      dns = {
        magic_dns = true;

        # ✅ 必须是 FQDN，且不能和 server_url 的域相同/包含
        base_domain = "tail.zhsjf.cn";
        override_local_dns = false;

        # 可选：给客户端注入搜索域
        # search_domains = [ "tail.zhsjf.cn" ];
      };
    };
  };
}
