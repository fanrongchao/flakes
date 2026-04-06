{ config, pkgs, lib, ... }:

let
  cfg = config.services.ingressHaproxySni;
  mkSniRules = backend: hosts: lib.concatMapStringsSep "\n" (host:
    let
      aclName = "sni_" + lib.replaceStrings [ "." "-" ] [ "_" "_" ] host;
    in ''
        acl ${aclName} req.ssl_sni -i ${host}
        use_backend ${backend} if ${aclName}
    ''
  ) hosts;

  publicSniRules = mkSniRules "be_caddy" cfg.tlsServerNames;
  tailnetSniRules = mkSniRules "be_caddy_tailnet" cfg.tailnetTlsServerNames;
  blockedPublicSniRules = lib.concatMapStringsSep "\n" (host:
    let
      aclName = "blocked_public_" + lib.replaceStrings [ "." "-" ] [ "_" "_" ] host;
    in ''
        acl ${aclName} req.ssl_sni -i ${host}
        tcp-request content reject if ${aclName}
    ''
  ) cfg.tailnetTlsServerNames;
  publicHttpBinds = lib.concatMapStringsSep "\n" (addr: "      bind ${addr}") cfg.publicHttpBindAddresses;
  publicTlsBinds = lib.concatMapStringsSep "\n" (addr: "      bind ${addr}") cfg.publicTlsBindAddresses;
  tailnetTlsBinds = lib.concatMapStringsSep "\n" (addr: "      bind ${addr}") cfg.tailnetTlsBindAddresses;
  tailnetFrontend = lib.optionalString (cfg.tailnetTlsBindAddresses != [] && cfg.tailnetTlsServerNames != []) ''

        frontend fe_tls_tailnet
${tailnetTlsBinds}
          mode tcp
          tcp-request inspect-delay 5s
          tcp-request content accept if { req.ssl_hello_type 1 }

          # Tailnet-only TLS traffic by SNI.
${tailnetSniRules}
          tcp-request content reject
  '';

  tailnetBackend = lib.optionalString (cfg.tailnetTlsBindAddresses != [] && cfg.tailnetTlsServerNames != []) ''

        backend be_caddy_tailnet
          mode tcp
          server caddy-tailnet ${cfg.tailnetCaddyBackend}
  '';
in {
  options.services.ingressHaproxySni = {
    publicHttpBindAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ":80" ];
      description = "Bind addresses for the public HTTP redirect frontend.";
    };

    publicTlsBindAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ":443" ];
      description = "Bind addresses for the public TLS passthrough frontend.";
    };

    tlsServerNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SNI hostnames that should be passed through to the local Caddy TLS backend.";
    };

    tailnetTlsBindAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Bind addresses for tailnet-only TLS passthrough frontends.";
    };

    tailnetTlsServerNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SNI hostnames exposed only on the tailnet TLS frontend.";
    };

    tailnetCaddyBackend = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8443";
      description = "Backend TCP endpoint for the tailnet-only Caddy TLS listener.";
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
${publicHttpBinds}
          mode http
          http-request redirect scheme https code 301

        frontend fe_tls
${publicTlsBinds}
          mode tcp
          tcp-request inspect-delay 5s
          tcp-request content accept if { req.ssl_hello_type 1 }

          # Non-TLS traffic (SSH) → GitLab SSH
          use_backend be_gitlab_ssh if !{ req.ssl_hello_type 1 }

          # TLS traffic by SNI
${publicSniRules}
${blockedPublicSniRules}
          default_backend be_caddy
${tailnetFrontend}

        backend be_caddy
          mode tcp
          server caddy 127.0.0.1:8443
${tailnetBackend}

        backend be_gitlab_ssh
          mode tcp
          server gitlab-ssh ${cfg.gitSshBackend}
      '';
    };
  };
}
