{ config, pkgs, lib, ... }:

let
  cfg = config.services.companyIdentityKeycloak;
in {
  options.services.companyIdentityKeycloak = {
    enable = lib.mkEnableOption "company identity Keycloak on ai-server";

    host = lib.mkOption {
      type = lib.types.str;
      example = "auth.example.com";
      description = "Public hostname for Keycloak.";
    };

    realm = lib.mkOption {
      type = lib.types.str;
      default = "zhsjf";
      example = "company";
      description = "Primary realm imported during bootstrap.";
    };

    headscaleHost = lib.mkOption {
      type = lib.types.str;
      example = "hs.example.com";
      description = "Headscale hostname used for the initial OIDC client.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Loopback HTTP port used by Keycloak behind Caddy.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      headscaleClientSecretPath = config.sops.secrets."headscale/oidc_client_secret".path;
      headscaleClientSecretPlaceholder = lib.hashString "sha256" headscaleClientSecretPath;
      realmImportName = "${cfg.realm}-realm.json";
      realmImportRuntimeSource = "/run/keycloak-realms/${realmImportName}";
      realmImportTemplate = pkgs.writeText realmImportName (builtins.toJSON {
        realm = cfg.realm;
        enabled = true;
        displayName = "ZHSJF";
        registrationAllowed = false;
        loginWithEmailAllowed = true;
        duplicateEmailsAllowed = false;
        editUsernameAllowed = false;
        resetPasswordAllowed = true;
        rememberMe = true;
        verifyEmail = false;
        otpPolicyType = "totp";
        otpPolicyAlgorithm = "HmacSHA1";
        otpPolicyDigits = 6;
        otpPolicyPeriod = 30;
        otpPolicyLookAheadWindow = 1;
        groups = map (name: { inherit name; }) [
          "employees"
          "headscale_users"
          "tailnet_admins"
          "airs_admins"
        ];
        requiredActions = [
          {
            alias = "CONFIGURE_TOTP";
            name = "Configure OTP";
            providerId = "CONFIGURE_TOTP";
            enabled = true;
            defaultAction = false;
            priority = 10;
          }
          {
            alias = "UPDATE_PASSWORD";
            name = "Update Password";
            providerId = "UPDATE_PASSWORD";
            enabled = true;
            defaultAction = false;
            priority = 20;
          }
          {
            alias = "webauthn-register";
            name = "Webauthn Register";
            providerId = "webauthn-register";
            enabled = true;
            defaultAction = false;
            priority = 30;
          }
          {
            alias = "webauthn-register-passwordless";
            name = "Webauthn Register Passwordless";
            providerId = "webauthn-register-passwordless";
            enabled = true;
            defaultAction = false;
            priority = 40;
          }
        ];
        clientScopes = [
          {
            name = "groups";
            description = "Expose group membership to OIDC clients.";
            protocol = "openid-connect";
            attributes = {
              "include.in.token.scope" = "true";
              "display.on.consent.screen" = "false";
              "gui.order" = "2";
            };
            protocolMappers = [
              {
                name = "groups";
                protocol = "openid-connect";
                protocolMapper = "oidc-group-membership-mapper";
                consentRequired = false;
                config = {
                  "full.path" = "false";
                  "id.token.claim" = "true";
                  "access.token.claim" = "true";
                  "userinfo.token.claim" = "true";
                  "claim.name" = "groups";
                };
              }
            ];
          }
        ];
        clients = [
          {
            clientId = "headscale";
            name = "Headscale";
            description = "OIDC login for Headscale";
            enabled = true;
            protocol = "openid-connect";
            publicClient = false;
            standardFlowEnabled = true;
            implicitFlowEnabled = false;
            directAccessGrantsEnabled = false;
            serviceAccountsEnabled = false;
            frontchannelLogout = true;
            redirectUris = [
              "https://${cfg.headscaleHost}/oidc/callback"
            ];
            webOrigins = [
              "https://${cfg.headscaleHost}"
            ];
            secret = headscaleClientSecretPlaceholder;
            attributes = {
              "pkce.code.challenge.method" = "S256";
              "post.logout.redirect.uris" = "+";
            };
            defaultClientScopes = [
              "profile"
              "email"
              "roles"
              "web-origins"
              "groups"
            ];
            optionalClientScopes = [
              "address"
              "phone"
              "offline_access"
              "microprofile-jwt"
            ];
          }
        ];
      });
    in {
      sops.secrets."keycloak/bootstrap_admin_password" = {
        sopsFile = ../secrets/identity.yaml;
        restartUnits = [ "keycloak.service" ];
      };

      sops.secrets."keycloak/database_password" = {
        sopsFile = ../secrets/identity.yaml;
        restartUnits = [
          "keycloak.service"
          "keycloakPostgreSQLInit.service"
        ];
      };

      sops.secrets."headscale/oidc_client_secret" = {
        sopsFile = ../secrets/identity.yaml;
        restartUnits = [
          "keycloak.service"
          "headscale.service"
        ];
      };

      sops.templates."keycloak-bootstrap-admin.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          KC_BOOTSTRAP_ADMIN_USERNAME=admin
          KC_BOOTSTRAP_ADMIN_PASSWORD=${config.sops.placeholder."keycloak/bootstrap_admin_password"}
        '';
      };

      services.keycloak = {
        enable = true;
        database = {
          type = "postgresql";
          passwordFile = config.sops.secrets."keycloak/database_password".path;
        };
        realmFiles = [ realmImportRuntimeSource ];
        settings = {
          hostname = cfg.host;
          "http-enabled" = true;
          "http-host" = "127.0.0.1";
          "http-port" = cfg.httpPort;
          "proxy-headers" = "xforwarded";
          "proxy-trusted-addresses" = "127.0.0.1,::1";
          "health-enabled" = true;
          "metrics-enabled" = true;
        };
      };

      systemd.services.keycloak = {
        preStart = lib.mkBefore ''
          install -d -m 0700 /run/keycloak-realms

          rm -f ${lib.escapeShellArg realmImportRuntimeSource}
          install -D -m 0600 ${realmImportTemplate} ${lib.escapeShellArg realmImportRuntimeSource}
          ${pkgs.replace-secret}/bin/replace-secret \
            ${headscaleClientSecretPlaceholder} \
            "$CREDENTIALS_DIRECTORY/headscale_oidc_client_secret" \
            ${lib.escapeShellArg realmImportRuntimeSource}
        '';

        serviceConfig = {
          EnvironmentFile = lib.mkAfter [
            config.sops.templates."keycloak-bootstrap-admin.env".path
          ];
          LoadCredential = lib.mkAfter [
            "headscale_oidc_client_secret:${headscaleClientSecretPath}"
          ];
        };
      };
    }
  );
}
