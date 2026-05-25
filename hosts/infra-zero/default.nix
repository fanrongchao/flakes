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
    keycloakIssuer = "https://auth.zhsjf.cn/realms/zhsjf";
    keycloakHostAddress = "192.168.3.111";
  };
}
