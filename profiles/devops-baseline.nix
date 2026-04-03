{ config, pkgs, lib, ... }:
{
  # DevOps baseline: common dev/ops CLI tools for all hosts.
  environment.systemPackages = with pkgs; [
    bubblewrap
    postgresql
    nodePackages.pnpm
  ];

  # Some CLIs probe a hardcoded /usr/bin/bwrap path instead of using PATH.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bwrap - - - - /run/current-system/sw/bin/bwrap"
  ];
}
