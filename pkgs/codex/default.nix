{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, nodejs
}:

let
  platformInfo =
    if stdenv.hostPlatform.system == "x86_64-linux" then {
      suffix = "linux-x64";
      hash = "sha256-T3D3t3V+JawmyiN1TRGzzLPeGSyCYP1rTylKNcssZ3w=";
    } else if stdenv.hostPlatform.system == "aarch64-linux" then {
      suffix = "linux-arm64";
      hash = "sha256-Dza8c9NaKsuK73CSdM/CPHfMoIKWNNMCwvjbj0NbA2M=";
    } else
      throw "Unsupported platform for codex prebuilt binary: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.106.0";

  src = fetchurl {
    url = "https://registry.npmmirror.com/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-UTbEnsypzh/FqVu7SWrQqJD6NobTyNp1kJNFbIHFa8k=";
  };

  platformSrc = fetchurl {
    url = "https://registry.npmmirror.com/@openai/codex/-/codex-${version}-${platformInfo.suffix}.tgz";
    hash = platformInfo.hash;
  };
  
  nativeBuildInputs = [ 
    autoPatchelfHook  # 自动修补预编译二进制的动态链接
    makeWrapper 
  ];
  
  dontBuild = true;  # 不需要构建
  
  installPhase = ''
    runHook preInstall
    
    # 创建标准的 node_modules 结构
    mkdir -p $out/lib/node_modules/@openai/codex
    mkdir -p $out/bin
    
    # 复制所有内容
    cp -r . $out/lib/node_modules/@openai/codex/

    # 复制对应平台的可选依赖，避免运行时报 Missing optional dependency
    mkdir -p $TMPDIR/codex-platform
    tar -xzf ${platformSrc} -C $TMPDIR/codex-platform
    mkdir -p $out/lib/node_modules/@openai/codex/node_modules/@openai
    cp -r $TMPDIR/codex-platform/package \
      $out/lib/node_modules/@openai/codex/node_modules/@openai/codex-${platformInfo.suffix}
    
    # 创建可执行命令，用 makeWrapper 确保 node 可用
    makeWrapper ${nodejs}/bin/node $out/bin/codex \
      --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"
    
    runHook postInstall
  '';
  
  meta = with lib; {
    description = "OpenAI Codex CLI tool";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    mainProgram = "codex";
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
