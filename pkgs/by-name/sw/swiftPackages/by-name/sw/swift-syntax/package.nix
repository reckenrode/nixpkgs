{
  lib,
  fetchFromGitHub,
  stdenv,
  cmake,
  ninja,
  swift-no-testing,
  swift_release,
}:

# The build for Swift Syntax extracts the shared libraries from the compiler, which will be re-linked against this
# derivation. This allows macro-based packages to use the libraries from the compiler.
#stdenvNoCC.mkDerivation
stdenv.mkDerivation (finalAttrs: {
  pname = "swift-syntax";
  version = swift_release;

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-syntax";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = "sha256-DMMVJQj590RGGBkTgA89u01ZP2B8kbJTmfu+oxzYPds=";
  };

  patches = [ ./patches/0001-gnu-install-dirs.patch ];

  strictDeps = true;

  preConfigure = ''
    appendToVar cmakeFlags -DCMAKE_Swift_COMPILER_TARGET=${stdenv.hostPlatform.swift.triple}
    appendToVar cmakeFlags -DCMAKE_Swift_FLAGS=-module-cache-path\ "$NIX_BUILD_TOP/module-cache"
  '';

  cmakeFlags = [
    # Defaults to static, but we want shared libraries by default.
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!stdenv.hostPlatform.isStatic))
    # Build and install the modules.
    (lib.cmakeBool "SWIFTSYNTAX_EMIT_MODULE" true)
  ];

  nativeBuildInputs = [
    cmake
    ninja
    swift-no-testing
  ];

  postBuild = ''
    # This library is inexplicably not built, but it’s part of the install target.
    ninja libSwiftCompilerPlugin${stdenv.hostPlatform.extensions.library}
  '';

  postInstall = ''
    moveToOutput lib/swift/host "$dev"

    # Install CMake config file for the Swift Collections library.
    mkdir -p mkdir -p "''${!outputDev}/lib/cmake/SwiftSyntax"
    substitute ${./files/SwiftSyntaxConfig.cmake} "''${!outputDev}/lib/cmake/SwiftSyntax/SwiftSyntaxConfig.cmake" \
      --replace-fail '@buildType@' ${if stdenv.hostPlatform.isStatic then "STATIC" else "SHARED"} \
      --replace-fail '@include@' "''${!outputDev}" \
      --replace-fail '@lib@' "''${!outputLib}"
  '';

  __structuredAttrs = true;

  meta = {
    homepage = "https://github.com/swiftlang/swift-syntax";
    description = "Swift libraries for parsing Swift source code";
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
