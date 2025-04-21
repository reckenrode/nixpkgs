{
  lib,
  fetchFromGitHub,
  swift,
  stdenv,
  cmake,
  ninja,
  replaceVars,
}:

let
  inherit (stdenv.hostPlatform.extensions) sharedLibrary;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "swift-testing";
  version = "6.1.1";

  srcs = [
    (fetchFromGitHub {
      name = "swift-testing";
      owner = "swiftlang";
      repo = "swift-testing";
      tag = "swift-${finalAttrs.version}-RELEASE";
      hash = "sha256-muRT0jrVqAtLT8cMj0gBwmRIemtrpSgFk2XmX0IFZeE=";
    })
    (fetchFromGitHub {
      name = "swift-syntax";
      owner = "swiftlang";
      repo = "swift-syntax";
      tag = "swift-${finalAttrs.version}-RELEASE";
      hash = "sha256-GaC1h89UYStAFeNXJ+nBFxPwF/No7L4Vpw0NmrGTCb8=";
    })
  ];

  sourceRoot = "swift-testing";

  postUnpack = ''
    chmod -R u+w swift-syntax
  '';

  postPatch = ''
    # Make installation paths consistent between platforms
    substituteInPlace Sources/CMakeLists.txt \
      --replace-fail plugins/libTestingMacros.so plugins/testing/libTestingMacros.so
    substituteInPlace Sources/TestingMacros/CMakeLists.txt \
      --replace-fail plugins\" plugins/testing\"
    substituteInPlace cmake/modules/SwiftModuleInstallation.cmake \
      --replace-fail \''${swift_os}\" \''${swift_os}/testing\"
  '';

  cmakeFlags = [ (lib.cmakeBool "BUILD_SHARED_LIBS" true) ];

  # Swift doesn’t install the CMake files required to use its SwiftSyntax, but Swift Testing needs to be linked against
  # it for a toolchain build. This generates a compatible `SwiftSynaxConfig.cmake`.
  preConfigure = ''
    if [ "$(basename "$PWD")" = "swift-testing" ]; then
      pushd "$NIX_BUILD_TOP/swift-syntax" > /dev/null
      cmakeFlags+=" -DSWIFT_MODULE_ABI_NAME_PREFIX:STRING=Compiler" cmakeConfigurePhase
      substituteInPlace cmake/modules/SwiftSyntaxConfig.cmake \
        --replace-fail "''${NIX_BUILD_TOP/'/private'/}/swift-syntax/build/lib" ${lib.escapeShellArg swift.out}/lib \
        --replace-fail "''${NIX_BUILD_TOP/'/private'/}/swift-syntax/build/Sources" ${lib.escapeShellArg swift.out}/lib/swift/host
      sed -i cmake/modules/SwiftSyntaxConfig.cmake \
        -e 's/\(INTERFACE_INCLUDE_DIRECTORIES.*\)\/Swift[^"]*/\1/g'
      appendToVar cmakeFlags "-DSwiftSyntax_DIR:PATH=$PWD/cmake/modules"
      popd
    fi
  '';

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
    swift
  ];

  postInstall =
    ''
      moveToOutput lib "''${!outputLib}"
      install -D -t "''${!outputDev}/lib/swift/host/plugins/testing" \
        lib/swift/host/plugins/testing/libTestingMacros${sharedLibrary}
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      install_name_tool "''${!outputLib}/lib/swift/${swift.swiftPlatform}/testing/libTesting${sharedLibrary}" \
        -id "''${!outputLib}/lib/swift/${swift.swiftPlatform}/testing/libTesting${sharedLibrary}"
      install_name_tool "''${!outputDev}/lib/swift/host/plugins/testing/libTestingMacros${sharedLibrary}" \
        -id "''${!outputDev}/lib/swift/host/plugins/testing/libTestingMacros${sharedLibrary}"
    '';

  __structuredAttrs = true;

  meta = {
    description = "Modern testing package for Swift";
    homepage = "https://github.com/swiftlang/swift-testing";
    platforms = with lib.platforms; darwin ++ linux ++ windows;
    license = lib.licenses.asl20;
    maintainers = lib.teams.swift.members;
  };
})
