{ config, lib, pkgs, ... }:

let
  cfg = config.services.sub2api;
  serviceName = "sub2api";
  networkName = "sub2api_default";
  networkSubnet = "10.235.0.0/24";
  postgresAddress = "10.235.0.11";
  redisAddress = "10.235.0.12";
  sub2apiAddress = "10.235.0.13";
  bridgeResolver = "10.235.0.1";
  defaultImage = "ghcr.io/wei-shaw/sub2api:0.1.125@sha256:b87cbfbe092ced8aad40f4ece8c1d1b4d7c7553a77c3c61cc2bc3c2585f90e0b";
  defaultPostgresImage = "docker.io/postgres:18-alpine";
  defaultRedisImage = "docker.io/redis:8-alpine";
  cleanupStaleHealthcheckUnits = pkgs.writeShellScript "sub2api-healthcheck-cleanup" ''
    set -euo pipefail

    systemctl_cmd="${lib.getExe' pkgs.systemd "systemctl"}"
    podman_cmd="${lib.getExe pkgs.podman}"
    awk_cmd="${lib.getExe pkgs.gawk}"

    mapfile -t units < <(
      "$systemctl_cmd" list-units --all --type=service --plain --no-legend \
        | "$awk_cmd" '$1 ~ /^[0-9a-f]{64}-[0-9a-f]+\.service$/ { print $1 }'
    )

    for unit in "''${units[@]}"; do
      [ -n "$unit" ] || continue

      description="$("$systemctl_cmd" show -p Description --value "$unit" 2>/dev/null || true)"
      case "$description" in
        *"podman-wrapped healthcheck run "*) ;;
        *) continue ;;
      esac

      container_id="''${unit%%-*}"
      if ! "$podman_cmd" container exists "$container_id" >/dev/null 2>&1; then
        timer="''${unit%.service}.timer"
        "$systemctl_cmd" stop "$timer" "$unit" 2>/dev/null || true
        "$systemctl_cmd" reset-failed "$timer" "$unit" 2>/dev/null || true
      fi
    done
  '';
  waitForSub2apiReady = pkgs.writeShellScript "sub2api-wait-ready" ''
    set -euo pipefail

    curl_cmd="${lib.getExe pkgs.curl}"
    sleep_cmd="${lib.getExe' pkgs.coreutils "sleep"}"
    health_url="http://127.0.0.1:${toString cfg.listenPort}/health"

    attempt=0
    until "$curl_cmd" -fsS "$health_url" >/dev/null; do
      attempt=$((attempt + 1))
      if [ "$attempt" -ge 90 ]; then
        echo "Sub2API did not become healthy within 90 seconds: $health_url" >&2
        exit 1
      fi
      "$sleep_cmd" 1
    done
  '';
  composeFile = pkgs.writeText "sub2api-compose.yml" ''
    services:
      sub2api:
        image: ${cfg.image}
        restart: unless-stopped
        ulimits:
          nofile:
            soft: 100000
            hard: 100000
        ports:
          - "127.0.0.1:${toString cfg.listenPort}:8080"
        dns:
          - ${bridgeResolver}
        env_file:
          - ${cfg.dataDir}/runtime.env
        environment:
          AUTO_SETUP: "true"
          SERVER_HOST: "0.0.0.0"
          SERVER_PORT: "8080"
          SERVER_MODE: "${cfg.serverMode}"
          RUN_MODE: "${cfg.runMode}"
          DATABASE_HOST: "${postgresAddress}"
          DATABASE_PORT: "5432"
          DATABASE_SSLMODE: "disable"
          REDIS_HOST: "${redisAddress}"
          REDIS_PORT: "6379"
          REDIS_DB: "0"
          REDIS_ENABLE_TLS: "false"
          TZ: "${cfg.timeZone}"
          TRUST_PROXY: "true"
          UPDATE_PROXY_URL: "${cfg.updateProxyUrl}"
        volumes:
          - ${cfg.dataDir}/data:/app/data:Z
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy
        networks:
          sub2api:
            ipv4_address: ${sub2apiAddress}
        healthcheck:
          test: ["CMD", "wget", "-q", "-T", "5", "-O", "/dev/null", "http://localhost:8080/health"]
          interval: 30s
          timeout: 10s
          retries: 3
          start_period: 30s

      postgres:
        image: ${cfg.postgresImage}
        restart: unless-stopped
        ulimits:
          nofile:
            soft: 100000
            hard: 100000
        env_file:
          - ${cfg.dataDir}/runtime.env
        environment:
          PGDATA: /var/lib/postgresql/data
          TZ: "${cfg.timeZone}"
        volumes:
          - ${cfg.dataDir}/postgres:/var/lib/postgresql/data:Z
        networks:
          sub2api:
            ipv4_address: ${postgresAddress}
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U sub2api -d sub2api"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 10s

      redis:
        image: ${cfg.redisImage}
        restart: unless-stopped
        ulimits:
          nofile:
            soft: 100000
            hard: 100000
        env_file:
          - ${cfg.dataDir}/runtime.env
        command:
          - sh
          - -c
          - |
            redis-server --save 60 1 --appendonly yes --appendfsync everysec $''${REDIS_PASSWORD:+--requirepass "$''${REDIS_PASSWORD}"}
        volumes:
          - ${cfg.dataDir}/redis:/data:Z
        networks:
          sub2api:
            ipv4_address: ${redisAddress}
        healthcheck:
          test: ["CMD", "redis-cli", "ping"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 5s

    networks:
      sub2api:
        external: true
        name: ${networkName}
  '';
in
{
  imports = [
    ./container-runtime
  ];

  options.services.sub2api = {
    enable = lib.mkEnableOption "Sub2API container stack";

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HTTPS domain for Sub2API.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sub2api";
      description = "Persistent data directory for Sub2API, PostgreSQL, Redis, and generated runtime secrets.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 13001;
      description = "Loopback HTTP port exposed by the Sub2API container.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local address Caddy binds for the Sub2API HTTPS virtual host.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = defaultImage;
      description = "Container image reference for Sub2API, ideally pinned by tag and digest.";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = defaultPostgresImage;
      description = "Container image reference for the Sub2API PostgreSQL service.";
    };

    redisImage = lib.mkOption {
      type = lib.types.str;
      default = defaultRedisImage;
      description = "Container image reference for the Sub2API Redis service.";
    };

    adminEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@sub2api.local";
      description = "Bootstrap administrator email for Sub2API.";
    };

    serverMode = lib.mkOption {
      type = lib.types.enum [ "release" "debug" ];
      default = "release";
      description = "Sub2API server mode.";
    };

    runMode = lib.mkOption {
      type = lib.types.enum [ "standard" "simple" ];
      default = "standard";
      description = "Sub2API run mode.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Asia/Shanghai";
      description = "Timezone passed to Sub2API, PostgreSQL, and Redis containers.";
    };

    updateProxyUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Optional proxy URL used by Sub2API for online updates and pricing data.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.domain != null;
        message = "services.sub2api.domain must be set when services.sub2api.enable = true";
      }
    ];

    containerRuntime.enable = true;
    containerRuntime.dockerCompat = true;

    environment.systemPackages = with pkgs; [
      curl
      jq
      podman-compose
    ];

    environment.etc."${serviceName}/docker-compose.yml".source = composeFile;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.dataDir}/data 0750 root root - -"
      "d ${cfg.dataDir}/postgres 0750 root root - -"
      "d ${cfg.dataDir}/redis 0750 root root - -"
      "d ${cfg.dataDir}/secrets 0700 root root - -"
    ];

    services.caddy.virtualHosts."${cfg.domain}".extraConfig = ''
      bind ${cfg.bindAddress}
      tls {
        dns alidns {
          access_key_id {env.ALICLOUD_ACCESS_KEY}
          access_key_secret {env.ALICLOUD_SECRET_KEY}
        }
        resolvers 1.1.1.1 8.8.8.8
      }
      encode zstd gzip
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

        install -d -m 0750 ${cfg.dataDir}/data
        install -d -m 0750 ${cfg.dataDir}/postgres
        install -d -m 0750 ${cfg.dataDir}/redis
        install -d -m 0700 ${cfg.dataDir}/secrets

        make_secret() {
          local path="$1"
          local bytes="$2"

          if [ ! -s "$path" ]; then
            od -An -N"$bytes" -tx1 /dev/urandom | tr -d ' \n' > "$path"
            printf '\n' >> "$path"
            chmod 0600 "$path"
          fi
        }

        make_secret ${cfg.dataDir}/secrets/postgres-password 24
        make_secret ${cfg.dataDir}/secrets/redis-password 24
        make_secret ${cfg.dataDir}/secrets/admin-password 12
        make_secret ${cfg.dataDir}/secrets/jwt-secret 32
        make_secret ${cfg.dataDir}/secrets/totp-encryption-key 32

        {
          echo "POSTGRES_USER=sub2api"
          echo "POSTGRES_PASSWORD=$(tr -d '\n' < ${cfg.dataDir}/secrets/postgres-password)"
          echo "POSTGRES_DB=sub2api"
          echo "DATABASE_USER=sub2api"
          echo "DATABASE_PASSWORD=$(tr -d '\n' < ${cfg.dataDir}/secrets/postgres-password)"
          echo "REDIS_PASSWORD=$(tr -d '\n' < ${cfg.dataDir}/secrets/redis-password)"
          echo "REDISCLI_AUTH=$(tr -d '\n' < ${cfg.dataDir}/secrets/redis-password)"
          echo "ADMIN_EMAIL=${cfg.adminEmail}"
          echo "ADMIN_PASSWORD=$(tr -d '\n' < ${cfg.dataDir}/secrets/admin-password)"
          echo "JWT_SECRET=$(tr -d '\n' < ${cfg.dataDir}/secrets/jwt-secret)"
          echo "JWT_EXPIRE_HOUR=24"
          echo "TOTP_ENCRYPTION_KEY=$(tr -d '\n' < ${cfg.dataDir}/secrets/totp-encryption-key)"
          echo "LOG_LEVEL=info"
          echo "LOG_FORMAT=json"
          echo "LOG_SERVICE_NAME=sub2api"
          echo "LOG_ENV=production"
          echo "LOG_OUTPUT_TO_STDOUT=true"
          echo "LOG_OUTPUT_TO_FILE=true"
          echo "OPS_ENABLED=true"
          echo "SECURITY_URL_ALLOWLIST_ENABLED=false"
          echo "SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false"
          echo "SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false"
          echo "GATEWAY_MAX_BODY_SIZE=268435456"
          echo "SERVER_MAX_REQUEST_BODY_SIZE=268435456"
          echo "SERVER_H2C_ENABLED=true"
          echo "SERVER_H2C_MAX_CONCURRENT_STREAMS=50"
        } > ${cfg.dataDir}/runtime.env
        chmod 0600 ${cfg.dataDir}/runtime.env
      '';
    };

    systemd.services.sub2api-network = {
      description = "Prepare Podman network for Sub2API";
      wantedBy = [ "multi-user.target" ];
      before = [ "sub2api.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ podman ];
      script = ''
        set -euo pipefail

        if ! podman network inspect ${networkName} >/dev/null 2>&1; then
          podman network create --subnet ${networkSubnet} --disable-dns ${networkName}
        fi
      '';
    };

    systemd.services.sub2api = {
      description = "Sub2API container stack";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "sub2api-prepare.service" "sub2api-network.service" ];
      wants = [ "network-online.target" "sub2api-prepare.service" "sub2api-network.service" ];
      requires = [ "sub2api-prepare.service" "sub2api-network.service" ];
      restartTriggers = [ composeFile ];
      path = with pkgs; [ podman podman-compose ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/etc/${serviceName}";
        ExecStartPre = [
          "${cleanupStaleHealthcheckUnits}"
          "${pkgs.podman}/bin/podman pull ${cfg.image}"
          "${pkgs.podman}/bin/podman pull ${cfg.postgresImage}"
          "${pkgs.podman}/bin/podman pull ${cfg.redisImage}"
        ];
        ExecStart = "${pkgs.podman-compose}/bin/podman-compose -f /etc/${serviceName}/docker-compose.yml up -d";
        ExecStartPost = [
          "${waitForSub2apiReady}"
          "${cleanupStaleHealthcheckUnits}"
        ];
        ExecStop = "${pkgs.podman-compose}/bin/podman-compose -f /etc/${serviceName}/docker-compose.yml down";
        ExecStopPost = [ "${cleanupStaleHealthcheckUnits}" ];
        TimeoutStartSec = 420;
        TimeoutStopSec = 60;
      };
    };
  };
}
