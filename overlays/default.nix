final: prev: {
  #TODO: 1. add codex/claude code/opencode/openspec ... npm install -g packages
  #      2. wrap sh and npm install -g pacakges and python app(uv) make them structural with helpers
  myHello = prev.callPackage ../pkgs/hello {};
  codex = prev.callPackage ../pkgs/codex {};
}
