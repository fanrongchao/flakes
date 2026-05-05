{ ... }:

{
  imports = [
    ./configuration.nix
    ../../profiles/container-runtime
  ];

  containerRuntime.enable = true;
}
