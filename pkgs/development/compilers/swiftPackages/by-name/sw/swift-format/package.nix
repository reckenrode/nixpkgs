{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  swift,
  swiftpm,
  stdenv,
  swift_release,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-format";
  version = swift_release;

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-format";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = "sha256-01lnZFaFAcjWN9Hn0y60gEANz7RbYRvjESysYqB9iSo=";
  };

  strictDeps = true;

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-UAvKJKEN32FVILwdADqXAZ7opS3Tf3e7Qp+RhD4R4QE=";

    # Upstream doesn’t provide `Package.resolved`.
    postPatch = ''
      ln -s ${./Package.resolved} Package.resolved
    '';
  };

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  doCheck = !stdenv.hostPlatform.isDarwin;

  __structuredAttrs = true;

  meta = {
    mainProgram = "swift-format";
    homepage = "https://github.com/swiftlang/swift-format";
    description = "Swift code formatter";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
