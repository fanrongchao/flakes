{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    mihomo
  #  wget
  ];
}
