{ config, pkgs, lib, ... }:
{
   services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
}
