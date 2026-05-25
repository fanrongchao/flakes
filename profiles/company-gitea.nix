{ config, lib, pkgs, ... }:

let
  cfg = config.services.companyGitea;
  giteaCfg = config.services.gitea;
  giteaExe = lib.getExe giteaCfg.package;
  authSourceName = "Keycloak";
in
{
  options.services.companyGitea = {
    enable = lib.mkEnableOption "company Gitea code hosting service";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "code.xfa.cn";
      description = "Public URL hostname used by Gitea.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTP port for Gitea.";
    };

    httpListenHost = lib.mkOption {
      type = lib.types.str;
      default = "192.168.3.88";
      description = "Address where Gitea's HTTP server listens for the ingress proxy.";
    };

    sshListenHost = lib.mkOption {
      type = lib.types.str;
      default = "192.168.3.88";
      description = "Address where Gitea's built-in SSH server listens.";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Internal and externally advertised Gitea SSH port.";
    };

    keycloakIssuer = lib.mkOption {
      type = lib.types.str;
      default = "https://auth.zhsjf.cn/realms/zhsjf";
      description = "Keycloak issuer URL used for Gitea OIDC login.";
    };

    keycloakHostAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.3.111";
      description = "Internal address used by this host to reach Keycloak.";
    };

    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "breakglass-admin";
      description = "Local Gitea administrator kept for break-glass access.";
    };

    adminEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@code.xfa.cn";
      description = "Email address for the local break-glass administrator.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.age.sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.secrets."gitea/admin_password" = {
      sopsFile = ../secrets/identity.yaml;
      restartUnits = [ "gitea-bootstrap.service" ];
    };

    sops.secrets."gitea/oidc_client_secret" = {
      sopsFile = ../secrets/identity.yaml;
      restartUnits = [ "gitea-bootstrap.service" ];
    };

    networking.hosts."${cfg.keycloakHostAddress}" = [ "auth.zhsjf.cn" ];
    networking.firewall.allowedTCPPorts = [
      cfg.httpPort
      cfg.sshPort
    ];

    services.gitea = {
      enable = true;
      appName = "XFA Code";

      database = {
        type = "postgres";
        createDatabase = true;
      };

      dump = {
        enable = true;
        interval = "04:31";
        type = "zip";
      };

      settings = {
        server = {
          DOMAIN = cfg.domain;
          ROOT_URL = "https://${cfg.domain}/";
          HTTP_ADDR = cfg.httpListenHost;
          HTTP_PORT = cfg.httpPort;
          DISABLE_SSH = false;
          START_SSH_SERVER = true;
          BUILTIN_SSH_SERVER_USER = "git";
          SSH_DOMAIN = cfg.domain;
          SSH_USER = "git";
          SSH_PORT = cfg.sshPort;
          SSH_LISTEN_HOST = cfg.sshListenHost;
          SSH_LISTEN_PORT = cfg.sshPort;
        };

        service = {
          DISABLE_REGISTRATION = false;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = false;
          REQUIRE_SIGNIN_VIEW = true;
          SHOW_REGISTRATION_BUTTON = false;
        };

        oauth2_client = {
          ENABLE_AUTO_REGISTRATION = true;
          OPENID_CONNECT_SCOPES = "profile email groups";
          USERNAME = "preferred_username";
          ACCOUNT_LINKING = "disabled";
        };

        repository = {
          DEFAULT_PRIVATE = "private";
        };

        session = {
          COOKIE_SECURE = true;
        };
      };
    };

    systemd.services.gitea-bootstrap = {
      description = "Bootstrap XFA Gitea admin and Keycloak OIDC source";
      after = [ "network-online.target" "gitea.service" ];
      wants = [ "network-online.target" ];
      requires = [ "gitea.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ gawk giteaCfg.package gnugrep ];

      environment = {
        USER = giteaCfg.user;
        HOME = giteaCfg.stateDir;
        GITEA_WORK_DIR = giteaCfg.stateDir;
        GITEA_CUSTOM = giteaCfg.customDir;
      };

      serviceConfig = {
        Type = "oneshot";
        User = giteaCfg.user;
        Group = giteaCfg.group;
        WorkingDirectory = giteaCfg.stateDir;
        LoadCredential = [
          "admin_password:${config.sops.secrets."gitea/admin_password".path}"
          "oidc_client_secret:${config.sops.secrets."gitea/oidc_client_secret".path}"
        ];
      };

      script = ''
        set -euo pipefail

        admin_password="$(${pkgs.coreutils}/bin/tr -d '\n' < "$CREDENTIALS_DIRECTORY/admin_password")"
        oidc_client_secret="$(${pkgs.coreutils}/bin/tr -d '\n' < "$CREDENTIALS_DIRECTORY/oidc_client_secret")"

        if ! ${giteaExe} admin user list \
          | ${pkgs.gawk}/bin/awk 'NR > 1 && $2 == "${cfg.adminUsername}" { found = 1 } END { exit !found }'; then
          ${giteaExe} admin user create \
            --username ${lib.escapeShellArg cfg.adminUsername} \
            --email ${lib.escapeShellArg cfg.adminEmail} \
            --password "$admin_password" \
            --admin \
            --must-change-password=false
        else
          ${giteaExe} admin user change-password \
            --username ${lib.escapeShellArg cfg.adminUsername} \
            --password "$admin_password" \
            --must-change-password=false
        fi

        auth_source_id="$(
          ${giteaExe} admin auth list \
            | ${pkgs.gawk}/bin/awk 'NR > 1 && $2 == "${authSourceName}" { print $1; exit }'
        )"

        oauth_args=(
          --name ${lib.escapeShellArg authSourceName}
          --provider openidConnect
          --key gitea
          --secret "$oidc_client_secret"
          --auto-discover-url ${lib.escapeShellArg "${cfg.keycloakIssuer}/.well-known/openid-configuration"}
          --scopes profile
          --scopes email
          --scopes groups
          --required-claim-name groups
          --required-claim-value gitea_users
          --group-claim-name groups
          --skip-local-2fa
        )

        if [ -n "$auth_source_id" ]; then
          ${giteaExe} admin auth update-oauth --id "$auth_source_id" "''${oauth_args[@]}"
        else
          ${giteaExe} admin auth add-oauth "''${oauth_args[@]}"
        fi
      '';
    };
  };
}
