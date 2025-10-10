{config, pkgs, lib, ...}:

{
  # TODO add sops 
  sops.age.keyFile = "/var/lib/sops/age/keys.txt";
  sops.secrets."sing-box.json" = {
    sopsFile = ../../secrets/sing-box.json.sops;
    format = "binary";
    owner = "root"; group = "root"; mode = "0400";
    path = "/run/secrets/sing-box.json";
  };


  services.sing-box = {
    enable = true;
    settings = {
      _secret = config.sops.secrets."sing-box.json".path;
    };
  };
  systemd.services.sing-box.serviceConfig = {
    Environment = [ "ENABLE_DEPRECATED_TUN_ADDRESS_X=true" ];
    AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
    CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
    DeviceAllow = [ "/dev/net/tun rw" ];
    after = [ "sops-nix.service" "sops-install-secrets.service" ];
    wants = [ "sops-nix.service" "sops-install-secrets.service" ];
    ExecStart = lib.mkForce [ 
      "" 
      "${pkgs.sing-box}/bin/sing-box run -c /run/secrets/sing-box.json -D /var/lib/sing-box"
    ];

  };

}
