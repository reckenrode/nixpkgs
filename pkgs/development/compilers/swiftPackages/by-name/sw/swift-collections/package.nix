{
  lib,
  fetchFromGitHub,
  cmake,
  ninja,
  swift,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-collections";
  version = "1.3.0";

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "apple";
    repo = "swift-collections";
    tag = finalAttrs.version;
    hash = "sha256-Bhfmf02JbmEdM1TFdM8UGxlouR8kr61WlU1uI2v67v8=";
  };

  postPatch = ''
    substituteInPlace cmake/modules/SwiftSupport.cmake \
      --replace-fail '    DESTINATION lib' "DESTINATION ''${!outputDev}/lib" \
      --replace-fail 'lib/''${swift}/''${COLLECTIONS_PLATFORM}$<$<BOOL:''${COLLECTIONS_INSTALL_ARCH_SUBDIR}>:/''${COLLECTIONS_ARCH}>' \''${CMAKE_INSTALL_LIBDIR}
  '';

  strictDeps = true;

  preConfigure = ''
    appendToVar cmakeFlags -DCMAKE_Swift_COMPILER_TARGET=${stdenv.hostPlatform.swift.triple}
    appendToVar cmakeFlags -DCMAKE_Swift_FLAGS=-module-cache-path\ "$NIX_BUILD_TOP/module-cache"
  '';

  nativeBuildInputs = [
    cmake
    ninja
    swift
  ];

  postInstall = ''
    moveToOutput lib/swift "''${!outputDev}"
    moveToOutput lib/swift_static "''${!outputDev}"

    # Install CMake config file for the Swift Collections library.
    mkdir -p mkdir -p "''${!outputDev}/lib/cmake/SwiftCollections"
    substitute ${./files/SwiftCollectionsConfig.cmake} "''${!outputDev}/lib/cmake/SwiftCollections/SwiftCollectionsConfig.cmake" \
      --replace-fail '@buildType@' ${if stdenv.hostPlatform.isStatic then "STATIC" else "SHARED"} \
      --replace-fail '@include@' "''${!outputDev}" \
      --replace-fail '@lib@' "''${!outputLib}" \
      --replace-fail '@swiftPlatform@' ${stdenv.hostPlatform.swift.platform}
  '';

  __structuredAttrs = true;

  meta = {
    homepage = "https://github.com/apple/swift-collections";
    description = "Commonly used data structures for Swift";
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
