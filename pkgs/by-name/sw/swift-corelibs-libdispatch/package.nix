{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  ninja,
  useSwift ? true,
  swift,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-corelibs-libdispatch";
  version = "6.1.1";

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-corelibs-libdispatch";
    tag = "swift-${finalAttrs.version}-RELEASE";
    hash = lib.fakeHash;
  };

  outputs = [
    "out"
    "dev"
    "man"
  ];

  nativeBuildInputs =
    [ cmake ]
    ++ lib.optionals useSwift [
      ninja
      swift
    ];

  patches = [ ./disable-swift-overlay.patch ];

  cmakeFlags = lib.optional useSwift "-DENABLE_SWIFT=ON";

  postInstall = ''
    # Provide a CMake module. This is primarily used to glue together parts of
    # the Swift toolchain. Modifying the CMake config to do this for us is
    # otherwise more trouble.
    mkdir -p $dev/lib/cmake/dispatch
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/dispatch/dispatchConfig.cmake
  '';

  strictDeps = true;

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
