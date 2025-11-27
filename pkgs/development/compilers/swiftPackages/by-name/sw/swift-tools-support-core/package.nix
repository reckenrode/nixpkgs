{
  lib,
  cmake,
  fetchFromGitHub,
  llvm_libtool,
  ninja,
  stdenv,
  swift-no-swift-driver,
  swift_release,
}:

let
  swiftPlatform = stdenv.hostPlatform.swift.platform;
in

# Swift Tools Support Core is a dependency to both Swift Compiler Driver and SwiftPM.
# It must be built with CMake and use Swift without swift-driver to avoid dependency cycles.
stdenv.mkDerivation (finalAttrs: {
  pname = "swift-tools-support-core";
  version = swift_release;

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-tools-support-core";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = "sha256-mV+z5sdG/maUzXUhK1vMtsnLCclcjqyXSMO6J2FjBEg=";
  };

  patches = [
    # Match the dynamic library structure of the SwiftPM build when using CMake.
    ./patches/0001-build-SwiftToolsSupport.patch
  ];

  postPatch = ''
    # Disable using XCTest framework properties that aren’t provided by swift-corelibs-xctest.
    substituteInPlace "Sources/TSCTestSupport/XCTestCasePerf.swift" \
      --replace-fail '#if canImport(Darwin)' '#if false'
  '';

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

  postInstall = ''
    # Install the swiftmodule.
    mkdir -p "''${!outputDev}/lib/swift/${swiftPlatform}"
    cp -v swift/*.swiftmodule "''${!outputDev}/lib/swift/${swiftPlatform}"

    # Install the C module
    mkdir -p "''${!outputDev}/include"
    cp -v "$NIX_BUILD_TOP/$sourceRoot/Sources/TSCclibc/include"/* "''${!outputDev}/include"

    # Install CMake config file for the SwiftSupportTools library.
    mkdir -p mkdir -p "''${!outputDev}/lib/cmake/TSC"
    substitute ${./files/TSCConfig.cmake} "''${!outputDev}/lib/cmake/TSC/TSCConfig.cmake" \
      --replace-fail '@buildType@' ${if stdenv.hostPlatform.isStatic then "STATIC" else "SHARED"} \
      --replace-fail '@include@' "''${!outputDev}" \
      --replace-fail '@lib@' "''${!outputLib}" \
      --replace-fail '@swiftPlatform@' ${swiftPlatform}
  '';

  __structuredAttrs = true;

  meta = {
    homepage = "https://github.com/swift/swift-tools-support-core";
    description = "Common infrastructure code used by SwiftPM and llbuild";
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
