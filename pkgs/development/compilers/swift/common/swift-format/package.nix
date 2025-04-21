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
  pname = "swift-format";
  inherit (version_src.swift-format) version;

  src = fetchFromGitHub {
    inherit (version_src.swift-format)
      owner
      repo
      tag
      hash
      ;

    # Upstream doesn’t provide `Package.resolved`.
    postFetch = ''
      cp ${./Package-${finalAttrs.version}.resolved} "$out/Package.resolved"
    '';
  };

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname src version;
    hash = version_src.swift-format.deps-hash;
  };

  swiftpmFlags = lib.optionals (!finalAttrs.finalPackage.doCheck) [
    "--product"
    "swift-format"
  ];

  strictDeps = true;

  nativeBuildInputs = [
    swift
    swiftpmHook
  ];

  doCheck = !stdenv.hostPlatform.isDarwin && stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  checkInputs = [ xctest ];

  __structuredAttrs = true;

  meta = {
    description = "Formatting technology for Swift source code";
    homepage = "https://github.com/swiftlang/swift-format";
    platforms = with lib.platforms; darwin ++ linux ++ windows;
    license = lib.licenses.asl20;
    maintainers = lib.teams.swift.members;
    mainProgram = "swift-format";
  };
})
