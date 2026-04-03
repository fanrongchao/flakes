{ config, lib, pkgs, ... }:

let
  cfg = config.services.sub2api;
  composeFile = pkgs.writeText "sub2api-compose.yml" ''
    services:
      postgres:
        image: docker.io/postgres:16-alpine
        restart: unless-stopped
        network_mode: host
        env_file:
          - ${cfg.dataDir}/runtime.env
        environment:
          POSTGRES_DB: ${cfg.database.name}
          POSTGRES_USER: ${cfg.database.user}
        command: ["postgres", "-c", "listen_addresses=127.0.0.1", "-p", "15432"]
        volumes:
          - ${cfg.dataDir}/postgres:/var/lib/postgresql/data:Z

      redis:
        image: docker.io/redis:7-alpine
        restart: unless-stopped
        network_mode: host
        command: ["redis-server", "--appendonly", "yes", "--bind", "127.0.0.1", "--port", "16379"]
        volumes:
          - ${cfg.dataDir}/redis:/data:Z

      sub2api:
        image: docker.io/weishaw/sub2api:latest
        restart: unless-stopped
        network_mode: host
        volumes:
          - ${cfg.dataDir}/app:/app/data:Z
  '';
in
{
  imports = [
    ./container-runtime
  ];

  options.services.sub2api = {
    enable = lib.mkEnableOption "Sub2API service";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "aiapi.zhsjf.cn";
      description = "Public HTTPS domain for Sub2API.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sub2api";
      description = "Persistent data directory for Sub2API.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 18081;
      description = "Loopback HTTP port exposed by the Sub2API container.";
    };

    adminEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@zhsjf.cn";
      description = "Bootstrap administrator email for the first-run setup.";
    };

    database.name = lib.mkOption {
      type = lib.types.str;
      default = "sub2api";
      description = "PostgreSQL database name for Sub2API.";
    };

    database.user = lib.mkOption {
      type = lib.types.str;
      default = "sub2api";
      description = "PostgreSQL user for Sub2API.";
    };
  };

  config = lib.mkIf cfg.enable {
    containerRuntime.enable = true;
    containerRuntime.dockerCompat = true;

    environment.systemPackages = with pkgs; [
      curl
      jq
      podman-compose
    ];

    environment.etc."sub2api/docker-compose.yml".source = composeFile;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.dataDir}/app 0750 root root - -"
      "d ${cfg.dataDir}/postgres 0750 root root - -"
      "d ${cfg.dataDir}/redis 0750 root root - -"
      "d ${cfg.dataDir}/secrets 0700 root root - -"
      "d ${cfg.dataDir}/tmp 0750 root root - -"
    ];

    services.caddy.virtualHosts."${cfg.domain}".extraConfig = ''
      bind 127.0.0.1
      tls {
        dns alidns {
          access_key_id {env.ALICLOUD_ACCESS_KEY}
          access_key_secret {env.ALICLOUD_SECRET_KEY}
        }
        resolvers 1.1.1.1 8.8.8.8
      }
      reverse_proxy 127.0.0.1:${toString cfg.listenPort}
    '';

    systemd.services.sub2api-prepare = {
      description = "Prepare persistent state for Sub2API";
      wantedBy = [ "multi-user.target" ];
      before = [ "sub2api.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ coreutils ];
      script = ''
        set -euo pipefail

        install -d -m 0700 ${cfg.dataDir}/secrets

        if [ ! -s ${cfg.dataDir}/secrets/postgres-password ]; then
          od -An -N16 -tx1 /dev/urandom | tr -d ' \n' > ${cfg.dataDir}/secrets/postgres-password
          printf '\n' >> ${cfg.dataDir}/secrets/postgres-password
        fi

        if [ ! -s ${cfg.dataDir}/secrets/admin-password ]; then
          od -An -N12 -tx1 /dev/urandom | tr -d ' \n' > ${cfg.dataDir}/secrets/admin-password
          printf '\n' >> ${cfg.dataDir}/secrets/admin-password
        fi

        printf '%s\n' '${cfg.adminEmail}' > ${cfg.dataDir}/secrets/admin-email

        printf 'POSTGRES_PASSWORD=%s\n' \
          "$(tr -d '\n' < ${cfg.dataDir}/secrets/postgres-password)" \
          > ${cfg.dataDir}/runtime.env
        chmod 0600 ${cfg.dataDir}/runtime.env
      '';
    };

    systemd.services.sub2api = {
      description = "Sub2API container stack";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "sub2api-prepare.service" ];
      wants = [ "network-online.target" "sub2api-prepare.service" ];
      requires = [ "sub2api-prepare.service" ];
      restartTriggers = [ composeFile ];
      path = with pkgs; [ podman podman-compose ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/etc/sub2api";
        ExecStart = "${pkgs.podman-compose}/bin/podman-compose -f /etc/sub2api/docker-compose.yml up -d";
        ExecStop = "${pkgs.podman-compose}/bin/podman-compose -f /etc/sub2api/docker-compose.yml down";
        TimeoutStartSec = 300;
        TimeoutStopSec = 60;
      };
    };

    systemd.services.sub2api-init = {
      description = "Initialize Sub2API on first boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "sub2api.service" ];
      requires = [ "sub2api.service" ];
      unitConfig.ConditionPathExists = "!${cfg.dataDir}/initialized";
      serviceConfig = {
        Type = "oneshot";
      };
      path = with pkgs; [ curl jq coreutils ];
      script = ''
        set -euo pipefail
        status_file=${cfg.dataDir}/tmp/setup-status.json
        install_file=${cfg.dataDir}/tmp/setup-install.json

        for _ in $(seq 1 120); do
          if curl -fsS http://127.0.0.1:${toString cfg.listenPort}/setup/status >"$status_file"; then
            break
          fi
          sleep 2
        done

        if ! test -s "$status_file"; then
          echo "Sub2API setup endpoint did not become ready" >&2
          exit 1
        fi

        if [ "$(jq -r '.data.needs_setup' "$status_file")" != "true" ]; then
          touch ${cfg.dataDir}/initialized
          exit 0
        fi

        postgres_password="$(tr -d '\n' < ${cfg.dataDir}/secrets/postgres-password)"
        admin_password="$(tr -d '\n' < ${cfg.dataDir}/secrets/admin-password)"
        admin_email="$(tr -d '\n' < ${cfg.dataDir}/secrets/admin-email)"

        payload="$(${pkgs.jq}/bin/jq -n \
          --arg dbHost "127.0.0.1" \
          --argjson dbPort 15432 \
          --arg dbUser "${cfg.database.user}" \
          --arg dbPassword "$postgres_password" \
          --arg dbName "${cfg.database.name}" \
          --arg dbSslMode "disable" \
          --arg redisHost "127.0.0.1" \
          --argjson redisPort 16379 \
          --arg redisPassword "" \
          --argjson redisDb 0 \
          --arg adminEmail "$admin_email" \
          --arg adminPassword "$admin_password" \
          --arg serverHost "${cfg.domain}" \
          --argjson serverPort 443 \
          --arg serverMode "release" \
          '{
            database: {
              host: $dbHost,
              port: $dbPort,
              user: $dbUser,
              password: $dbPassword,
              dbname: $dbName,
              sslmode: $dbSslMode
            },
            redis: {
              host: $redisHost,
              port: $redisPort,
              password: $redisPassword,
              db: $redisDb,
              enable_tls: false
            },
            admin: {
              email: $adminEmail,
              password: $adminPassword
            },
            server: {
              host: $serverHost,
              port: $serverPort,
              mode: $serverMode
            }
          }'
        )"

        curl -fsS \
          -X POST \
          -H 'Content-Type: application/json' \
          -d "$payload" \
          http://127.0.0.1:${toString cfg.listenPort}/setup/install >"$install_file"

        for _ in $(seq 1 120); do
          if curl -fsS http://127.0.0.1:${toString cfg.listenPort}/setup/status >"$status_file"; then
            if [ "$(jq -r '.data.needs_setup' "$status_file")" = "false" ]; then
              touch ${cfg.dataDir}/initialized
              exit 0
            fi
          fi
          sleep 2
        done

        echo "Sub2API setup did not complete in time" >&2
        exit 1
      '';
    };
  };
}
