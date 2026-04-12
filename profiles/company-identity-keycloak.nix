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
      boolString = value: if value then "true" else "false";
      oidcProtocol = "openid-connect";
      oidcBaseDefaultClientScopes = [
        "web-origins"
        "acr"
        "roles"
        "profile"
        "basic"
        "email"
      ];
      oidcBaseOptionalClientScopes = [
        "address"
        "phone"
        "organization"
        "offline_access"
        "microprofile-jwt"
      ];
      mkMapper = {
        name,
        protocolMapper,
        config,
        protocol ? oidcProtocol,
        consentRequired ? false,
      }: {
        inherit name protocol protocolMapper consentRequired config;
      };
      mkUserAttributeMapper = {
        name,
        claimName,
        userAttribute,
        jsonType ? "String",
        accessToken ? true,
        idToken ? true,
        introspectionToken ? true,
        userinfoToken ? true,
      }:
        mkMapper {
          inherit name;
          protocolMapper = "oidc-usermodel-attribute-mapper";
          config = {
            "user.attribute" = userAttribute;
            "claim.name" = claimName;
            "jsonType.label" = jsonType;
            "access.token.claim" = boolString accessToken;
            "id.token.claim" = boolString idToken;
            "introspection.token.claim" = boolString introspectionToken;
            "userinfo.token.claim" = boolString userinfoToken;
          };
        };
      mkUserPropertyMapper = {
        name,
        claimName,
        userAttribute,
        jsonType,
        accessToken ? true,
        idToken ? true,
        introspectionToken ? true,
        userinfoToken ? true,
      }:
        mkMapper {
          inherit name;
          protocolMapper = "oidc-usermodel-property-mapper";
          config = {
            "user.attribute" = userAttribute;
            "claim.name" = claimName;
            "jsonType.label" = jsonType;
            "access.token.claim" = boolString accessToken;
            "id.token.claim" = boolString idToken;
            "introspection.token.claim" = boolString introspectionToken;
            "userinfo.token.claim" = boolString userinfoToken;
          };
        };
      mkUserSessionNoteMapper = {
        name,
        claimName,
        note,
        jsonType,
        accessToken ? true,
        idToken ? true,
        introspectionToken ? true,
      }:
        mkMapper {
          inherit name;
          protocolMapper = "oidc-usersessionmodel-note-mapper";
          config = {
            "user.session.note" = note;
            "claim.name" = claimName;
            "jsonType.label" = jsonType;
            "access.token.claim" = boolString accessToken;
            "id.token.claim" = boolString idToken;
            "introspection.token.claim" = boolString introspectionToken;
          };
        };
      mkRealmRoleMapper = {
        name,
        claimName,
        accessToken ? true,
        idToken ? false,
        introspectionToken ? true,
      }:
        mkMapper {
          inherit name;
          protocolMapper = "oidc-usermodel-realm-role-mapper";
          config = {
            "claim.name" = claimName;
            "jsonType.label" = "String";
            "multivalued" = "true";
            "user.attribute" = "foo";
            "access.token.claim" = boolString accessToken;
            "id.token.claim" = boolString idToken;
            "introspection.token.claim" = boolString introspectionToken;
          };
        };
      mkClientRoleMapper = {
        name,
        claimName,
        accessToken ? true,
        introspectionToken ? true,
      }:
        mkMapper {
          inherit name;
          protocolMapper = "oidc-usermodel-client-role-mapper";
          config = {
            "claim.name" = claimName;
            "jsonType.label" = "String";
            "multivalued" = "true";
            "user.attribute" = "foo";
            "access.token.claim" = boolString accessToken;
            "introspection.token.claim" = boolString introspectionToken;
          };
        };
      mkScope = {
        name,
        description,
        attributes,
        protocolMappers ? [],
      }: {
        inherit name description attributes protocolMappers;
        protocol = oidcProtocol;
      };
      realmImportName = "${cfg.realm}-realm.json";
      realmImportRuntimeSource = "/run/keycloak/data/import/${realmImportName}";
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
        defaultDefaultClientScopes = oidcBaseDefaultClientScopes;
        defaultOptionalClientScopes = oidcBaseOptionalClientScopes;
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
            defaultAction = true;
            priority = 10;
          }
          {
            alias = "UPDATE_PASSWORD";
            name = "Update Password";
            providerId = "UPDATE_PASSWORD";
            enabled = true;
            defaultAction = true;
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
          (mkScope {
            name = "acr";
            description = "OpenID Connect scope for add acr (authentication context class reference) to the token";
            attributes = {
              "display.on.consent.screen" = "false";
              "include.in.token.scope" = "false";
            };
            protocolMappers = [
              (mkMapper {
                name = "acr loa level";
                protocolMapper = "oidc-acr-mapper";
                config = {
                  "access.token.claim" = "true";
                  "id.token.claim" = "true";
                  "introspection.token.claim" = "true";
                };
              })
            ];
          })
          (mkScope {
            name = "address";
            description = "OpenID Connect built-in scope: address";
            attributes = {
              "consent.screen.text" = "\${addressScopeConsentText}";
              "display.on.consent.screen" = "true";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkMapper {
                name = "address";
                protocolMapper = "oidc-address-mapper";
                config = {
                  "access.token.claim" = "true";
                  "id.token.claim" = "true";
                  "introspection.token.claim" = "true";
                  "userinfo.token.claim" = "true";
                  "user.attribute.country" = "country";
                  "user.attribute.formatted" = "formatted";
                  "user.attribute.locality" = "locality";
                  "user.attribute.postal_code" = "postal_code";
                  "user.attribute.region" = "region";
                  "user.attribute.street" = "street";
                };
              })
            ];
          })
          (mkScope {
            name = "basic";
            description = "OpenID Connect scope for add all basic claims to the token";
            attributes = {
              "display.on.consent.screen" = "false";
              "include.in.token.scope" = "false";
            };
            protocolMappers = [
              (mkUserSessionNoteMapper {
                name = "auth_time";
                claimName = "auth_time";
                note = "AUTH_TIME";
                jsonType = "long";
              })
              (mkMapper {
                name = "sub";
                protocolMapper = "oidc-sub-mapper";
                config = {
                  "access.token.claim" = "true";
                  "introspection.token.claim" = "true";
                };
              })
            ];
          })
          (mkScope {
            name = "email";
            description = "OpenID Connect built-in scope: email";
            attributes = {
              "consent.screen.text" = "\${emailScopeConsentText}";
              "display.on.consent.screen" = "true";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkUserAttributeMapper {
                name = "email";
                claimName = "email";
                userAttribute = "email";
              })
              (mkUserPropertyMapper {
                name = "email verified";
                claimName = "email_verified";
                userAttribute = "emailVerified";
                jsonType = "boolean";
              })
            ];
          })
          (mkScope {
            name = "groups";
            description = "Expose group membership to OIDC clients.";
            attributes = {
              "display.on.consent.screen" = "false";
              "gui.order" = "2";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkMapper {
                name = "groups";
                protocolMapper = "oidc-group-membership-mapper";
                config = {
                  "access.token.claim" = "true";
                  "claim.name" = "groups";
                  "full.path" = "false";
                  "id.token.claim" = "true";
                  "userinfo.token.claim" = "true";
                };
              })
            ];
          })
          (mkScope {
            name = "microprofile-jwt";
            description = "Microprofile - JWT built-in scope";
            attributes = {
              "display.on.consent.screen" = "false";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkMapper {
                name = "groups";
                protocolMapper = "oidc-usermodel-realm-role-mapper";
                config = {
                  "access.token.claim" = "true";
                  "claim.name" = "groups";
                  "id.token.claim" = "true";
                  "introspection.token.claim" = "true";
                  "jsonType.label" = "String";
                  "multivalued" = "true";
                  "user.attribute" = "foo";
                };
              })
              (mkUserAttributeMapper {
                name = "upn";
                claimName = "upn";
                userAttribute = "username";
              })
            ];
          })
          (mkScope {
            name = "offline_access";
            description = "OpenID Connect built-in scope: offline_access";
            attributes = {
              "consent.screen.text" = "\${offlineAccessScopeConsentText}";
              "display.on.consent.screen" = "true";
            };
          })
          (mkScope {
            name = "organization";
            description = "Additional claims about the organization a subject belongs to";
            attributes = {
              "consent.screen.text" = "\${organizationScopeConsentText}";
              "display.on.consent.screen" = "true";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkMapper {
                name = "organization";
                protocolMapper = "oidc-organization-membership-mapper";
                config = {
                  "access.token.claim" = "true";
                  "claim.name" = "organization";
                  "id.token.claim" = "true";
                  "introspection.token.claim" = "true";
                  "jsonType.label" = "String";
                  "multivalued" = "true";
                };
              })
            ];
          })
          (mkScope {
            name = "phone";
            description = "OpenID Connect built-in scope: phone";
            attributes = {
              "consent.screen.text" = "\${phoneScopeConsentText}";
              "display.on.consent.screen" = "true";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkUserAttributeMapper {
                name = "phone number";
                claimName = "phone_number";
                userAttribute = "phoneNumber";
              })
              (mkUserAttributeMapper {
                name = "phone number verified";
                claimName = "phone_number_verified";
                userAttribute = "phoneNumberVerified";
                jsonType = "boolean";
              })
            ];
          })
          (mkScope {
            name = "profile";
            description = "OpenID Connect built-in scope: profile";
            attributes = {
              "consent.screen.text" = "\${profileScopeConsentText}";
              "display.on.consent.screen" = "true";
              "include.in.token.scope" = "true";
            };
            protocolMappers = [
              (mkUserAttributeMapper {
                name = "birthdate";
                claimName = "birthdate";
                userAttribute = "birthdate";
              })
              (mkUserAttributeMapper {
                name = "family name";
                claimName = "family_name";
                userAttribute = "lastName";
              })
              (mkMapper {
                name = "full name";
                protocolMapper = "oidc-full-name-mapper";
                config = {
                  "access.token.claim" = "true";
                  "id.token.claim" = "true";
                  "introspection.token.claim" = "true";
                  "userinfo.token.claim" = "true";
                };
              })
              (mkUserAttributeMapper {
                name = "gender";
                claimName = "gender";
                userAttribute = "gender";
              })
              (mkUserAttributeMapper {
                name = "given name";
                claimName = "given_name";
                userAttribute = "firstName";
              })
              (mkUserAttributeMapper {
                name = "locale";
                claimName = "locale";
                userAttribute = "locale";
              })
              (mkUserAttributeMapper {
                name = "middle name";
                claimName = "middle_name";
                userAttribute = "middleName";
              })
              (mkUserAttributeMapper {
                name = "nickname";
                claimName = "nickname";
                userAttribute = "nickname";
              })
              (mkUserAttributeMapper {
                name = "picture";
                claimName = "picture";
                userAttribute = "picture";
              })
              (mkUserAttributeMapper {
                name = "profile";
                claimName = "profile";
                userAttribute = "profile";
              })
              (mkUserAttributeMapper {
                name = "updated at";
                claimName = "updated_at";
                userAttribute = "updatedAt";
                jsonType = "long";
              })
              (mkUserAttributeMapper {
                name = "username";
                claimName = "preferred_username";
                userAttribute = "username";
              })
              (mkUserAttributeMapper {
                name = "website";
                claimName = "website";
                userAttribute = "website";
              })
              (mkUserAttributeMapper {
                name = "zoneinfo";
                claimName = "zoneinfo";
                userAttribute = "zoneinfo";
              })
            ];
          })
          (mkScope {
            name = "roles";
            description = "OpenID Connect scope for add user roles to the access token";
            attributes = {
              "consent.screen.text" = "\${rolesScopeConsentText}";
              "display.on.consent.screen" = "true";
              "include.in.token.scope" = "false";
            };
            protocolMappers = [
              (mkMapper {
                name = "audience resolve";
                protocolMapper = "oidc-audience-resolve-mapper";
                config = {
                  "access.token.claim" = "true";
                  "introspection.token.claim" = "true";
                };
              })
              (mkClientRoleMapper {
                name = "client roles";
                claimName = "resource_access.\${client_id}.roles";
              })
              (mkRealmRoleMapper {
                name = "realm roles";
                claimName = "realm_access.roles";
              })
            ];
          })
          (mkScope {
            name = "web-origins";
            description = "OpenID Connect scope for add allowed web origins to the access token";
            attributes = {
              "consent.screen.text" = "";
              "display.on.consent.screen" = "false";
              "include.in.token.scope" = "false";
            };
            protocolMappers = [
              (mkMapper {
                name = "allowed web origins";
                protocolMapper = "oidc-allowed-origins-mapper";
                config = {
                  "access.token.claim" = "true";
                  "introspection.token.claim" = "true";
                };
              })
            ];
          })
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
          install -d -m 0700 /run/keycloak/data/import

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

      systemd.services.keycloak-account-console-reconcile = {
        description = "Reconcile Keycloak account-console permissions and default required actions";
        after = [ "keycloak.service" ];
        requires = [ "keycloak.service" ];
        partOf = [ "keycloak.service" ];
        wantedBy = [ "keycloak.service" ];

        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = [
            config.sops.templates."keycloak-bootstrap-admin.env".path
          ];
        };

        script = ''
          set -euo pipefail

          base_url="http://127.0.0.1:${toString cfg.httpPort}"
          admin_token=""

          for _attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
            admin_response="$(
              ${pkgs.curl}/bin/curl -fsS \
                "$base_url/realms/master/protocol/openid-connect/token" \
                -d grant_type=password \
                -d client_id=admin-cli \
                --data-urlencode "username=$KC_BOOTSTRAP_ADMIN_USERNAME" \
                --data-urlencode "password=$KC_BOOTSTRAP_ADMIN_PASSWORD" \
                2>/dev/null \
              || true
            )"
            admin_token="$(
              printf '%s' "$admin_response" \
                | ${pkgs.jq}/bin/jq -r '.access_token // empty' 2>/dev/null \
              || true
            )"

            if [ -n "$admin_token" ]; then
              break
            fi

            ${pkgs.coreutils}/bin/sleep 2
          done

          if [ -z "$admin_token" ]; then
            echo "Unable to obtain a Keycloak admin token" >&2
            exit 1
          fi

          auth_header="Authorization: Bearer $admin_token"
          realm_path="$base_url/admin/realms/${cfg.realm}"

          account_id="$(
            ${pkgs.curl}/bin/curl -fsS -H "$auth_header" \
              "$realm_path/clients?clientId=account" \
            | ${pkgs.jq}/bin/jq -r '.[0].id // empty'
          )"
          account_console_id="$(
            ${pkgs.curl}/bin/curl -fsS -H "$auth_header" \
              "$realm_path/clients?clientId=account-console" \
            | ${pkgs.jq}/bin/jq -r '.[0].id // empty'
          )"
          roles_scope_id="$(
            ${pkgs.curl}/bin/curl -fsS -H "$auth_header" \
              "$realm_path/client-scopes" \
            | ${pkgs.jq}/bin/jq -r '.[] | select(.name == "roles") | .id'
          )"

          if [ -z "$account_id" ] || [ -z "$account_console_id" ] || [ -z "$roles_scope_id" ]; then
            echo "Unable to resolve account/account-console client IDs or roles scope" >&2
            exit 1
          fi

          # Keycloak 26 account console can fail to load personal-info after required actions
          # unless account-console explicitly carries the roles scope and account:view-profile.
          ${pkgs.curl}/bin/curl -fsS -o /dev/null -X PUT -H "$auth_header" \
            "$realm_path/clients/$account_console_id/default-client-scopes/$roles_scope_id"

          current_account_console_roles="$(
            ${pkgs.curl}/bin/curl -fsS -H "$auth_header" \
              "$realm_path/clients/$account_console_id/scope-mappings/clients/$account_id" \
            | ${pkgs.jq}/bin/jq -r '.[].name'
          )"

          if ! printf '%s\n' "$current_account_console_roles" | ${pkgs.gnugrep}/bin/grep -qx 'view-profile'; then
            view_profile_role="$(
              ${pkgs.curl}/bin/curl -fsS -H "$auth_header" \
                "$realm_path/clients/$account_id/roles/view-profile"
            )"

            ${pkgs.curl}/bin/curl -fsS -o /dev/null -X POST \
              -H "$auth_header" \
              -H 'Content-Type: application/json' \
              -d "[$view_profile_role]" \
              "$realm_path/clients/$account_console_id/scope-mappings/clients/$account_id"
          fi

          for required_action_alias in CONFIGURE_TOTP UPDATE_PASSWORD; do
            current_required_action="$(
              ${pkgs.curl}/bin/curl -fsS -H "$auth_header" \
                "$realm_path/authentication/required-actions/$required_action_alias"
            )"

            if ! printf '%s' "$current_required_action" | ${pkgs.jq}/bin/jq -e '.enabled == true and .defaultAction == true' >/dev/null; then
              desired_required_action="$(
                printf '%s' "$current_required_action" \
                  | ${pkgs.jq}/bin/jq '.enabled = true | .defaultAction = true'
              )"

              ${pkgs.curl}/bin/curl -fsS -o /dev/null -X PUT \
                -H "$auth_header" \
                -H 'Content-Type: application/json' \
                -d "$desired_required_action" \
                "$realm_path/authentication/required-actions/$required_action_alias"
            fi
          done
        '';
      };
    }
  );
}
