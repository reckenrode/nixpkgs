{
  lib,
  apple-sdk_14,
  apple-sdk_15,
  bootSwift,
  buildPackages,
  callPackage,
  cctools,
  cmake,
  darwin,
  fetchFromGitHub,
  fetchpatch2,
  libedit,
  libffi,
  libxml2,
  llvmPackages,
  ninja,
  perl,
  python3Packages,
  replaceVars,
  stdenv,
  swift-cmark,
  swift-corelibs-libdispatch,
  xcbuild,
  xctest,
  zlib,
  version_src,
  enableBuildingSwiftWithSwift ? true,
  enableSwiftDriver ? enableBuildingSwiftWithSwift,
}:

let
  inherit (darwin) sigtool;

  inherit (llvmPackages)
    clang
    libclang
    llvm
    libllvm
    ;

  apple-sdk =
    if
      lib.versionOlder version_src.swift.version "6.0"
      # Building Swift 6 with the 15.x SDK requires a newer Clang resource dir than the one Swift 5.10.1 has.
      # Otherwise, it fails due to the incomplete module map for the C standard library.
      || lib.versionOlder (lib.getVersion bootSwift) "6.0"
    then
      apple-sdk_14
    else
      apple-sdk_15;

  swiftTriple =
    lib.replaceStrings [ "darwin" ] [ "macosx${stdenv.hostPlatform.darwinMinVersion}" ]
      stdenv.hostPlatform.config;

  python3 = python3Packages.python.withPackages (p: [ p.setuptools ]); # python 3.12 compat.

  buildSwiftDriver = callPackage ./swift-driver {
    xctest = xctest.override {
      swift = bootSwift;
    };
  };
