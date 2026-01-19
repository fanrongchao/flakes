{ config, lib, ... }:

let
  cfg = config.containerRuntime;
in
{
  imports = [
    ./podman.nix
  ];

  options.containerRuntime = {
    enable = lib.mkEnableOption "container runtime profile";

    implementation = lib.mkOption {
      type = lib.types.enum [ "podman" ];
      default = "podman";
      description = "Container runtime implementation.";
    };

    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Provide a docker-compatible CLI via the selected implementation (when supported).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.implementation == "podman";
        message = "containerRuntime.implementation must be one of: podman";
      }
    ];
  };
}
