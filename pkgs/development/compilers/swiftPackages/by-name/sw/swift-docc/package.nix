{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  stdenv,
  swift,
  swiftpm,
  swift_release,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-docc";
  version = swift_release;

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-docc";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = "sha256-zu70RyYvnfhW3DdovSeLFXTNmdHrhdnSYCN8RisSkt8=";
  };

  postPatch = ''
    # SignalTests.testTrappingSignal tries to access `/bin/bash`. Replace it with the shell in the stdenv.
    substituteInPlace Tests/SwiftDocCUtilitiesTests/SignalTests.swift \
      --replace-fail '/bin/bash' ${lib.escapeShellArg stdenv.shell}
  '';

  strictDeps = true;

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-kJFuNw/pRn2A4UMvGcX3j04Faz44mriSz90u8hLdaZc=";
  };

  swiftpmFlags = [
    # Otherwise fails to build with `error: module 'SwiftDocC' was not compiled for testing`.
    "-Xswiftc"
    "-enable-testing"
  ];

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  doCheck = !stdenv.hostPlatform.isDarwin;

  __structuredAttrs = true;

  meta = {
    description = "Documentation compiler for Swift";
    mainProgram = "docc";
    homepage = "https://github.com/swiftlang/swift-docc";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
