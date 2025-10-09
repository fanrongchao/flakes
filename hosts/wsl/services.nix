{config, pkgs, ...}:

{
  # TODO add sops 


  services.sing-box = {
    enable = true;
#   enable Tun
    serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      DeviceAllow = [ "/dev/net/tun rw" ];
    };
    # TODO encrypt
    _secret = "../../secrets/sing-box.json";
  };

}
