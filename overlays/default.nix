final: prev: {
  #TODO: 1. add [x]codex/[ ]claude code/[ ]gemini/[ ]opencode/openspec ... npm install -g packages
  #      2. wrap sh and npm install -g pacakges and python app(uv) make them structural with helpers
  codex = prev.callPackage ../pkgs/codex {};
}
