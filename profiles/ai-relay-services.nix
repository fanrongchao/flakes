{ config, lib, pkgs, ... }:

let
  cfg = config.services.aiRelayServices;
  serviceName = "ai-relay-services";
  legacyDir = "/home/xfa/code/claude-relay-service";
  networkName = "ai-relay-services_default";
  networkSubnet = "10.234.0.0/24";
  redisAddress = "10.234.0.11";
  relayAddress = "10.234.0.12";
  composeFile = pkgs.writeText "ai-relay-services-compose.yml" ''
    services:
      redis:
        image: docker.io/redis:7-alpine
        restart: unless-stopped
        command: ["redis-server", "--save", "60", "1", "--appendonly", "yes", "--appendfsync", "everysec"]
        volumes:
          - ${cfg.dataDir}/redis:/data:Z
        networks:
          airs:
            ipv4_address: ${redisAddress}

      claude-relay:
        image: docker.io/weishaw/claude-relay-service:latest
        restart: unless-stopped
        depends_on:
          - redis
        ports:
          - "127.0.0.1:${toString cfg.listenPort}:3000"
        env_file:
          - ${cfg.dataDir}/runtime.env
        volumes:
          - ${cfg.dataDir}/logs:/app/logs:Z
          - ${cfg.dataDir}/data:/app/data:Z
        networks:
          airs:
            ipv4_address: ${relayAddress}
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
          interval: 30s
          timeout: 10s
          retries: 3

    networks:
      airs:
        external: true
        name: ${networkName}
  '';
