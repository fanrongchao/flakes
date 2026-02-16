{ config, pkgs, lib, ... }:
{
  # DevOps baseline: common dev/ops CLI tools for all hosts.
  environment.systemPackages = with pkgs; [
    postgresql
  ];
}
