{
  lib,
  stdenv,
  stdenvNoCC,
  stdlib,
  symlinkJoin,
  swift-corelibs-xctest,
  swift-driver,
  swift-testing,
  swift-collections,
  swift-corelibs-foundation,
  swift-corelibs-libdispatch,
  swift-foundation-icu,
  swift-foundation,
  swift_release,
  swiftc,

  # Tests
  test-cxx-interop,
  test-foundation-macros,
  test-swift-differentiation,
  test-swift-testing,

  # Required by the setup-hook
  llvmPackages_current,
  patchelf,
}@args:

let
  getBuildHost = lib.mapAttrs (_: pkg: pkg.__spliced.buildHost or pkg);
  getHostTarget = lib.mapAttrs (_: pkg: pkg.__spliced.hostTarget or pkg);

  buildHostPackages = getBuildHost args;
  hostTargetPackages = getHostTarget args;

  includeTesting = swiftc.supportsMacros && swift-testing != null;

  swift-foundation-macros = stdenvNoCC.mkDerivation {
    pname = "swift-foundation-macros";
    version = lib.getVersion swift-foundation;

    buildCommand = ''
      mkdir -p "$out/lib/swift/host/plugins"
      ln -s ${lib.escapeShellArg hostTargetPackages.swift-foundation.dev}/lib/swift/host/plugins/libFoundationMacros${stdenv.hostPlatform.extensions.sharedLibrary} "$out/lib/swift/host/plugins"
    '';
  };

  # This makes sure that linking to `libdispatch.so` and `libBlocksRuntime.so` does not pull in previous stages
  # of the bootstrap toolchain.
  swift-corelibs-libdispatch-no-overlay = swift-corelibs-libdispatch.override { useSwift = false; };
  hostTargetPackages_swift-corelibs-libdispatch-no-overlay =
    hostTargetPackages.swift-corelibs-libdispatch.override
      { useSwift = false; };

  # `out` and `dev` are merged because that’s what Swift expects.
  outLinks = symlinkJoin {
    name = "swift" + lib.removePrefix "swiftc" (lib.getName swiftc) + "-${swift_release}-out";
    paths = [
      buildHostPackages.swiftc.out
      hostTargetPackages.swiftc.dev
    ]
    ++ lib.optionals includeTesting [
      hostTargetPackages.swift-corelibs-xctest.dev
      hostTargetPackages.swift-corelibs-xctest.out
      hostTargetPackages.swift-testing.dev
      hostTargetPackages.swift-testing.out
    ]
    ++ lib.optionals (stdlib != null) [
      hostTargetPackages.stdlib.dev
      hostTargetPackages.stdlib.out
      hostTargetPackages.swiftc.dev
    ]
    ++ lib.optionals (swift-driver != null) [
      buildHostPackages.swift-driver.out
      hostTargetPackages.swift-driver.dev
      hostTargetPackages.swift-driver.lib
    ]
    ++ lib.optionals (stdenv.hostPlatform.isDarwin && swift-foundation != null) [
      # Needed for FoundationMacros, which is otherwise not part of the SDK on Darwin.
      hostTargetPackages.swift-foundation.out
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isDarwin) (
      lib.optionals (swift-corelibs-libdispatch != null) [
        hostTargetPackages.swift-corelibs-libdispatch.out
        hostTargetPackages.swift-corelibs-libdispatch.dev
        hostTargetPackages_swift-corelibs-libdispatch-no-overlay.out
        hostTargetPackages_swift-corelibs-libdispatch-no-overlay.dev
      ]
      ++ lib.optionals (swift-foundation != null) [
        #        hostTargetPackages.swift-collections.dev
        #        hostTargetPackages.swift-collections.out
        hostTargetPackages.swift-corelibs-foundation.out
        hostTargetPackages.swift-corelibs-foundation.dev
        hostTargetPackages.swift-foundation-icu.out
        hostTargetPackages.swift-foundation.dev
        hostTargetPackages.swift-foundation.out
      ]
    );
  };

  #  devLinks = symlinkJoin {
  #    name = "swift" + lib.removePrefix "swiftc" (lib.getName swiftc) + "-${swift_release}-dev";
  #    paths = [
  #      hostTargetPackages.swiftc.dev
  #    ]
  #    ++ lib.optionals includeTesting [
  #      hostTargetPackages.swift-corelibs-xctest.dev
  #      hostTargetPackages.swift-corelibs-xctest.out
  #      hostTargetPackages.swift-testing.dev
  #      hostTargetPackages.swift-testing.out
  #    ]
  #    ++ lib.optionals (stdlib != null) [
  #      hostTargetPackages.stdlib.dev
  #    ]
  #    ++ lib.optionals (swift-driver != null) [
  #      hostTargetPackages.swift-driver.dev
  #    ]
  #    ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
  #      buildHostPackages.swift-corelibs-libdispatch.dev
  #      # buildHostPackages.swift-corelibs-foundation.dev
  #    ];
  #  };

  docLinks = symlinkJoin {
    name = "swift" + lib.removePrefix "swiftc" (lib.getName swiftc) + "-${swift_release}-doc";
    paths = [
      hostTargetPackages.swiftc.doc
    ];
  };

  manLinks = symlinkJoin {
    name = "swift" + lib.removePrefix "swiftc" (lib.getName swiftc) + "-${swift_release}-man";
    paths = [
      hostTargetPackages.swiftc.man
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isDarwin && swift-corelibs-libdispatch != null) [
      buildHostPackages.swift-corelibs-libdispatch.man
      # buildHostPackages.swift-corelibs-foundation.man
    ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "swift" + lib.removePrefix "swiftc" (lib.getName swiftc);
  version = swift_release;

  outputs = [
    "out"
    "doc"
    "man"
  ];

  strictDeps = true;

  # Will effectively be `buildInputs` when swift is put in `nativeBuildInputs`.
  depsTargetTargetPropagated =
    lib.optionals (stdlib != null) [
      # Propagate the stdlib to make sure the linker wrapper will pick up the dynamic and static libraries.
      stdlib
    ]
    ++ lib.optionals includeTesting [
      swift-corelibs-xctest.out
      swift-testing.out
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isDarwin) (
      lib.optionals (swift-corelibs-libdispatch != null) [
        swift-corelibs-libdispatch-no-overlay.out
        swift-corelibs-libdispatch.out
      ]
      ++ lib.optionals (swift-foundation != null) [
        swift-corelibs-foundation.out
        swift-foundation-icu.out
        swift-foundation.out
      ]
    );

  buildCommand = ''
    mkdir -p "$out" "$doc" "man"

    cp -r ${lib.escapeShellArg outLinks}/* "$out"
    cp -r ${lib.escapeShellArg docLinks}/* "$doc"
    cp -r ${lib.escapeShellArg manLinks}/* "$man"

    # Make writable temporarily to allow for the fixups below to be made to the outputs.
    chmod -R u+w "$out/bin" "$out/lib" "$out/nix-support"

    # `swift-frontend` expects to find everything relative to its location after resolving symlinks.
    # Also copy `swift-driver` assuming it does similar.
    for exe in swift-driver swift-frontend; do
      if [ -e "$out/bin/$exe" ]; then
        orig=$(readlink "$out/bin/$exe")
        rm "$out/bin/$exe"
        cp "$orig" "$out/bin/$exe"
      fi
    done

    # Make sure `swift` and `swiftc` point to `swift-driver` if present.
    if [ -e "$out/bin/swift-driver" ]; then
      for exe in swift swiftc; do
        rm -f "$out/bin/$exe"
        ln -s swift-driver "$out/bin/$exe"
      done
    fi

    # Propagated inputs in `$dev/nix-support` have to be substituted to use this derivation instead of swiftc.
    for f in "$out/nix-support/"*; do
      orig=$(readlink "$f")
      rm "$f"
      substitute "$orig" "$f" \
        --replace-quiet ${lib.escapeShellArg hostTargetPackages.swiftc.out} "$out"
    done

    # Don’t propagate CMake files for toolchain dependencies. These are an implementation detail of the package set.
    rm -rf "$out/lib/cmake"

    recordPropagatedDependencies

    ${lib.optionalString (stdlib != null) ''
      # Can’t use `replaceVars` because it needs to substitute $out.
      substitute ${./setup-hook.sh} "$out/nix-support/setup-hook" \
        --replace-fail @patchelf@ ${lib.escapeShellArg (lib.getExe buildHostPackages.patchelf)} \
        --replace-fail @objdump@ ${lib.escapeShellArg (lib.getExe' buildHostPackages.llvmPackages_current.llvm "llvm-objdump")} \
        --replace-fail @install_name_tool@ ${lib.escapeShellArg (lib.getExe' buildHostPackages.llvmPackages_current.llvm "llvm-install-name-tool")} \
        --replace-fail @stdlibPath@ ${lib.escapeShellArg stdlib.out} \
        --replace-fail @swiftPath@ "$out" \
        --replace-fail @swiftPlatform@ ${stdenv.hostPlatform.swift.platform}
    ''}

    chmod -R u-w "$out/bin" "$out/lib" "$out/nix-support"
  '';

  __structuredAttrs = true;

  passthru = {
    inherit swiftc swift-driver;
  };

  passthru.tests = {
    inherit test-cxx-interop test-foundation-macros test-swift-differentiation;
  }
  // lib.optionalAttrs (!stdenv.hostPlatform.isDarwin) {
    inherit test-swift-testing;
  };

  # passthru.tests = callPackage ./tests { };

  meta = {
    description = "Swift Programming Language";
    homepage = "https://github.com/swiftlang/swift";
    inherit (swiftc.meta) platforms badPlatforms;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
