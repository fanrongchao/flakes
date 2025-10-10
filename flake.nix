# /etc/nixos/flake.nix
{
  description = "NixOS configuration for my laptop wsl";

  nixConfig = {
    substituters = [
      #"https://mirror.sjtu.edu.cn/nix-channels/store"
      #"https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    # 将 NixOS 软件包集固定到一个特定的发布分支
    # 建议使用您当前系统相近的版本，例如 nixos-24.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/nixos-wsl";
    # 添加 home-manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = { url = "github:fanrongchao/dotfiles"; flake = false; };
    # add sops
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, sops-nix, ... }@inputs: {
    # 定义一个 NixOS 系统配置
    # 请将 'my-hostname' 替换为您系统的真实主机名
    # 您可以通过运行 `hostname` 命令来查看
    nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # 或者您的系统架构，例如 "aarch64-linux"
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/wsl        # enable sops-nix
        inputs.nixos-wsl.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # 自动备份被 home-manager 管理的已存在文件
          home-manager.backupFileExtension = "bak";
          home-manager.extraSpecialArgs = {
              inherit dotfiles;
          };
          home-manager.users.nixos = import ./users/nixos/home.nix;
          home-manager.users.fanrongchao = import ./users/fanrongchao/home.nix;
        }
      ];
    };
  };
}
