{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  stdenv,
  swift,
  swiftpmHook,
  xctest,
  version_src,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-docc";
  inherit (version_src.swift-docc) version;

  src = fetchFromGitHub {
    inherit (version_src.swift-docc)
      owner
      repo
      tag
      hash
      ;
  };

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname src version;
    hash = version_src.swift-docc.deps-hash;
  };

  swiftpmFlags = lib.optionals (!finalAttrs.finalPackage.doCheck) [
    "--product"
    "docc"
  ];

  strictDeps = true;

  nativeBuildInputs = [
    swift
    swiftpmHook
  ];

  doCheck = !stdenv.hostPlatform.isDarwin && stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  checkInputs = [ xctest ];

  __structuredAttrs = true;

  # Canary to verify output of our Swift toolchain does not depend on the Swift
  # compiler itself. (Only its 'lib' output.)
  disallowedRequisites = [ swift.out ];

  meta = {
    description = "Documentation compiler for Swift";
    mainProgram = "docc";
    homepage = "https://github.com/swiftlang/swift-docc";
    platforms = with lib.platforms; linux ++ darwin;
    license = lib.licenses.asl20;
    maintainers = lib.teams.swift.members;
  };
})
