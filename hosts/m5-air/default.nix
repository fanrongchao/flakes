{ ... }:

{
  imports = [
    ./configuration.nix
  ];

  home-manager.users.frc.imports = [
    ../../users/frc/darwin-home.nix
  ];
}
