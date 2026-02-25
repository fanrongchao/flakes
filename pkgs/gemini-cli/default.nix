{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  jq,
  pkg-config,
  clang_20,
  libsecret,
  ripgrep,
  nodejs_22,
}:

buildNpmPackage (finalAttrs: {
  pname = "gemini-cli";
  version = "0.30.0";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+w4w1cftPSj0gJ23Slw8Oexljmu0N/PZWH4IDjw75rs=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-Nkd5Q2ugRqsTqaFbCSniC3Obl++uEjVUmoa8MVT5++8=";

  dontPatchElf = stdenv.isDarwin;

  nativeBuildInputs = [
    jq
    pkg-config
  ]
  ++ lib.optionals stdenv.isDarwin [ clang_20 ];

  buildInputs = [
    ripgrep
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
  '';

  postPatch = ''
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty")' package.json > package.json.tmp && mv package.json.tmp package.json
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty")' packages/core/package.json > packages/core/package.json.tmp && mv packages/core/package.json.tmp packages/core/package.json

    substituteInPlace packages/core/src/tools/ripGrep.ts \
      --replace-fail "await ensureRgPath();" "'${lib.getExe ripgrep}';"

    sed -i '/enableAutoUpdate:/,/default: true/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
    sed -i '/enableAutoUpdateNotification:/,/default: true/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts

    substituteInPlace packages/cli/src/utils/handleAutoUpdate.ts \
      --replace-fail "if (!settings.merged.general.enableAutoUpdateNotification) {" "if (false) {" \
      --replace-fail "settings.merged.general.enableAutoUpdate," "false," \
      --replace-fail "!settings.merged.general.enableAutoUpdate" "!false"
  '';

  disallowedReferences = [
    finalAttrs.npmDeps
    nodejs_22.python
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    npm prune --omit=dev

    find node_modules -name "*.py" -delete
    rm -rf node_modules/keytar/build

    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
    cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
    cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    cp -r packages/sdk $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk
    cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    ln -s $out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js $out/bin/gemini
    chmod +x "$out/bin/gemini"

    find $out/share/gemini-cli/node_modules -name "package-lock.json" -delete
    find $out/share/gemini-cli/node_modules -name ".package-lock.json" -delete
    find $out/share/gemini-cli/node_modules -name "config.gypi" -delete

    runHook postInstall
  '';

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
})
