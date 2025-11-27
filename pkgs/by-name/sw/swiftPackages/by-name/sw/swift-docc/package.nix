{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  stdenv,
  swift,
  swiftpmHook,
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
    substituteInPlace Package.swift \
      --replace-fail '.macOS(.v12)' ".macOS(\"$MACOSX_DEPLOYMENT_TARGET\")"
  '';

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-q3PZjzn2Zweyv5q2c4WgSe11FTp6EO3qxR/Qu3fOm6I=";
  };

  nativeBuildInputs = [
    swift
    swiftpmHook
  ];

  meta = {
    description = "Documentation compiler for Swift";
    mainProgram = "docc";
    homepage = "https://github.com/apple/swift-docc";
    platforms = with lib.platforms; linux ++ darwin;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