in
stdenv.mkDerivation (
  lib.extends (if enableSwiftDriver then buildSwiftDriver else _: _: { }) (finalAttrs: {
    pname = "swift" + lib.optionalString (!(enableBuildingSwiftWithSwift && enableSwiftDriver)) "-boot";
    inherit (version_src.swift) version;

    outputs = [
      "out"
      "lib"
      "dev"
      "doc"
      "man"
    ];

    srcs =
      map
        (
          name:
          fetchFromGitHub {
            inherit name;
            inherit (version_src.${name})
              owner
              repo
              tag
              hash
              ;
          }
        )
        (
          [ "swift" ]
          ++ lib.optionals enableBuildingSwiftWithSwift [
            "swift-experimental-string-processing"
            "swift-syntax"
          ]
        );

    sourceRoot = "swift";

    prePatch = ''
      # Setting `patchFlags` in the derivation won’t work because `-d` needs to be an absolute path.
      patchFlags=("-d" "$NIX_BUILD_TOP" "-p1")

      # Make sure all Swift sources can be patched.
      chmod u+w -R "$NIX_BUILD_TOP/swift"*
    '';

    patches =
      let
        swiftMajor = lib.versions.major finalAttrs.version;
      in
      [
        # Find the location of libc++ from `nix-support` instead of probing for it.
        ./patches/${swiftMajor}/cmake-libcxx-flags.patch
        # Backport linking against an external swift-cmark.
        # From https://github.com/swiftlang/swift/pull/70791.
        ./patches/${swiftMajor}/cmark-build-revamp.patch
        # Patch paths to use the separate 'lib' output.
        # Link against libdispatch in nixpkgs instead of building it in-tree
        ./patches/${swiftMajor}/libdispatch-cmake.patch
        ./patches/${swiftMajor}/separate-lib.patch
        # Fix compilation errors when building the SIL moduel during bootstrap.
        # error: field has incomplete type 'clang::DeclContext::all_lookups_iterator'
        # error: field has incomplete type 'clang::DeclContext::ddiag_iterator'
        ./patches/${swiftMajor}/sil-missing-headers.patch
        # ClangImporter needs help finding the location of libc++.
        ./patches/clang-importer-libcxx.patch
        # Use libLTO.dylib from the LLVM built for Swift
        (replaceVars ./patches/specify-liblto-path.patch {
          libllvm_path = lib.getLib libllvm;
        })
      ]
      ++ lib.optionals (lib.versionOlder finalAttrs.version "6.0") (
        [
          # Fixes a crash when building Swift with C++ interop enabled.
          # See: https://github.com/swiftlang/swift/pull/70549
          (fetchpatch2 {
            url = "https://github.com/swiftlang/swift/commit/14cfebc64002dd9faad3587acbe3d95f7477991e.diff?full_index=1";
            extraPrefix = "swift/";
            stripLen = 1;
            hash = "sha256-0vttONzFfcsJ9TC6j19Fhq89ZJtoSGtQBZoiYuJ1sB0=";
          })
          # Fixes C++ interop build failures when using newer libc++ versions with reorganized `module.modulemap`.
          # See: https://github.com/swiftlang/swift/pull/71813
          (fetchpatch2 {
            url = "https://github.com/swiftlang/swift/commit/9147522506a5ca826467e3a7e031492e5b36988a.diff?full_index=1";
            extraPrefix = "swift/";
            stripLen = 1;
            hash = "sha256-ucCLZZnYa/JdG5ke6FKREi1WdJ+/IsoklYha5eEZTzs=";
          })
        ]
        ++ lib.optionals enableBuildingSwiftWithSwift [
          # Without this patch, Swift Syntax fails to emit private interfaces that are expected by the installation target.
          # See: https://github.com/swiftlang/swift-syntax/pull/2413
          (fetchpatch2 {
            url = "https://github.com/swiftlang/swift-syntax/commit/766a260dfd78197db0a4692bb8d7537e8d9d7d3b.diff?full_index=1";
            extraPrefix = "swift-syntax/";
            stripLen = 1;
            hash = "sha256-Yw8CUBO/A3uIGcBgVoyDq/De0WL68vFm0ZRXzPmkx3k=";
          })
        ]
      );

    postPatch =
      ''
        # Need to reference $lib, so this can’t be substituted by `replaceVars`.
        substituteInPlace lib/Frontend/CompilerInvocation.cpp \
          --replace-fail '@lib@' "''${!outputLib}" \
          --replace-fail '@storeDir@' ${lib.escapeShellArg builtins.storeDir}

        # Only build the runtime for the target architecture. Universal builds aren’t really supported in nixpkgs,
        # and the dylibs in the SDK aren’t built as universal. Use `grep` to assert the change was made.
        sed -i cmake/modules/SwiftConfigureSDK.cmake \
          -e 's/^\( *\)remove_sdk_unsupported_archs(.*$/\1set(SWIFT_SDK_''${prefix}_ARCHITECTURES "${stdenv.targetPlatform.darwinArch}")/'
        grep -q 'set(SWIFT_SDK_''${prefix}_ARCHITECTURES "${stdenv.targetPlatform.darwinArch}")' cmake/modules/SwiftConfigureSDK.cmake

        # Swift doesn’t really _need_ LLVM’s build folder. It only needs to find a built LLVM, which we can provide.
        substituteInPlace cmake/modules/SwiftSharedCMakeConfig.cmake \
          --replace-fail "precondition_translate_flag(LLVM_BUILD_LIBRARY_DIR LLVM_LIBRARY_DIR)" ""

        # Fix the path to LLVM’s CMake modules.
        substituteInPlace lib/Basic/CMakeLists.txt \
          --replace-fail \''${LLVM_MAIN_SRC_DIR}/cmake/modules ${lib.escapeShellArg (lib.getDev libllvm)}/lib/cmake/llvm

        # Find `features.json` in Clang’s $out not LLVM’s.
        substituteInPlace lib/Option/CMakeLists.txt \
          --replace-fail \''${LLVM_BINARY_DIR} ${lib.escapeShellArg (lib.getBin libclang)}

      # Make sure Swift can find Clang’s resource dir during the build.
      substituteInPlace stdlib/public/SwiftShims/swift/shims/CMakeLists.txt \
        --replace-fail \
          'set(clang_headers_location "''${LLVM_LIBRARY_OUTPUT_INTDIR}/clang/''${CLANG_VERSION${lib.optionalString (lib.versionAtLeast finalAttrs.version "6.0") "_MAJOR"}}")' \
          'set(clang_headers_location "${lib.getBin clang}/resource-root")'
    '';

    dontFixCmake = true;

    cmakeFlags =
      [
        # The documentation suggests this is the default, but it appears to default to off.
        (lib.cmakeFeature "BOOTSTRAPPING_MODE" (if bootSwift == null then "OFF" else "HOSTTOOLS")) # "BOOTSTRAPPING${lib.optionalString stdenv.hostPlatform.isDarwin "-WITH-HOSTLIBS"}")
        # Build Swift with LTO for better performance.
        (lib.cmakeFeature "SWIFT_TOOLS_ENABLE_LTO" "full")
        (lib.cmakeFeature "SWIFT_STDLIB_ENABLE_LTO" "full")
        # Swift installs its dylibs to `$lib/lib/swift/host` instead of `$lib/lib`.
        (lib.cmakeFeature "CMAKE_INSTALL_NAME_DIR" "${placeholder "lib"}/lib/swift/host")
        # Make Swift use Clang from nixpkgs instead of building its own.
        (lib.cmakeBool "SWIFT_PREBUILT_CLANG" true)
        (lib.cmakeFeature "SWIFT_NATIVE_CLANG_TOOLS_PATH" "${lib.getBin clang}/bin")
        (lib.cmakeFeature "SWIFT_NATIVE_LLVM_TOOLS_PATH" "${lib.getBin llvm}/bin")
        # Swift expects to find these relative to `$src`, but it only actually needs their final build products.
        # Instead of being built in the Swift derivation, they’re built separately. This tells CMake how to find them.
        (lib.cmakeFeature "Clang_DIR" "${lib.getDev libclang}/lib/cmake/clang")
        (lib.cmakeFeature "LLVM_DIR" "${lib.getDev libllvm}/lib/cmake/llvm")
        (lib.cmakeFeature "cmark-gfm_DIR" "${lib.getDev swift-cmark}/lib/cmake")
        # Swift defaults to 10.13, which is too old. Set the deployment target to the minimum supported in nixpkgs.
        (lib.cmakeFeature "SWIFT_DARWIN_DEPLOYMENT_VERSION_OSX" stdenv.hostPlatform.darwinMinVersion)
        (lib.cmakeFeature "SWIFT_HOST_TRIPLE" swiftTriple)
        # Enable Swift Concurrency even the basic, bootstrap compiler. Otherwise, it generates a ton of warnings.
        (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY" true)
      ]
      ++ lib.optionals enableBuildingSwiftWithSwift (
        [
          (lib.cmakeBool "SWIFT_BUILD_SWIFT_SYNTAX" true)
          (lib.cmakeBool "SWIFT_ENABLE_BACKTRACING" true)
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_CXX_INTEROP" true)
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING" true)
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED" true)
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_OBSERVATION" true)
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_PARSER_VALIDATION" true)
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING" true)
        ]
        ++ lib.optionals (lib.versionAtLeast finalAttrs.version "6.1") [
          (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_POINTER_BOUNDS" true)
          (lib.cmakeBool "SWIFT_ENABLE_SYNCHRONIZATION" true)
          (lib.cmakeBool "SWIFT_ENABLE_VOLATILE" true)
        ]
      );

    # Swift uses `<arch>-apple.macosx` triples instead of `<arch>-apple-darwin`, which causes tons of warnings.
    env.NIX_CC_WRAPPER_SUPPRESS_TARGET_WARNING = true;

    preConfigure =
      if enableBuildingSwiftWithSwift then
        ''
          appendToVar cmakeFlags "-DSWIFT_PATH_TO_STRING_PROCESSING_SOURCE:PATH=$NIX_BUILD_TOP/swift-experimental-string-processing"
          appendToVar cmakeFlags "-DSWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE:PATH=$NIX_BUILD_TOP/swift-syntax"
        ''
      else
        null;

    strictDeps = true;

    nativeBuildInputs =
      [
        cmake
        ninja
        perl # For pod2man
        python3
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        cctools.libtool
        sigtool
        xcbuild
      ]
      ++ lib.optionals (bootSwift != null) [ bootSwift ];

    buildInputs =
      [
        libedit
        libffi
        libllvm
        libxml2
        swift-cmark
        zlib
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [ apple-sdk ]
      ++ lib.optionals (lib.meta.availableOn stdenv.hostPlatform swift-corelibs-libdispatch) [
        (swift-corelibs-libdispatch.override { useSwift = false; })
      ];

    ninjaFlags = [
      "all"
      "swift-syntax-lib" # `swift-syntax-lib` doesn’t seem to be included in the `all` target in Swift 6.1.
    ];

    doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

    postInstall =
      ''
        # Separate $lib output here, because specific logic follows.
        # Only move the dynamic run-time parts, to keep $lib small. Every Swift build will depend on it.
        moveToOutput "lib/swift" "''${!outputLib}"
        moveToOutput "lib/libswiftDemangle.*" "''${!outputLib}"

        # This link is here because various tools (SwiftPM) check for stdlib relative to the swift compiler.
        # It’s fine if this is for build-time stuff, but we should patch all cases were it would end up in an output.
        ln -s "''${!outputLib}/lib/swift" "$out/lib/swift"

        # Swift has a separate resource root from Clang, but locates the Clang
        # resource root via subdir or symlink.
        #
        # NOTE: We don't symlink directly here, because that'd add a run-time dep
        # on the full Clang compiler to every Swift executable. The copy here is
        # just copying the 3 symlinks inside to smaller closures.
        mkdir -p "''${!outputLib}/lib/swift/clang"
        cp -P ${lib.escapeShellArg (lib.getBin clang)}/resource-root/* "''${!outputLib}/lib/swift/clang/"
      ''
      # Swift 6 installs private Swift Syntax dylibs to $lib/lib/swift/host/compiler, which `CMAKE_INSTALL_NAME_DIR`
      # mangles to the wrong paths.
      +
        lib.optionalString (stdenv.hostPlatform.isDarwin && lib.versionAtLeast finalAttrs.version "6.0")
          ''
            # Fix up the install names of all the dylibs generated by the build process. fixupDarwinDylibNames doesn’t work.
            while IFS= read -d "" dylib; do
              dylib_name=$(basename "$dylib")
              echo "$dylib: fixing dylib"
              install_name_tool "$dylib" -id "$dylib"
            done < <(find "''${!outputLib}/lib/swift/host/compiler" -name '*.dylib' -print0)
            readarray -t -d "" args < <(
              find "''${!outputLib}/lib/swift/host/compiler" -name '*.dylib' \
                -printf "-change\0''${!outputLib}/lib/swift/host/%f\0%p\0"
            )
            for output in out lib; do
              while IFS= read -d "" exe; do
                if [[ "$exe" != *.a ]] && LC_ALL=C isMachO "$exe"; then
                  res=$(install_name_tool "$exe" "''${args[@]}" 2>&1)
                  if [[ "$res" =~ invalidate ]]; then codesign -s - -f "$exe"; fi
                fi
              done < <(find "''${!output}" -type f -print0)
            done
          '';

    # Will effectively be `buildInputs` when swift is put in `nativeBuildInputs`.
    depsTargetTargetPropagated = lib.optionals stdenv.targetPlatform.isDarwin [ apple-sdk ];

    __structuredAttrs = true;

    passthru.swiftPlatform =
      if stdenv.targetPlatform.isDarwin then
        "macosx"
      else if stdenv.targetPlatform.isLinux then
        "linux"
      else if stdenv.targetPlatform.isWindows then
        "windows"
      else
        lib.throw "unsupported platform";

    meta = {
      description = "Swift Programming Language";
      homepage = "https://github.com/swiftlang/swift";
      platforms = lib.platforms.darwin ++ lib.platforms.linux ++ lib.platforms.windows;
      badPlatforms = [ lib.systems.inspect.patterns.is32bit ];
      license = lib.licenses.asl20;
      teams = [ lib.teams.swift ];
    };
  })
)
