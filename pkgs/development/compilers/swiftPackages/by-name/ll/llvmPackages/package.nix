# Swift needs to be built against the matching tag from the LLVM fork in the swiftlang repo.
# Ideally, it would build against upstream LLVM, but it depends on APIs that have not been upstreamed.
# For example: https://github.com/swiftlang/llvm-project/blob/901f89886dcd5d1eaf07c8504d58c90f37b0cfdf/clang/include/clang/AST/StableHash.h

{
  lib,
  apple-sdk_26,
  darwin,
  fetchpatch2,
  fetchFromGitHub,
  generateSplicesForMkScope,
  libuuid,
  lld,
  llvmPackages_19, # Needs to match the `llvmVersion` of the fork.
  python3,
  runCommand,
  stdenv,
  stdlib,
  swift-cmark,
  swiftc,
  swift_release,
}:

let
  swiftLlvmVersion = "17.0.0"; # From https://github.com/swiftlang/swift/blob/swift-$swiftVersion-RELEASE/utils/build_swift/build_swift/defaults.py#L51
  llvmVersion = "19.1.5"; # From https://github.com/swiftlang/llvm-project/blob/swift-$swiftVersion-RELEASE/cmake/Modules/LLVMVersion.cmake
in
(llvmPackages_19.override {
  officialRelease.version = llvmVersion;

  monorepoSrc = fetchFromGitHub {
    owner = "swiftlang";
    repo = "llvm-project";
    tag = "swift-${swift_release}-RELEASE";
    hash = "sha256-5Nb8rQmk6onrc4wKW/kT38FsYsWTqMBWtsHYZLA/0Po=";
  };

  otherSplices = generateSplicesForMkScope [
    "swiftPackages"
    "llvmPackages"
  ];

  patchesFn =
    patches:
    patches
    // {
      # Updated patch that also prevents Clang from trying to copy `clang-deps-launcher.py` to `${llvm}/bin`.
      "clang/gnu-install-dirs.patch" = [ { path = ./patches; } ];
    };
}).overrideScope
  (
    final: prev: {
      version = swiftLlvmVersion;
      release_version = llvmVersion;

      libclang = prev.libclang.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          moveToOutput bin/clang-deps-launcher.py "$python"
        '';
      });

      lldb =
        let
          python3-with-distutils = python3.withPackages (pkgs: [ pkgs.distutils ]);
          # LLDB needs internal headers to build. Run configure phase to generate `Config.h` then copy the rest.
          swiftHeaders = swiftc.overrideAttrs (old: {
            pname = "swiftc-headers";
            outputs = [ "out" ];
            dontBuild = true;

            installPhase = ''
              runHook preInstall

              staticLibExt=${stdenv.hostPlatform.extensions.staticLibrary}
              sharedLibExt=${stdenv.hostPlatform.extensions.sharedLibrary}

              stdlibLibPath=${lib.getLib stdlib}
              stdlibDevPath=${lib.getDev stdlib}
              stdlibIncPath=${lib.getInclude stdlib}

              swiftcLibPath=${lib.getLib swiftc}
              swiftcDevPath=${lib.getOutput "static" swiftc}
              swiftcIncPath=${lib.getInclude swiftc}

              swiftBinaryDir=${lib.getBin swiftc}
              swiftIncludeDirs=$swiftcIncPath/include\;$stdlibIncPath/lib\;$stdlibIncPath/include\;$out/include
              swiftLibraryDirs=$swiftcDevPath/lib\;$swiftcLibPath/lib\;$stdlibLibPath/lib\;$stdlibDevPath/lib

              swiftArch=${stdenv.hostPlatform.swift.arch}
              swiftPlatform=${stdenv.hostPlatform.swift.platform}

              buildDir=$NIX_BUILD_TOP/$sourceRoot/build
              buildType=''${cmakeBuildType:-Release}

              # Some headers reference headers from the source tree, so copy all of them.
              mkdir -p "$out"
              cp -rv include "$out" # For generated config headers.
              while IFS= read -d "" f; do
                dest=$out/''${f#../}
                mkdir -p "$(dirname "$dest")"
                cp -v "$f" "$dest"
              done < <(find .. \( -name '*.def' -o -name '*.h' \) -print0)

              # Copy the Swift CMake config but fix it up to point to the store instead of to the source folder.
              mkdir -p "$out/lib/cmake/modules"
              cp -rv lib/cmake/swift "$out/lib/cmake"

              # Clean up the config paths and drop the main source location (because it references the build folder).
              # The `find_package` is because our Swift builds against an external swift-cmark, which dependents
              # need to be able to find and use as well. Otherwise, they try to link liblibcmark-gfm, which is wrong.
              sed -i "$out/lib/cmake/swift/SwiftConfig.cmake" \
                -e '1i find_package(cmark-gfm)' \
                -e "2i set(SWIFT_STDLIB_DIR \"$stdlibLibPath/lib\")" \
                -e '/SWIFT_MAIN_SRC_DIR/d' \
                -e "/SWIFT_BINARY_DIR /c set(SWIFT_BINARY_DIR \"$swiftBinaryDir\")" \
                -e "/SWIFT_INCLUDE_DIR /c set(SWIFT_INCLUDE_DIR \"$swiftIncludeDirs\")" \
                -e "/SWIFT_INCLUDE_DIRS /c set(SWIFT_INCLUDE_DIRS \"$swiftIncludeDirs\")" \
                -e "/SWIFT_LIBRARY_DIR /c set(SWIFT_LIBRARY_DIR \"$swiftLibraryDirs\")" \
                -e "/SWIFT_LIBRARY_DIRS /c set(SWIFT_LIBRARY_DIRS \"$swiftLibraryDirs\")" \
                -e "/SWIFT_CMAKE_DIR /c set(SWIFT_CMAKE_DIR \"$out/lib/cmake/modules\")" \
                -e "/include(\"''${NIX_BUILD_TOP//\//\\\/}/c include(\"$out/lib/cmake/swift/SwiftExports.cmake\")"

              # Change exports to point to the locations in the store. This is a ugly because the exports could be in
              # one of several outputs belong to different derivations.
              sed -i "$out/lib/cmake/swift/SwiftExports.cmake" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/swift/$swiftPlatform/$swiftArch/\(.*$sharedLibExt\)\"|IMPORTED_LOCATION_''${buildType^^} \"$stdlibLibPath/lib/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/swift/$swiftPlatform/$swiftArch/\(.*$staticLibExt\)\"|IMPORTED_LOCATION_''${buildType^^} \"$stdlibDevPath/lib/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/\(swift-[^/]*\)/$swiftPlatform/$swiftArch/\([^/\"]*\)\"|IMPORTED_LOCATION_''${buildType^^} \"$stdlibLibPath/lib/\1/\2\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/swift/host/\(.*$sharedLibExt\)\"|IMPORTED_LOCATION_''${buildType^^} \"$swiftcLibPath/lib/swift/host/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/swift/host/\(.*$staticLibExt\)\"|IMPORTED_LOCATION_''${buildType^^} \"$swiftcDevPath/lib/swift/host/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/\(lib_Internal[^/\"]*\)\"|IMPORTED_LOCATION_''${buildType^^} \"$swiftcLibPath/lib/swift/host/compiler/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/\(.*$sharedLibExt\)\"|IMPORTED_LOCATION_''${buildType^^} \"$swiftcLibPath/lib/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/\(.*.framework/[^\"]*\)\"|IMPORTED_LOCATION_''${buildType^^} \"$swiftcLibPath/lib/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/lib/\(.*$staticLibExt\)\"|IMPORTED_LOCATION_''${buildType^^} \"$swiftcDevPath/lib/\1\"|g" \
                -e "s|IMPORTED_LOCATION_''${buildType^^} \"$buildDir/bin/\([^/\"]*\)\"|IMPORTED_LOCATION_''${buildType^^} \"swiftBinaryDir/bin/\1\"|g" \
                -e "s|IMPORTED_OBJECTS_''${buildType^^} \"$buildDir/.*/\([^/\"]*.o\)\"|IMPORTED_OBJECTS_''${buildType^^} \"$swiftcDevPath/lib\/\1\"|g" \
                -e "/INTERFACE_INCLUDE_DIRECTORIES/c INTERFACE_INCLUDE_DIRECTORIES \"$swiftIncludeDirs\"" \
                -e "/INTERFACE_LINK_DIRECTORIES/c INTERFACE_LINK_DIRECTORIES \"$swiftLibraryDirs\""

              # Copy SwiftAddCustomCommandTarget and its required support module (SwiftUtils), which is needed by LLDB.
              cp -v ../cmake/modules/SwiftUtils.cmake "$out/lib/cmake/modules/SwiftUtils.cmake"
              cp -v ../cmake/modules/SwiftAddCustomCommandTarget.cmake "$out/lib/cmake/modules/SwiftAddCustomCommandTarget.cmake"

              runHook postInstall
            '';
            postInstall = "";
          });

          swiftLLDB = prev.lldb.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              # The LLDB build on Linux assumes the rpath is set relative to the toolchain and that `SWIFT_LIBRARY_DIR`
              # consists of only one path (and is not a list). It needs to point to the stdlib.
              ./patches/lldb/0001-Set-stdlib-path-on-Linux.patch
              # Otherwise, linking `lldb-server` fails with a missing symbol error on Linux.
              ./patches/lldb/0002-Link-lldb-server-to-swiftCore.patch
              # Don’t resolve the liblldb symlink to help it find the Swift toolchain that it’s linked into.
              ./patches/lldb/0003-Don-t-follow-symlinks-when-finding-liblldb.patch
            ];
            buildInputs =
              (old.buildInputs or [ ])
              ++ [
                stdlib # The LLDB build system expects the stdlib libraries to be available on the default linker path.
              ]
              # For `swift_coroFrameAlloc`, which needs an SDK with libswiftCore text-based stubs that have the symbol.
              ++ lib.optionals stdenv.hostPlatform.isDarwin [ apple-sdk_26 ];
            # Swift’s fork of LLDB has extra requirements.
            nativeBuildInputs =
              (old.nativeBuildInputs or [ ])
              ++ [
                python3-with-distutils # distutils is needed for the bundled Python plugin.
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [
                darwin.sigtool # Required for code-signing.
                lld # Otherwise results in `can't find ordinal for imported symbol '_objc_opt_self'` when linking.
              ];
            # These aren’t set correctly otherwise. The LLDB build system needs an explicit Swift path regardless.
            cmakeFlags =
              (old.cmakeFlags or [ ])
              ++ [
                (lib.cmakeFeature "Clang_DIR" "${lib.getDev final.libclang}/lib/cmake/clang")
                (lib.cmakeFeature "LLVM_DIR" "${lib.getDev final.libllvm}/lib/cmake/llvm")
                (lib.cmakeFeature "Swift_DIR" "${swiftHeaders}")
                (lib.cmakeFeature "cmark-gfm_DIR" "${swift-cmark.out}/lib/cmake")
                (lib.cmakeFeature "LLDB_SWIFT_LIBS" "${lib.getDev stdlib}/lib/swift")
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [
                (lib.cmakeFeature "CMAKE_LINKER_TYPE" "LLD")
              ];

            # Make sure LLDB can find the Swift compiler shared libraries.
            postInstall =
              (old.postInstall or "")
              + lib.optionalString stdenv.hostPlatform.isElf ''
                for output in $outputs; do
                  while IFS= read -d "" f; do
                    if isELF "$f"; then
                      # Make sure all rpaths are present. Why is libuuid getting dropped? I have no idea.
                      patchelf --add-rpath ${
                        lib.escapeShellArg (lib.makeSearchPathOutput "out" "lib/swift/host/compiler" [ swiftc ])
                      } "$f" || true
                      patchelf --add-rpath ${lib.escapeShellArg (lib.makeLibraryPath [ libuuid ])} "$f" || true
                    fi
                  done < <(find "''${!output}" -type f -print0)
                done
              '';
          });
        in
        # Linux tries to use a GCC stdenv to build LLDB, but the Swift headers aren’t compatible with GCC.
        # The stdenv passed in from the package set arguments is the Clang-based stdenv from `swift-packages.nix`.
        swiftLLDB.override { inherit stdenv; };

      libllvm =
        let
          # The Swift build system expects to link statically against LLVM. Trying to link to the `libLLVM` shared
          # library causes `swift-frontend` to crash during the build on Linux.
          staticLibllvm = prev.libllvm.override { enableSharedLibraries = false; };
        in
        staticLibllvm.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            # Ensure the LLVM module cache is in a writable location during builds.
            ./patches/llvm/module-cache.patch
          ];
          doCheck = false; # TODO: fix fork-specific tests that fail due to, e.g., not finding `libLLVM.dylib` during the test
          postInstall = (old.postInstall or [ ]) + ''
            # Swift relies on LLVM’s private `config.h` for feature checks (e.g., for `unistd.h`).
            cp include/llvm/Config/config.h "$dev/include/llvm/Config/config.h"
          '';
        });
    }
  )
