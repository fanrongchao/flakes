{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    mihomo
  #  wget
  ];
  networking.firewall.enable = false;
}
