{
  lib,
  fetchFromGitHub,
  cmake,
  llvm_libtool,
  ninja,
  swift-no-swift-driver,
  stdenv,
}:

let
  swiftPlatform = stdenv.hostPlatform.swift.platform;
in

# Swift Argument Parser is a dependency to both Swift Compiler Driver and SwiftPM.
# It must be built with CMake and use Swift without swift-driver to avoid dependency cycles.
stdenv.mkDerivation (finalAttrs: {
  pname = "swift-argument-parser";
  version = "1.7.0";

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "apple";
    repo = "swift-argument-parser";
    tag = finalAttrs.version;
    hash = "sha256-1J68vCB4P9MBznK4cPX9TzLQId+r5//45M3C8G6zg+c=";
  };

  patches = [
    # Install libSwiftArgumentParserToolInfo.a and its module as well.
    ./patches/0001-install-argument-parser-tool-info.patch
  ];

  strictDeps = true;

  preConfigure = ''
    appendToVar cmakeFlags -DCMAKE_Swift_COMPILER_TARGET=${stdenv.hostPlatform.swift.triple}
    appendToVar cmakeFlags -DCMAKE_Swift_FLAGS=-module-cache-path\ "$NIX_BUILD_TOP/module-cache"
  '';

  nativeBuildInputs = [
    cmake
    ninja
    swift-no-swift-driver
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ llvm_libtool ];

  __structuredAttrs = true;

  postInstall = ''
    moveToOutput lib/swift "''${!outputDev}"
    moveToOutput lib/swift_static "''${!outputDev}"

    # Install CMake config file for the Swift Argument Parser library.
    mkdir -p "''${!outputDev}/lib/cmake/ArgumentParser"
    substitute ${./files/ArgumentParserConfig.cmake} "''${!outputDev}/lib/cmake/ArgumentParser/ArgumentParserConfig.cmake" \
      --replace-fail '@buildType@' ${if stdenv.hostPlatform.isStatic then "STATIC" else "SHARED"} \
      --replace-fail '@include@' "''${!outputDev}" \
      --replace-fail '@lib@' "''${!outputLib}" \
      --replace-fail '@swiftPlatform@' ${swiftPlatform}
  '';

  meta = {
    homepage = "https://github.com/apple/swift-argument-parser";
    description = "Type-safe argument parsing for Swift";
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
