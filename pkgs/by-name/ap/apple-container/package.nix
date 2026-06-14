{
  bzip2,
  darwin,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  libarchive,
  stdenv,
  swift,
  swiftpm,
  xz,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "container";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "apple";
    repo = "container";
    tag = finalAttrs.version;
    hash = "sha256-uBmBDFxrtXqfZnDhe6gfugnrjVsCbMswijygNGjAgos=";
  };

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) src pname version;
    hash = "sha256-AUJ2NGiCYS/cPZP4tH9T318wVny5oWBvdhP1HeVJPuE=";
  };

  nativeBuildInputs = [
    darwin.sigtool
    swift
    swiftpm
  ];

  buildInputs = [
    bzip2
    libarchive
    xz
    zlib
  ];

  installPhase = ''
    runHook preInstall

    declare -a exes=(
      container
      container-apiserver
    )

    declare -A plugins=(
      [container-core-images]=CoreImages
      [container-network-vmnet]=NetworkVmnet
      [container-runtime-linux]=RuntimeLinux
      [machine-apiserver]=MachineAPIServer
    )

    for exe in "''${exes[@]}"; do
      if [ "$exe" = container ]; then
        identity=com.apple.container.cli
      else
        identity=com.apple.container.apiserver
      fi

      install -m755 -D "$(swiftpmBinPath)/$exe" "$out/bin/$exe"

      codesign -f -s - -i "$identity" "$out/bin/$exe"
    done

    for plugin in "''${!plugins[@]}"; do
      if [ -e "signing/$plugin.entitlements" ]; then
        entitlements=(--entitlements "signing/$plugin.entitlements")
      else
        entitlements=()
      fi
      identity=com.apple.container.$plugin

      install -m755 -D "$(swiftpmBinPath)/container" "$out/libexec/container/plugins/$plugin/bin/$plugin"
      codesign -f -s - -i "$identity" "''${entitlements[@]}" "$out/libexec/container/plugins/$plugin/bin/$plugin"

      install -m644 Sources/Plugins/''${plugins[$plugin]}/config.toml "$out/libexec/container/plugins/$plugin/config.toml"
    done

    runHook postInstall
  '';
})
