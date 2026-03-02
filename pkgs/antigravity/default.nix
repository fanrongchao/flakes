{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, alsa-lib
, at-spi2-atk
, atk
, cairo
, cups
, dbus
, expat
, glib
, gtk3
, libdrm
, mesa
, nspr
, nss
, pango
, systemd
, libX11
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libsecret
, libxcb
, libxkbfile
, libxkbcommon
, libsoup_3
, webkitgtk_4_1
}:

let
  pname = "antigravity";
  version = "1.19.6-6514342219874304";
in
stdenv.mkDerivation rec {
  inherit pname version;

  src =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      fetchurl {
        url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/linux-x64/Antigravity.tar.gz";
        hash = "sha256-gFIsnWC8wEuxPUD6E2YB0YTcg/NruQZespzEVttMKeE=";
      }
    else
      throw "antigravity: unsupported system ${stdenv.hostPlatform.system}";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libsecret
    libxcb
    libxkbfile
    libxkbcommon
    libsoup_3
    mesa
    nspr
    nss
    pango
    systemd
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    webkitgtk_4_1
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/antigravity $out/share/applications $out/bin
    cp -r Antigravity/* $out/share/antigravity/

    ln -s $out/share/antigravity/bin/antigravity $out/bin/antigravity

    install -Dm444 \
      $out/share/antigravity/resources/app/resources/linux/code.png \
      $out/share/icons/hicolor/512x512/apps/antigravity.png

    cat > $out/share/applications/antigravity.desktop <<EOF
    [Desktop Entry]
    Name=Antigravity
    Comment=Google Antigravity
    Exec=$out/bin/antigravity %F
    Icon=antigravity
    Terminal=false
    Type=Application
    Categories=Development;IDE;TextEditor;
    MimeType=text/plain;inode/directory;
    StartupWMClass=Antigravity
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Antigravity desktop app";
    homepage = "https://antigravity.google/download/linux";
    license = licenses.unfree;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "antigravity";
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
