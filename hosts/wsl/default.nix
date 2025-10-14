{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    ./services.nix
  ];
}