in
{
  imports = [
    ./container-runtime
  ];

  options.services.aiRelayServices = {
    enable = lib.mkEnableOption "AIRS (AI Relay Services) container stack";

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Public HTTPS domain for AIRS.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ai-relay-services";
      description = "Persistent data directory for AIRS.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 13000;
      description = "Loopback HTTP port exposed by the AIRS container.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local address Caddy binds for the AIRS HTTPS virtual host.";
    };

    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Bootstrap administrator username for AIRS.";
    };

    apiKeyPrefix = lib.mkOption {
      type = lib.types.str;
      default = "cr_";
      description = "Prefix for newly created AIRS API keys.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.domain != null;
        message = "services.aiRelayServices.domain must be set when services.aiRelayServices.enable = true";
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
      "d ${cfg.dataDir}/logs 0750 root root - -"
      "d ${cfg.dataDir}/redis 0750 root root - -"
      "d ${cfg.dataDir}/secrets 0700 root root - -"
      "d ${cfg.dataDir}/tmp 0750 root root - -"
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
      reverse_proxy 127.0.0.1:${toString cfg.listenPort}
    '';

    systemd.services.ai-relay-services-migrate = {
      description = "Migrate legacy manual AIRS state";
      wantedBy = [ "multi-user.target" ];
      before = [ "ai-relay-services-prepare.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ coreutils rsync gnused ];
      script = ''
        set -euo pipefail

        if [ -e ${cfg.dataDir}/migration-complete ]; then
          exit 0
        fi

        if [ ! -d ${legacyDir} ]; then
          touch ${cfg.dataDir}/migration-complete
          exit 0
        fi

        if [ -f ${legacyDir}/.env ]; then
          extract_env() {
            local key="$1"
            sed -n "s/^''${key}=//p" ${legacyDir}/.env | tail -n 1
          }

          install -d -m 0700 ${cfg.dataDir}/secrets

          if [ ! -s ${cfg.dataDir}/secrets/jwt-secret ]; then
            extract_env JWT_SECRET > ${cfg.dataDir}/secrets/jwt-secret || true
          fi

          if [ ! -s ${cfg.dataDir}/secrets/encryption-key ]; then
            extract_env ENCRYPTION_KEY > ${cfg.dataDir}/secrets/encryption-key || true
          fi

          if [ ! -s ${cfg.dataDir}/secrets/admin-username ]; then
            extract_env ADMIN_USERNAME > ${cfg.dataDir}/secrets/admin-username || true
          fi

          if [ ! -s ${cfg.dataDir}/secrets/admin-password ]; then
            extract_env ADMIN_PASSWORD > ${cfg.dataDir}/secrets/admin-password || true
          fi
        fi

        if [ -d ${legacyDir}/data ]; then
          ${pkgs.rsync}/bin/rsync -a ${legacyDir}/data/ ${cfg.dataDir}/data/
        fi

        if [ -d ${legacyDir}/logs ]; then
          ${pkgs.rsync}/bin/rsync -a ${legacyDir}/logs/ ${cfg.dataDir}/logs/
        fi

        if [ -d ${legacyDir}/redis_data ]; then
          ${pkgs.rsync}/bin/rsync -a ${legacyDir}/redis_data/ ${cfg.dataDir}/redis/
        fi

        touch ${cfg.dataDir}/migration-complete
      '';
    };

    systemd.services.ai-relay-services-prepare = {
      description = "Prepare persistent state for AIRS";
      wantedBy = [ "multi-user.target" ];
      before = [ "ai-relay-services.service" ];
      after = [ "ai-relay-services-migrate.service" ];
      requires = [ "ai-relay-services-migrate.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ coreutils ];
      script = ''
        set -euo pipefail

        install -d -m 0700 ${cfg.dataDir}/secrets

        if [ ! -s ${cfg.dataDir}/secrets/jwt-secret ]; then
          od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > ${cfg.dataDir}/secrets/jwt-secret
          printf '\n' >> ${cfg.dataDir}/secrets/jwt-secret
        fi

        if [ ! -s ${cfg.dataDir}/secrets/encryption-key ]; then
          od -An -N16 -tx1 /dev/urandom | tr -d ' \n' > ${cfg.dataDir}/secrets/encryption-key
          printf '\n' >> ${cfg.dataDir}/secrets/encryption-key
        fi

        if [ ! -s ${cfg.dataDir}/secrets/admin-username ]; then
          printf '%s\n' '${cfg.adminUsername}' > ${cfg.dataDir}/secrets/admin-username
        fi

        if [ ! -s ${cfg.dataDir}/secrets/admin-password ]; then
          od -An -N12 -tx1 /dev/urandom | tr -d ' \n' > ${cfg.dataDir}/secrets/admin-password
          printf '\n' >> ${cfg.dataDir}/secrets/admin-password
        fi

        {
          echo "NODE_ENV=production"
          echo "PORT=3000"
          echo "HOST=0.0.0.0"
          echo "JWT_SECRET=$(tr -d '\n' < ${cfg.dataDir}/secrets/jwt-secret)"
          echo "ENCRYPTION_KEY=$(tr -d '\n' < ${cfg.dataDir}/secrets/encryption-key)"
          echo "ADMIN_USERNAME=$(tr -d '\n' < ${cfg.dataDir}/secrets/admin-username)"
          echo "ADMIN_PASSWORD=$(tr -d '\n' < ${cfg.dataDir}/secrets/admin-password)"
          echo "ADMIN_SESSION_TIMEOUT=86400000"
          echo "API_KEY_PREFIX=${cfg.apiKeyPrefix}"
          echo "REDIS_HOST=${redisAddress}"
          echo "REDIS_PORT=6379"
          echo "REDIS_PASSWORD="
          echo "REDIS_DB=0"
          echo "REQUEST_MAX_SIZE_MB=60"
          echo "DEFAULT_PROXY_TIMEOUT=60000"
          echo "MAX_PROXY_RETRIES=3"
          echo "PROXY_USE_IPV4=true"
          echo "DEFAULT_TOKEN_LIMIT=1000000"
          echo "LOG_LEVEL=info"
          echo "LOG_MAX_SIZE=10m"
          echo "LOG_MAX_FILES=5"
          echo "CLEANUP_INTERVAL=3600000"
          echo "TOKEN_USAGE_RETENTION=2592000000"
          echo "HEALTH_CHECK_INTERVAL=60000"
          echo "TIMEZONE_OFFSET=8"
          echo "WEB_TITLE=AIRS"
          echo "WEB_DESCRIPTION=AI Relay Services"
          echo "WEB_LOGO_URL=/assets/logo.png"
          echo "DEBUG=false"
          echo "ENABLE_CORS=true"
          echo "TRUST_PROXY=true"
          echo "STICKY_SESSION_TTL_HOURS=1"
          echo "STICKY_SESSION_RENEWAL_THRESHOLD_MINUTES=15"
        } > ${cfg.dataDir}/runtime.env
        chmod 0600 ${cfg.dataDir}/runtime.env
      '';
    };

    systemd.services.ai-relay-services-network = {
      description = "Prepare Podman network for AIRS";
      wantedBy = [ "multi-user.target" ];
      before = [ "ai-relay-services.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ podman ];
      script = ''
        set -euo pipefail

        if ! podman network inspect ${networkName} >/dev/null 2>&1; then
          podman network create --subnet ${networkSubnet} --disable-dns ${networkName}
        fi
      '';
    };

    systemd.services.ai-relay-services = {
      description = "AIRS container stack";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "ai-relay-services-prepare.service" "ai-relay-services-network.service" ];
      wants = [ "network-online.target" "ai-relay-services-prepare.service" "ai-relay-services-network.service" ];
      requires = [ "ai-relay-services-prepare.service" "ai-relay-services-network.service" ];
      restartTriggers = [ composeFile ];
      path = with pkgs; [ podman podman-compose ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/etc/${serviceName}";
        ExecStart = "${pkgs.podman-compose}/bin/podman-compose -f /etc/${serviceName}/docker-compose.yml up -d";
        ExecStop = "${pkgs.podman-compose}/bin/podman-compose -f /etc/${serviceName}/docker-compose.yml down";
        TimeoutStartSec = 300;
        TimeoutStopSec = 60;
      };
    };
  };
}
