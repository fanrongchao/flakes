{ lib
, stdenv
, fetchurl
, appimageTools
}:

let
  version = "1.1.18";
  platformInfo =
    if stdenv.hostPlatform.system == "x86_64-linux" then {
      url = "https://5ykymftd1soethh5.public.blob.vercel-storage.com/Pencil-linux-x86_64.AppImage";
      hash = "sha256-wqqykm42/rAYUCT0wuoJBF98CQ0xrbt0/euOnd6wbng=";
    } else if stdenv.hostPlatform.system == "aarch64-linux" then {
      url = "https://5ykymftd1soethh5.public.blob.vercel-storage.com/Pencil-linux-arm64.AppImage";
      hash = "sha256-e2CgmyiO6rFJLfMQkGFBlhQaXN4c8dFmezNOCtTq9SM=";
    } else
      throw "pencilOfficial: unsupported system ${stdenv.hostPlatform.system}";
  src = fetchurl {
    inherit (platformInfo) url hash;
  };
  appimageContents = appimageTools.extractType2 {
    pname = "pencil";
    inherit version src;
  };
in
appimageTools.wrapType2 rec {
  pname = "pencil";
  inherit version;
  inherit src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/pencil.png $out/share/icons/hicolor/512x512/apps/pencil.png
    install -Dm444 ${appimageContents}/pencil.desktop $out/share/applications/pencil.desktop
    substituteInPlace $out/share/applications/pencil.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=pencil %U'
  '';

  meta = with lib; {
    description = "Pencil official desktop app from pencil.dev";
    homepage = "https://www.pencil.dev/downloads";
    license = licenses.unfree;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "pencil";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    maintainers = [ ];
  };
}
