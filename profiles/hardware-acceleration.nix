{ config, pkgs, lib, ... }:
{
  # NVIDIA compute support for AI workloads.
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.blacklistedKernelModules = [ "nouveau" ];

  hardware.graphics.enable = true;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    nvidiaSettings = false;
    open = false;
    powerManagement.enable = false;
  };

  environment.systemPackages = with pkgs; [
    pciutils
    cudaPackages.cudatoolkit
  ];
}
