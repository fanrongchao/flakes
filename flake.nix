{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    mihomo-cli.url = "github:fanrongchao/mihomocli";
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nixos-hardware, dank-material-shell, ... }@inputs: 

    let
      system = "x86_64-linux";
      overlays = [(import ./overlays)];
      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };
      commonNixpkgsModule = {
        nixpkgs = {
          inherit overlays;
          config.allowUnfree = true;
        };
        home-manager.extraSpecialArgs = { inherit inputs; };
      };
      inherit (nixpkgs) lib;
    in {
      #overlay packages
      packages.${system} = {
        codex = pkgs.codex;
      };

      nixosConfigurations.zenbook = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          commonNixpkgsModule
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

      nixosConfigurations.lg-gram = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          commonNixpkgsModule
	  sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frc = import ./users/frc/home.nix;
          } 
          ./hosts/lg-gram              
        ];
      };

      nixosConfigurations.gpd = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          commonNixpkgsModule
          nixos-hardware.nixosModules.gpd-pocket-4
	  sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frc = import ./users/frc/home.nix;
          }
          ./hosts/gpd
        ];
      };

      nixosConfigurations.pve-dev-01 = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          commonNixpkgsModule
	  sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frc = import ./users/frc/home.nix;
          } 
          ./hosts/pve-dev-01             
        ];
      };

      nixosConfigurations.ai-server= lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          commonNixpkgsModule
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

      nixosConfigurations.rog-laptop = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          commonNixpkgsModule
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frc = import ./users/frc/home.nix;
          } 
          ./hosts/rog-laptop              
        ];
      };

      #home-manager configuraions

      homeConfigurations.frc = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./users/frc/home.nix
        ];
      };

      homeConfigurations.xfa = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./users/xfa/home.nix
        ];
      };
    };
}
