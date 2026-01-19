{ config, lib, pkgs, ... }:

let
  cfg = config.containerRuntime;
in
{
  config = lib.mkIf (cfg.enable && cfg.implementation == "podman") {
    virtualisation.podman = {
      enable = true;
      dockerCompat = cfg.dockerCompat;
    };

    environment.systemPackages = [
      pkgs.podman
    ];
  };
}
