# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS flake configuration repository managing multiple hosts and users with declarative system and home environment configurations. It uses home-manager for user-level configurations, sops-nix for encrypted secrets, and integrates external dotfiles from a GitHub repository.

## Key Commands

### System Configuration

```bash
# Build and activate NixOS configuration for a specific host
sudo nixos-rebuild switch --flake .#wsl
sudo nixos-rebuild switch --flake .#zenbook
sudo nixos-rebuild switch --flake .#razer

# Build without activating (test)
sudo nixos-rebuild build --flake .#<hostname>

# Test configuration (activates but doesn't set as boot default)
sudo nixos-rebuild test --flake .#<hostname>
```

### Home Manager

```bash
# Build and activate home-manager configuration
home-manager switch --flake .#nixos
home-manager switch --flake .#frc

# Build without activating
home-manager build --flake .#<username>
```

### Flake Management

```bash
# Update all flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Check flake for errors
nix flake check

# Show flake outputs
nix flake show

# Show flake metadata
nix flake metadata
```

### Secrets Management (SOPS)

```bash
# Edit encrypted secrets (requires age key)
sops secrets/clash.yaml.sops
sops secrets/sing-box.json.sops

# Create new secret file
sops -e <file> > secrets/<filename>.sops

# Note: Age public keys are configured in .sops.yaml
```

## Repository Architecture

### Directory Structure

- **flake.nix**: Main entry point defining flake inputs (nixpkgs, home-manager, sops-nix, dotfiles) and outputs (nixosConfigurations, homeConfigurations)

- **hosts/**: Per-host NixOS system configurations
  - **hosts/\<hostname\>/default.nix**: Import aggregator for the host
  - **hosts/\<hostname\>/configuration.nix**: Main system configuration (packages, services, users)
  - **hosts/\<hostname\>/hardware-configuration.nix**: Hardware-specific settings (auto-generated)
  - **hosts/\<hostname\>/services.nix**: Optional host-specific services

- **users/**: Per-user home-manager configurations
  - **users/\<username\>/home.nix**: User-specific packages, dotfiles, and programs
  - Receives `dotfiles` input as `extraSpecialArgs` for linking external dotfiles

- **profiles/**: Shared configuration modules (currently minimal)

- **secrets/**: SOPS-encrypted secret files
  - **clash.yaml.sops**: Clash proxy configuration
  - **sing-box.json.sops**: Sing-box configuration
  - Protected by age keys defined in `.sops.yaml`

### Configuration Flow

1. **System-level**: flake.nix → hosts/\<hostname\>/ → NixOS modules
2. **User-level**: flake.nix → home-manager.users.\<username\> → users/\<username\>/home.nix
3. **Secrets**: SOPS module integrated at system level, secrets decrypted at runtime

### Hosts

- **wsl**: WSL2 environment using nix-community/NixOS-WSL
  - Default user: nixos
  - Additional user: fanrongchao
  - Enabled features: distrobox, podman, vcluster, nix-ld for Cursor remote

- **zenbook**: Physical/VM NixOS installation
  - User: frc
  - Has hardware-configuration.nix and services.nix

- **razer**: Physical/VM NixOS installation
  - User: frc
  - Has hardware-configuration.nix

### Users

- **nixos**: Primary user on WSL, includes development tools (nodejs, go, python, rust, uv, lazygit)
  - Configures neovim with treesitter and dotfiles from external repo
  - Auto-installs npm global packages via home.activation

- **fanrongchao**: Additional WSL user with minimal configuration

- **frc**: User for zenbook and razer hosts with basic tools

### Key Integrations

- **home-manager**: Integrated as NixOS module with `useGlobalPkgs = true` and `useUserPackages = true`
- **sops-nix**: Secrets encrypted with age, three age public keys configured
- **dotfiles**: External GitHub repo (fanrongchao/dotfiles) imported as flake input, used for neovim config via `xdg.configFile."nvim".source`
- **nix-ld**: Enabled on WSL for Cursor remote server compatibility

### Important Notes

- The repository uses `nixos-unstable` channel for latest packages
- Flakes are enabled system-wide with `nix.settings.experimental-features`
- WSL configuration includes kernel modules for Kubernetes (overlay, br_netfilter)
- NPM global packages are managed declaratively via home-manager activation scripts
- Home-manager automatically backs up existing files with `.bak` extension
