{config, pkgs, ...}:

{
  # TODO add sops 


  services.sing-box = {
    enable = true;
#   enable Tun
    # TODO encrypt
    settings = {
      _secret = "../../secrets/sing-box.json";
    };
  };
  systemd.services.sing-box.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
    CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
    DeviceAllow = [ "/dev/net/tun rw" ];
  };

}
