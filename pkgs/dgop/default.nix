{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule {
  pname = "dgop";
  version = "0.1.13";

  src = fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dgop";
    rev = "v0.1.13";
    hash = "sha256-Frp1/AE5jznFWS52FgN9daI6Kgi0yPx7bZVoFuEIylw=";
  };

  vendorHash = "sha256-NycCRxav1S/DW4fRlcLG5r5NsQQHbAE4zoOiF6Ut/bE=";

  subPackages = [ "cmd/cli" ];

  ldflags = [ "-s" "-w" ];

  postInstall = ''
    mv "$out/bin/cli" "$out/bin/dankgop"
    ln -s dankgop "$out/bin/dgop"
  '';

  meta = {
    description = "Stateless system telemetry CLI used by DankMaterialShell";
    homepage = "https://github.com/AvengeMedia/dgop";
    license = lib.licenses.mit;
    mainProgram = "dgop";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
}
