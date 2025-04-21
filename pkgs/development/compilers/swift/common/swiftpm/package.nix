{
  lib,
  callPackage,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  ncurses,
  replaceVars,
  sqlite,
  stdenv,
  swift,
  version_src,
  enableCmakeBuild ? false,
}:

let
  cmakeBuild = callPackage ./cmake-build.nix { inherit swift; };
  swiftpmBuild = callPackage ./swiftpm-build.nix { };
in
stdenv.mkDerivation (
  lib.extends (if enableCmakeBuild then cmakeBuild else swiftpmBuild) (finalAttrs: {
    inherit (version_src.swiftpm) version;

    src = fetchFromGitHub {
      inherit (version_src.swiftpm)
        owner
        repo
        tag
        hash
        ;

      # Upstream doesn’t provide `Package.resolved` even though the deps are supposed to be consistent
      # between SwiftPM and its dependencies.
      postFetch = ''
        cp ${./Package-${finalAttrs.version}.resolved} "$out/Package.resolved"
      '';
    };

    patches = [
      # Use swift-corelibs-xctest even on Darwin (because XCTest.framework is not available in nixpkgs).
      ./patches/${lib.versions.major finalAttrs.version}/darwin-swift-corelibs-xctest.patch
      # Look for the Swift Concurrency backdeploy dylib in the `lib` output of Swift instead of the main toolchain.
      (replaceVars ./patches/${lib.versions.major finalAttrs.version}/fix-backdeploy-rpath.patch {
        swift-lib = lib.getLib swift;
      })
      # SwiftPM invokes `clang` to compile C++, but that doesn’t work with the wrapper. Patch it to work.
      # See: https://github.com/NixOS/nixpkgs/issues/191152
      # ./patches/${lib.versions.major finalAttrs.version}/fix-clang-cxx.patch
      # SwiftPM does its own `.pc` parsing, so it avoids the `pkg-config` wrapper used in nixpkgs to support
      # cross-compilation. This patch adds support for `"PKG_CONFIG_PATH_FOR_TARGET` to SwiftPM.
      ./patches/${lib.versions.major finalAttrs.version}/nix-pkgconfig-vars.patch
      # SwiftPM tries to use `sandbox-exec` for sandboxing, which will fail when it is run in the Nix sandbox.
      ./patches/disable-sandbox.patch
      # SwiftPM falls back to looking for manifests and plugins in the Swift compiler location. Find them in $out.
      ./patches/fix-manifest-path.patch
      # Silence warnings about not finding the cache folder when building packages by moving it to $NIX_BUILD_TOP.
      ./patches/nix-build-caches.patch
      # SwiftPM assumes that you are using Apple Clang on macOS, but nixpkgs builds Clang from upstream LLVM.
      # This effectively disables using `-index-store-path`, which isn’t supported by LLVM’s Clang.
      ./patches/set-compiler-vendor.patch
    ];

    postPatch = ''
      # Need to reference $out, so this can’t be substituted by `replaceVars`.
      substituteInPlace Sources/PackageModel/UserToolchain.swift \
        --replace-fail '@out@' "$out"

      # Replace hardcoded references to `xcrun` with `PATH`-based references.
      find Sources -name '*.swift' -exec sed -i '{}' -e 's|/usr/bin/xcrun|xcrun|g' \;
    '';

    swiftpmDeps = fetchSwiftPMDeps {
      inherit (finalAttrs) pname src version;
      hash = version_src.swiftpm.deps-hash;

      postBuild = ''
        # Disable performance tests in llbuild, which require XCTest.framework. XCTest.framework is not available.
        substituteInPlace "$out/checkouts/swift-llbuild/CMakeLists.txt" \
          --replace-fail 'add_subdirectory(perftests)' ""

        # Disable using XCTest framework properties that aren’t provided by swift-corelibs-xctest.
        substituteInPlace "$out/checkouts/swift-tools-support-core/Sources/TSCTestSupport/XCTestCasePerf.swift" \
          --replace-fail '#if canImport(Darwin)' '#if false'

        # Use ncurses instead of curses
        grep -rl 'curses)' "$out/checkouts/swift-llbuild" -Z | while IFS= read -d "" file; do
          substituteInPlace "$file" --replace-fail 'curses)' 'ncurses)'
        done
      '';
    };

    strictDeps = true;

    nativeBuildInputs = [ swift ];

    buildInputs = [
      ncurses
      sqlite
    ];

    __structuredAttrs = true;

    meta = {
      description = "Package Manager for the Swift Programming Language";
      homepage = "https://github.com/swiftlang/swift-package-manager";
      platforms = with lib.platforms; darwin ++ linux ++ windows;
      license = lib.licenses.asl20;
      maintainers = lib.teams.swift.members;
    };
  })
)
