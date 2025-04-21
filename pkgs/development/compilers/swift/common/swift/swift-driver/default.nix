{
  lib,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  ncurses,
  sqlite,
  bootSwift,
  bootSwiftpmHook,
  xctest,
  version_src,
}:

final: prev:
let
  src = fetchFromGitHub {
    name = "swift-driver";
    inherit (version_src.swift-driver)
      owner
      repo
      tag
      hash
      ;

    # Update `Package.resolved` to make sure it’s consistent with SwiftPM.
    postFetch = ''
      cp ${./Package-${final.version}.resolved} "$out/Package.resolved"
    '';
  };

  swiftpmDeps = fetchSwiftPMDeps {
    pname = "swift-driver";
    inherit (final) version;
    inherit src;
    hash = version_src.swift-driver.deps-hash;
  };
in
{
  outputs = (prev.outputs or [ ]) ++ [ "driver" ];

  srcs = (prev.srcs or [ ]) ++ [ src ];

  patches =
    (prev.patches or [ ])
    ++ lib.optionals (lib.versionOlder final.version "6.1") [
      # Backport of a patch to make the the early Swift Driver location configurable via CMake.
      # See: https://github.com/swiftlang/swift/pull/75965/commits/cc27c83fc8dd0b487c3b573adfb416a7c3dcdf81
      ./patches/adjust-early-swift-driver-handling.patch
    ];

  swiftpmRoot = "swift-driver";

  postUnpack =
    (prev.postUnpack or "")
    + ''
      # Inlined from `swiftpmHook` because swift-driver won’t be writable when the env hook runs.
      chmod -R u+w "$NIX_BUILD_TOP/swift-driver"
      echo "Unpacking SwiftPM dependencies"
      buildRoot=$NIX_BUILD_TOP/''${swiftpmRoot-"$sourceRoot"}/.build
      mkdir -p "$buildRoot/checkouts"
      for dep in ${lib.escapeShellArg swiftpmDeps}/checkouts/*; do
          ln -s "$dep" "$buildRoot/checkouts/$(basename "$dep")"
      done
      install -m 0600 "${lib.escapeShellArg swiftpmDeps}/workspace-state.json" "$buildRoot/workspace-state.json"

      # Make a copy of swift-driver for building the early swift-driver needed to build Swift.
      cp -r "$NIX_BUILD_TOP/swift-driver" "$NIX_BUILD_TOP/early-swift-driver"
      earlySwiftDriverPath=$(cd "$NIX_BUILD_TOP/early-swift-driver"; swiftpmBinPath)
    '';

  dontUseSwiftpmBuild = true;
  dontUseSwiftpmCheck = true;
  dontUseSwiftpmInstall = true;

  nativeBuildInputs = (prev.nativeBuildInputs or [ ]) ++ [ bootSwiftpmHook ];

  buildInputs = (prev.buildInputs or [ ]) ++ [
    ncurses
    sqlite
    xctest
  ];

  # Build the early Swift Driver with the bootstrap compiler.
  preConfigure =
    (prev.preConfigure or "")
    + ''
      pushd "$NIX_BUILD_TOP/early-swift-driver" > /dev/null
      swiftpmBuildPhase
      appendToVar cmakeFlags "-DSWIFT_EARLY_SWIFT_DRIVER_BUILD:PATH=$(swiftpmBinPath)"
      popd
    '';

  # This is done in `preInstall` because the Swift install logic automatically creates symlinks to `swift-driver` if
  # it’s already present in `$out/bin`. Note:
  # - Can’t use `postBuild` to build the final Swift Driver because it will be run by `swiftpmBuildPhase`; and
  # - Can’t use `swiftpmInstallPhase` because it will attempt to run `preInstall`.
  preInstall =
    (prev.preInstall or "")
    + ''
      # Rebuild the final Swift Driver is rebuilt with the just-built, Swift compiler.
      pushd "$NIX_BUILD_TOP/swift-driver" > /dev/null
      PATH=$NIX_BUILD_TOP/swift/build/bin:''${PATH/':${lib.getBin bootSwift}/bin'/} swiftpmBuildPhase
      products=$(swiftpmBinPath)
      popd

      # The `driver` output is used to provide `swiftPackages.swift-driver` for compatibility with packages
      # that expect Swift Driver to be packaged separately.
      mkdir -p "$driver/bin"
      for exe in swift-driver swift-help swift-build-sdk-interfaces; do
        install --verbose -D -m 755 "$products/$exe" "''${!outputBin}/bin/$exe"
        ln -s "''${!outputBin}/bin/$exe" "$driver/bin/$exe"
      done
    '';
}
