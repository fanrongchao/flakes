{config, pkgs, lib, ...}:

{
  # TODO add sops 
  sops.age.keyFile = "/var/lib/sops/age/keys.txt";
  sops.secrets."clash.yaml" = {
    sopsFile = ../../secrets/clash.yaml.sops;
    format = "binary";
    owner = "root"; group = "root"; mode = "0400";
    path = "/run/secrets/clash.yaml";
  };


  services.mihomo = {
    enable = true;
    configFile = config.sops.secrets."clash.yaml".path;
    tunMode = true;
  };
  
  systemd.services.mihomo.serviceConfig = {
    # 需要更宽的能力：用 mkForce 覆盖掉模块默认值
    AmbientCapabilities    = lib.mkForce "CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE";
    CapabilityBoundingSet  = lib.mkForce "CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE";

    # 放开地址族，包含 AF_NETLINK（路由变更监控）与 AF_UNIX
    RestrictAddressFamilies = lib.mkForce "AF_UNIX AF_INET AF_INET6 AF_NETLINK";

    # 放行 /dev/net/tun，且显式允许它（DeviceAllow 是列表）
    PrivateDevices = lib.mkForce false;
    DeviceAllow    = lib.mkForce [ "/dev/net/tun rw" ];

    # 允许修改网络相关内核开关（更保险让路由可写）
    ProtectKernelTunables = lib.mkForce false;

    # 某些打包带的系统调用过滤太严，清空（允许 netlink/route 相关调用）
    SystemCallFilter = lib.mkForce "";

    # 可选
    LimitNOFILE = lib.mkForce "infinity";
  };

  #（可选）如果 mihomo 模块还限制了 PrivateUsers/ProtectSystem 等，
  # 也可以用 mkForce 显式设置：
  # systemd.services.mihomo.serviceConfig.PrivateUsers = lib.mkForce false;

}
