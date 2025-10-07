{config, pkgs, ...}:

{
  #TODO enable sing-box
  services.sing-box = {
    enable = true;
#    enableTun = true;
#    configFile = "./../../secrets/sing-box.json";
  };

}
