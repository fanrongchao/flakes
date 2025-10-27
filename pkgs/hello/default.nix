{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "myHello";
  version = pkgs.hello.version;
  meta = pkgs.hello.meta // {
    description = "Custom hello";
  };
  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    ln -s ${pkgs.hello}/bin/hello $out/bin/myHello
    '';
}
