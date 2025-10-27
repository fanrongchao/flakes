{ lib, buildNpmPackage, fetchurl }:

buildNpmPackage rec {
  pname = "codex";
  version = "0.50.0";
  
  src = fetchurl {
    url = "https://registry.npmmirror.com/@openai/codex/-/codex-${version}.tgz";
    hash = "";
  };
  
  
  NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com";
  
  npmDepsHash = "";
  dontNpmBuild = true;
  
  meta = with lib; {
    description = "OpenAI Codex CLI tool";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    mainProgram = "codex";
    platforms = platforms.all;
  };
}
