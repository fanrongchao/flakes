{ config, pkgs, lib, ... }:
let
  cfg = config.services.networkIngressProxy;
  mkVirtualHost = host: hostCfg: {
    extraConfig = ''
      bind ${hostCfg.bindAddress}
      tls {
        dns alidns {
          access_key_id {env.ALICLOUD_ACCESS_KEY}
          access_key_secret {env.ALICLOUD_SECRET_KEY}
        }
        resolvers 1.1.1.1 8.8.8.8
      }
      reverse_proxy ${hostCfg.upstream}
    '';
  };
in {
  options.services.networkIngressProxy.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
      options = {
        upstream = lib.mkOption {
          type = lib.types.str;
          description = "Upstream address passed to Caddy reverse_proxy.";
        };
        bindAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Local address Caddy binds for the virtual host.";
        };
      };
    }));
    default = {};
    description = "Site-specific Caddy virtual hosts exposed through the ingress proxy.";
  };

  config = {
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

      # Run Caddy behind HAProxy (SNI passthrough on :443).
      # Move Caddy's HTTP port away from :80 because HAProxy owns it.
      globalConfig = ''
        https_port 8443
        http_port 18080
        auto_https disable_redirects

        servers {
          protocols h1 h2
        }
      '';
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/alidns@v1.0.26" ];
        hash = "sha256-U8uzVMPKfAMgCv1M6WIsiaLuzLbJftS87mGLeySK3FI=";
      };

      virtualHosts = lib.mapAttrs mkVirtualHost cfg.virtualHosts;
    };

    systemd.services.caddy = {
      reloadTriggers = [
        "/etc/caddy/caddy_config"
        config.sops.templates."caddy-alidns.env".path
      ];

      serviceConfig.EnvironmentFile = [
        config.sops.templates."caddy-alidns.env".path
      ];
    };
  };
}
