{config, pkgs, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/proxyed.nix
  ];
}
