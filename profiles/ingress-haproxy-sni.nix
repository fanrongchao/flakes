{ config, pkgs, lib, ... }:

let
  cfg = config.services.ingressHaproxySni;
  sniRules = lib.concatMapStringsSep "\n" (host:
    let
      aclName = "sni_" + lib.replaceStrings [ "." "-" ] [ "_" "_" ] host;
    in ''
        acl ${aclName} req.ssl_sni -i ${host}
        use_backend be_caddy if ${aclName}
    ''
  ) cfg.tlsServerNames;
in {
  options.services.ingressHaproxySni = {
    tlsServerNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SNI hostnames that should be passed through to the local Caddy TLS backend.";
    };

    gitSshBackend = lib.mkOption {
      type = lib.types.str;
      example = "192.168.3.100:2222";
      description = "Backend TCP endpoint for non-TLS Git SSH traffic.";
    };
  };

  config = {
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

          # Non-TLS traffic (SSH) → GitLab SSH
          use_backend be_gitlab_ssh if !{ req.ssl_hello_type 1 }

          # TLS traffic by SNI
${sniRules}
          default_backend be_caddy

        backend be_caddy
          mode tcp
          server caddy 127.0.0.1:8443

        backend be_gitlab_ssh
          mode tcp
          server gitlab-ssh ${cfg.gitSshBackend}
      '';
    };
  };
}
