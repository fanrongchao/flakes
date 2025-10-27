{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, nodejs
}:

stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.50.0";
  
  src = fetchurl {
    url = "https://registry.npmmirror.com/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-3eHxe1t6zSUDTCugCDOeI6Ta1vo89OdpsFCX59HLaco=";
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
