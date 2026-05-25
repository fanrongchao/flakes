{ ... }:

{
  imports = [
    ./configuration.nix
    ../../profiles/container-runtime
    ../../profiles/company-gitea.nix
    ../../profiles/zero-trust-node.nix
  ];

  containerRuntime.enable = true;
  services.zeroTrustNode.loginServerUrl = "https://hs.zhsjf.cn";

  services.companyGitea = {
    enable = true;
    domain = "code.xfa.cn";
    httpListenHost = "127.0.0.1";
    sshListenHost = "100.64.0.33";
    sshPort = 22;
    tailnetAddress = "100.64.0.33";
    keycloakIssuer = "https://auth.zhsjf.cn/realms/zhsjf";
    keycloakHostAddress = "192.168.3.111";
  };

  services.openssh.listenAddresses = [
    {
      addr = "192.168.3.88";
      port = 22;
    }
  ];
}
