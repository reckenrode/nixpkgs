{
  lib,
  cmake,
  fetchFromGitHub,
  ninja,
  stdenv,
  swift,
  useSwift ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-corelibs-libdispatch";
  version = "6.1.1";

  outputs = [
    "out"
    "dev"
    "man"
  ];

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-corelibs-libdispatch";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = lib.fakeHash;
  };

  patches = [ ./disable-swift-overlay.patch ];

  strictDeps = true;

  cmakeFlags = [ (lib.cmakeBool "ENABLE_SWIFT" useSwift) ];

  nativeBuildInputs =
    [
      cmake
      ninja
    ]
    ++ lib.optionals useSwift [ swift ];

  postInstall =
    ''
      # Provide a CMake module. This is primarily used to glue together parts of
      # the Swift toolchain. Modifying the CMake config to do this for us is
      # otherwise more trouble.
      mkdir -p $dev/lib/cmake/dispatch
      export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
      substituteAll ${./glue.cmake} $dev/lib/cmake/dispatch/dispatchConfig.cmake
    '';

  __structuredAttrs = true;

  meta = {
    description = "Grand Central Dispatch";
    platforms = lib.platforms.linux;
    homepage = "https://github.com/swiftlang/swift-corelibs-libdispatch";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ cmm ];
    teams = [ lib.teams.swift ];
  };
})
