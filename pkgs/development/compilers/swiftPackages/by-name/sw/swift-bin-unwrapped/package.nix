{
  lib,
  autoPatchelfHook,
  cpio,
  curl,
  fetchurl,
  libedit,
  libuuid,
  libxml2,
  ncurses,
  python313,
  sqlite,
  stdenv,
  swiftc,
  xar,
  zlib,
  swift_release,
  runCommand,
}:

let
  platformSrc = rec {
    aarch64-darwin = {
      url = "https://download.swift.org/swift-${swift_release}-release/xcode/swift-${swift_release}-RELEASE/swift-${swift_release}-RELEASE-osx.pkg";
      hash = lib.fakeHash;
    };
    x86_64-darwin = aarch64-darwin; # The package is universal.
    aarch64-linux = {
      url = "https://download.swift.org/swift-${swift_release}-release/fedora41-aarch64/swift-${swift_release}-RELEASE/swift-${swift_release}-RELEASE-fedora41-aarch64.tar.gz";
      hash = lib.fakeHash;
    };
    x86_64-linux = {
      url = "https://download.swift.org/swift-${swift_release}-release/fedora41/swift-${swift_release}-RELEASE/swift-${swift_release}-RELEASE-fedora41.tar.gz";
      hash = "sha256-mPqK7m4gtHFZBfBgp5cYkt5Sftiu34HzwNjzb/TXqQE=";
    };
  };
in
stdenv.mkDerivation {
  pname = "swiftc-bin";
  version = swift_release;

  src = fetchurl { inherit (platformSrc.${stdenv.hostPlatform.system}) url hash; };

  unpackPhase = lib.optionalDrvAttr stdenv.hostPlatform.isDarwin ''
    runHook preUnpack

    xar -xf $src
    zcat swift-${swift_release}-RELEASE-osx-package.pkg/Payload | cpio -i

    runHook postUnpack
  '';

  strictDeps = true;

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    curl
    libedit
    libuuid
    ncurses
    python313
    sqlite
    zlib
    # Fedora 41 packages libxml2 pre-ABI change (from 2 -> 16). Use a hack to work around it.
    # See: https://github.com/NixOS/nixpkgs/pull/396195#issuecomment-2881757108.
    (runCommand "libxml2-fake-old-abi" { } ''
      mkdir -p "$out/lib"
      ln -s "${lib.getLib libxml2}/lib/libxml2.so" "$out/lib/libxml2.so.2"
    '')
  ];

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isDarwin [
      cpio
      xar
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
      python313
    ];

  # buildPhase = lib.optionalString stdenv.hostPlatform.isLinux ''
  #   # Patch the binary to find the libc the way Nixpkgs wraps it (using `-idirafter`).
  #   sed -E 's/47073/46514/g' -i usr/lib/swift/host/compiler/lib_InternalSwiftScan.so
  # '';

  installPhase = ''
    runHook preInstall

    #install -D -t "''${!outputBin}/bin" \
    #  usr/bin/swift-driver \
    #  usr/bin/swift-frontend \
    #  usr/bin/swift-help
    mkdir -p "''${!outputBin}"
    cp -rv usr/bin "''${!outputBin}"

    # ln -s ${lib.escapeShellArg (lib.getExe' stdenv.cc "${stdenv.cc.targetPrefix}clang")} "''${!outputBin}/bin/clang"

    #for tool in swift swiftc; do
    #  ln -s swift-driver "''${!outputBin}/bin/$tool"
    #  ln -s swift-frontend "''${!outputBin}/bin/$tool-legacy-driver"
    #done
    ## These are symlinks to `swift-frontend` because they’re not supported by `swift-driver`.
    #ln -s swift-frontend "''${!outputBin}/bin/swift-autolink-extract"

    cp -rv usr/lib "''${!outputLib}"

    runHook postInstall
  '';

  __structuredAttrs = true;

  inherit (swiftc) meta;
}
