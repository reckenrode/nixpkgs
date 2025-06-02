{
  lib,
  cmake,
  fetchFromGitHub,
  lld,
  ninja,
  stdenv,
  swift,
  swift-corelibs-libdispatch,
  useSwift ? true,
}:

let
  swift-corelibs-libdispatch-no-overlay = swift-corelibs-libdispatch.override { useSwift = false; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "swift-corelibs-libdispatch${lib.optionalString useSwift "-swift-overlay"}";
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
    hash = "sha256-IyjVH1ss1LEJbZmS3r2+JQd3vqfyc+cSvkUmSNETTew=";
  };

  strictDeps = true;

  # The Swift overlay is built separately using the no-overlay derivation as a base.
  cmakeFlags = [ (lib.cmakeBool "ENABLE_SWIFT" useSwift) ];

  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.hostPlatform.isWindows "-fuse-ld=lld";

  nativeBuildInputs =
    [
      cmake
      ninja
    ]
    ++ lib.optionals useSwift [ swift ]
    ++ lib.optionals stdenv.hostPlatform.isWindows [ lld ];

  postInstall =
    ''
      # Provide a CMake module. This is primarily used to glue together parts of
      # the Swift toolchain. Modifying the CMake config to do this for us is
      # otherwise more trouble.
      mkdir -p "''${!outputDev}/lib/cmake/dispatch"
      export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
      substituteAll ${./glue.cmake} "''${!outputDev}/lib/cmake/dispatch/dispatchConfig.cmake"
    ''
    + lib.optionalString useSwift ''
      rm "''${!outputLib}/lib"/*"$dylibExt"
      for dylib in ${lib.escapeShellArg (lib.getLib swift-corelibs-libdispatch-no-overlay)}/lib/*"$dylibExt"; do
        ln -s "$dylib" "''${!outputLib}/lib/$(basename "$dylib")"
      done
    '';

  __structuredAttrs = true;

  meta = {
    description = "Grand Central Dispatch";
    homepage = "https://github.com/swiftlang/swift-corelibs-libdispatch";
    platforms = lib.platforms.freebsd ++ lib.platforms.linux ++ lib.platforms.windows;
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ cmm ];
    teams = [ lib.teams.swift ];
  };
})
