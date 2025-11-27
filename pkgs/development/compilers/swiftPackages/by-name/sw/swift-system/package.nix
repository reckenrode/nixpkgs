{
  lib,
  fetchFromGitHub,
  cmake,
  ninja,
  swift,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-system";
  version = "1.6.4";

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "apple";
    repo = "swift-system";
    tag = finalAttrs.version;
    hash = "sha256-bfxm2WS+4qcgSzheWTvRloDAIIIHzPZ8SaAZq9bWmSc=";
  };

  patches = [ ./patches/0001-gnu-install-dirs.patch ];

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

    # Install CMake config file for Swift System.
    mkdir -p mkdir -p "''${!outputDev}/lib/cmake/SwiftSystem"
    substitute ${./files/SwiftSystemConfig.cmake} "''${!outputDev}/lib/cmake/SwiftSystem/SwiftSystemConfig.cmake" \
      --replace-fail '@include@' "''${!outputDev}" \
      --replace-fail '@lib@' "''${!outputLib}" \
      --replace-fail '@swiftPlatform@' ${stdenv.hostPlatform.swift.platform}
  '';

  __structuredAttrs = true;

  meta = {
    homepage = "https://github.com/apple/swift-system";
    description = "Low-level APIs and types for Swift";
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
