{
  lib,
  cmake,
  fetchFromGitHub,
  llvm_libtool,
  ninja,
  stdenv,
  swift-argument-parser,
  swift-llbuild,
  swift-no-swift-driver,
  swift-tools-support-core,
  swift_release,
}:

let
  swiftPlatform = stdenv.hostPlatform.swift.platform;
in

# Swift Driver is a dependency of SwiftPM.
# It must be built with CMake to avoid dependency cycles. It can’t be built with swift-driver for obvious reasons.
stdenv.mkDerivation (finalAttrs: {
  pname = "swift-driver";
  version = swift_release;

  outputs = [
    "out"
    "dev"
    "lib"
  ];

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-driver";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = "sha256-CZYqUadpAsAUnCTZElobZS9nlMfCuHiMnac3o0k7hnI=";
  };

  patches = [
    ./patches/0001-gnu-install-dirs.patch
    # Adjust the built libraries to match the way SwiftPM would build the Swift Compiler Driver.
    ./patches/0002-match-swiftpm-products.patch
    # Resolve any symlinks when adding rpaths. This is helpful to avoid pulling in the whole Swift closure when only
    # the stdlib is needed.
    ./patches/0003-resolve-rpath-symlinks.patch
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

  buildInputs = [
    swift-argument-parser
    swift-llbuild
    swift-tools-support-core
  ];

  env.NIX_LDFLAGS = lib.optionalString stdenv.hostPlatform.isDarwin "-headerpad_max_install_names";

  postInstall = ''
    # Install the swiftmodule.
    mkdir -p "''${!outputDev}/lib/swift/${swiftPlatform}"
    cp -v swift/*.swiftmodule "''${!outputDev}/lib/swift/${swiftPlatform}"

    # Install CMake config file for the Swift Compiler Driver library.
    mkdir -p mkdir -p "''${!outputDev}/lib/cmake/SwiftDriver"
    substitute ${./files/SwiftDriverConfig.cmake} "''${!outputDev}/lib/cmake/SwiftDriver/SwiftDriverConfig.cmake" \
      --replace-fail '@buildType@' ${if stdenv.hostPlatform.isStatic then "STATIC" else "SHARED"} \
      --replace-fail '@include@' "''${!outputDev}" \
      --replace-fail '@lib@' "''${!outputLib}" \
      --replace-fail '@swiftPlatform@' ${swiftPlatform}
  '';

  __structuredAttrs = true;

  meta = {
    mainProgram = "swift-driver";
    homepage = "https://github.com/apple/swift-driver";
    description = "Swift compiler driver written in Swift";
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
