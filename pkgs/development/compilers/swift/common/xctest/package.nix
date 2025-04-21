{
  lib,
  cmake,
  ninja,
  fetchFromGitHub,
  stdenv,
  swift,
  version_src,
}:

# Build with CMake instead of SwiftPM to avoid SwiftPM and XCTest mutually depending on each other.
stdenv.mkDerivation (finalAttrs: {
  pname = "xctest";
  inherit (version_src.xctest) version;

  src = fetchFromGitHub {
    inherit (version_src.xctest)
      owner
      repo
      tag
      hash
      ;
  };

  postPatch =
    # XCTest for Swift 6.1 and older installs the dylib to `$out/lib/swift/darwin` instead of `$out/lib/swift/macosx`.
    lib.optionalString (stdenv.hostPlatform.isDarwin && lib.versionOlder finalAttrs.version "6.2") ''
      substituteInPlace CMakeLists.txt \
        --replace-fail '$<LOWER_CASE:''${CMAKE_SYSTEM_NAME}>' macosx
    '';

  cmakeFlags =
    [ (lib.cmakeBool "USE_FOUNDATION_FRAMEWORK" true) ]
    # Otherwise, Darwin will default to macOS 15.0 for its deployment target.
    # TODO: Align all SwiftPM packages around a similar deployment target.
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      (lib.cmakeFeature "CMAKE_Swift_FLAGS" "-target arm64-apple-macosx10.15")
    ];

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
    swift
  ];

  __structuredAttrs = true;

  meta = {
    description = "Framework for writing unit tests in Swift";
    homepage = "https://github.com/swiftlang/swift-corelibs-xctest";
    platforms = with lib.platforms; darwin ++ linux ++ windows;
    license = lib.licenses.asl20;
    maintainers = lib.teams.swift.members;
  };
})
