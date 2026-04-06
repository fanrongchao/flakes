{ config, pkgs, lib, ... }:
{
  environment.etc."headscale/derp.yaml".text = ''
    regions:
      902:
        regionid: 902
        regioncode: cn-ali-qd
        regionname: China Ali Qingdao
        nodes:
          - name: 902a
            regionid: 902
            hostname: derp.zhsjf.cn
            ipv4: 114.215.124.90
            stunport: 3478
            derpport: 443
            canport80: true
  '';

  services.headscale = {
    enable = true;

    settings = {
      server_url = "https://hs.zhsjf.cn";
      listen_addr = "127.0.0.1:8080";

      derp = {
        server.enabled = false;
        urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
        paths = [ "/etc/headscale/derp.yaml" ];
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
