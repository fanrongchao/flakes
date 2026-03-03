{ lib
, stdenv
, fetchurl
, appimageTools
}:

let
  pname = "antigravity-manager";
  version = "4.1.27";
  platformInfo =
    if stdenv.hostPlatform.system == "x86_64-linux" then {
      url = "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v${version}/Antigravity.Tools_${version}_amd64.AppImage";
      hash = "sha256-7YosahuFsQjKiVMh40yc8vkQIcFI3WU8Maho3jeCKgU=";
    } else if stdenv.hostPlatform.system == "aarch64-linux" then {
      url = "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v${version}/Antigravity.Tools_${version}_aarch64.AppImage";
      hash = "sha256-KN3H3Cv6+LiIw4qKHWIsdecvbPd3JIHeYxaCC0PUImI=";
    } else
      throw "antigravity-manager: unsupported system ${stdenv.hostPlatform.system}";
  src = fetchurl {
    inherit (platformInfo) url hash;
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 \
      '${appimageContents}/Antigravity Tools.desktop' \
      "$out/share/applications/${pname}.desktop"
    install -Dm444 \
      '${appimageContents}/antigravity_tools.png' \
      "$out/share/icons/hicolor/256x256/apps/antigravity_tools.png"

    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=antigravity_tools' 'Exec=${pname}'
  '';

  meta = with lib; {
    description = "Desktop manager for Antigravity ecosystem";
    homepage = "https://github.com/lbjlaq/Antigravity-Manager";
    license = licenses.unfree;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    maintainers = [ ];
  };
}
