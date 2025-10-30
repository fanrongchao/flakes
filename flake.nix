{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/nixos-wsl";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = { url = "github:fanrongchao/dotfiles"; flake = false; };
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, sops-nix, ... }@inputs: 

    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [(import ./overlays)];
      };
      inherit (nixpkgs) lib;
    in {
      #overlay packages
      packages.${system} = {
        codex = pkgs.codex;
      };

      #NixOS system configurations
      nixosConfigurations.wsl = lib.nixosSystem {
        inherit system;
        modules = [
          {nixpkgs.overlays = [(import ./overlays)];}
          sops-nix.nixosModules.sops
          ./hosts/wsl
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

      nixosConfigurations.zenbook = lib.nixosSystem {
        inherit system;
        modules = [
          {nixpkgs.overlays = [(import ./overlays)];}
	  sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frc = import ./users/frc/home.nix;
          } 
          ./hosts/zenbook              
        ];
      };

      nixosConfigurations.ai-server= lib.nixosSystem {
        inherit system;
        modules = [
          {nixpkgs.overlays = [(import ./overlays)];}
	  sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.xfa = import ./users/xfa/home.nix;
          } 
          ./hosts/ai-server             
        ];
      };

      nixosConfigurations.razer = lib.nixosSystem {
        inherit system;
        modules = [
          {nixpkgs.overlays = [(import ./overlays)];}
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frc = import ./users/frc/home.nix;
          } 
          ./hosts/razer              
        ];
      };

      #home-manager configuraions

      homeConfigurations.nixos = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./users/nixos/home.nix
        ];
      };

      homeConfigurations.frc = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./users/frc/home.nix
        ];
      };
    };
}
