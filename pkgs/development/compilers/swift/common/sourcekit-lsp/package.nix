{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  fetchpatch2,
  ncurses,
  pkg-config,
  sqlite,
  stdenv,
  swift,
  swiftpmHook,
  xctest,
  version_src,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sourcekit-lsp";
  inherit (version_src.sourcekit-lsp) version;

  src = fetchFromGitHub {
    inherit (version_src.sourcekit-lsp)
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

  patches = lib.optionals (lib.versionOlder finalAttrs.version "6.0") [
    # Fix a compilation error with Clang 19
    # See: https://github.com/swiftlang/indexstore-db/pull/220
    (fetchpatch2 {
      url = "https://github.com/swiftlang/indexstore-db/commit/6120b53b1e8774ef4e2ad83438d4d94961331e72.diff?full_index=1";
      extraPrefix = ".build/checkouts/indexstore-db/";
      stripLen = 1;
      hash = "sha256-ejOrRTMBqHbj2kOAQKs/95zdCIgdQC53HQhLrCaSqps=";
    })
  ];

  # TODO: move to swiftpmHook
  prePatch = lib.optionals (lib.versionOlder finalAttrs.version "6.0") ''
    # Helper that makes a swiftpm dependency mutable by copying the source.
    swiftpmMakeMutable() {
      local orig="$(readlink .build/checkouts/$1)"
      rm .build/checkouts/$1
      cp -r "$orig" .build/checkouts/$1
      chmod -R u+w .build/checkouts/$1
    }
    swiftpmMakeMutable indexstore-db
  '';

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname src version;
    hash = version_src.sourcekit-lsp.deps-hash;
  };

  swiftpmFlags = lib.optionals (!finalAttrs.finalPackage.doCheck) [
    "--product"
    "sourcekit-lsp"
  ];

  strictDeps = true;

  nativeBuildInputs = [
    swift
    swiftpmHook
    pkg-config
  ];

  buildInputs = [
    ncurses
    sqlite
  ];

  doCheck = !stdenv.hostPlatform.isDarwin && stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  checkInputs = [ xctest ];

  __structuredAttrs = true;

  # Canary to verify output of our Swift toolchain does not depend on the Swift
  # compiler itself. (Only its 'lib' output.)
  disallowedRequisites = [ swift.out ];

  meta = {
    description = "Language Server Protocol implementation for Swift and C-based languages";
    mainProgram = "sourcekit-lsp";
    homepage = "https://github.com/swiftlang/sourcekit-lsp";
    platforms = with lib.platforms; darwin ++ linux ++ windows;
    license = lib.licenses.asl20;
    maintainers = lib.teams.swift.members;
  };
})
