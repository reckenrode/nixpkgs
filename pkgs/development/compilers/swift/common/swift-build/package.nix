{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  ncurses,
  pkg-config,
  sqlite,
  stdenv,
  swift,
  swift-testing,
  swiftpmHook,
  xcbuild,
  replaceVars,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-build";
  version = "0-unstable-20250512";

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-build";
    rev = "51369cdceadcb51894314be2b40352a41abad4de";
    hash = "sha256-0EFcLp7H2ahXgBdMWVnWRs817B1Ca0dNreGjkOZ4OCo=";

    # Upstream doesn’t provide `Package.resolved`.
    postFetch = ''
      cp ${./Package.resolved} "$out/Package.resolved"
    '';
  };

  patches = [
    # Swift Build checks whether the SDK is Xcode by looking at the `DEVELOPER_DIR` path for Xcode.
    # Have it treat store paths as being Xcode SDKs so that the nixpkgs SDK is treated as a Darwin platform.
    (replaceVars ./patches/treat-nixpkgs-sdk-as-xcode.patch {
      store-dir = builtins.storeDir;
    })
  ];

  postPatch = ''
    substituteInPlace Sources/SwiftBuild/SWBBuildServiceConnection.swift \
      --replace-fail 'Bundle(for: SWBBuildServiceConnection.self).bundleURL.deletingLastPathComponent()' 'URL(filePath: "@out@/libexec")?' \
      --replace-fail 'Bundle.main.executableURL?.deletingLastPathComponent()' 'URL(filePath: "@out@/libexec")?' \
      --replace-fail '@out@' "$out"
  '';

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-soZ6SsCn/u0POxF2pndUsSzLc8LwB5NJn+tSCYO9xhw=";
  };

  swiftpmFlags = [
    "--skip-update"
    "-Xswiftc"
    "-load-plugin-library"
    "-Xswiftc"
    "${lib.getDev swift-testing}/lib/swift/host/plugins/testing/libTestingMacros${stdenv.buildPlatform.extensions.sharedLibrary}"
    "-Xswiftc"
    "-I"
    "-Xswiftc"
    "${lib.getLib swift-testing}/lib/swift/${swift.swiftPlatform}/testing"
    "-Xswiftc"
    "-L"
    "-Xswiftc"
    "${lib.getLib swift-testing}/lib/swift/${swift.swiftPlatform}/testing"
  ];

  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    swift
    swiftpmHook
  ];

  buildInputs = [
    ncurses
    sqlite
    swift-testing
  ];

  # Install xcspec files needed by Swift Build
  postInstall = ''
    mkdir -p "$out/libexec"
    mv "$out/bin/SWBBuildServiceBundle" "$out/libexec"
    cp -r "$(swiftpmBinPath)"/*.bundle "$out/libexec"
  '';

  __structuredAttrs = true;

  # TODO: Do something with this to inject it into the build (in the hook?)
  passthru.buildParameters = {
    activeRunDestination = {
      platform = "macosx";
      sdk = "macosx";
      targetArchitecture = stdenv.hostPlatform.darwinArch;
      supportedArchitectures = [ stdenv.hostPlatform.darwinArch ];
      disableOnlyActiveArch = false;
    };
    overrides = {
      commandLine = {
        table = {
          DSTROOT = "@out@";
          LD = "clang";
        };
      };
    };
  };

  meta = {
    description = "High-level build system based on swift-llbuild used by Xcode and SwiftPM";
    mainProgram = "swbuild";
    homepage = "https://github.com/swiftlang/swift-build";
    platforms = with lib.platforms; darwin ++ linux ++ windows;
    license = lib.licenses.asl20;
    maintainers = lib.teams.swift.members;
  };
})
