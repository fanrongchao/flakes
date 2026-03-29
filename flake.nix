{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, sops-nix, nixos-hardware, dank-material-shell, nix-openclaw, ... }@inputs:

    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
      overlays = [
        nix-openclaw.overlays.default
        (import ./overlays)
      ];
      mkPkgs = system: import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };
      pkgs = mkPkgs linuxSystem;
      darwinPkgs = mkPkgs darwinSystem;
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
      packages.${linuxSystem} = {
        antigravity = pkgs.antigravity;
        antigravity-manager = pkgs.antigravity-manager;
        codex = pkgs.codex;
      };

      nixosConfigurations.zenbook = lib.nixosSystem {
        system = linuxSystem;
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
        system = linuxSystem;
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
        system = linuxSystem;
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
        system = linuxSystem;
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
        system = linuxSystem;
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
        system = linuxSystem;
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

      darwinConfigurations.m5-air = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { inherit inputs self; };
        modules = [
          commonNixpkgsModule
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
          ./hosts/m5-air
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

      homeConfigurations.frc-m5-air = home-manager.lib.homeManagerConfiguration {
        pkgs = darwinPkgs;
        modules = [
          ./users/frc/darwin-home.nix
        ];
      };
    };
}
