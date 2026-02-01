{ config, pkgs, ... }:

{
  services.haproxy = {
    enable = true;
    config = ''
      global
        maxconn 4096

      defaults
        timeout connect 10s
        timeout client  1m
        timeout server  1m

      frontend fe_http
        bind :80
        mode http
        http-request redirect scheme https code 301

      frontend fe_tls
        bind :443
        mode tcp
        tcp-request inspect-delay 5s
        tcp-request content accept if { req.ssl_hello_type 1 }

        acl sni_hs req.ssl_sni -i hs.zhsjf.cn
        use_backend be_caddy if sni_hs
        default_backend be_caddy

      backend be_caddy
        mode tcp
        server caddy 127.0.0.1:8443
    '';
  };
}
