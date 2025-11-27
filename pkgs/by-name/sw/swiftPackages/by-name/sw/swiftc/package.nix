{
  lib,
  apple-sdk_14,
  apple-sdk_26,
  cmake,
  darwin,
  fetchFromGitHub,
  fetchpatch2,
  libedit,
  llvm_libtool,
  libffi,
  libuuid,
  libxml2,
  llvmPackages,
  ninja_1_11,
  perl,
  python3,
  replaceVars,
  stdenv,
  stdlib,
  swift-cmark,
  swift-corelibs-libdispatch,
  swift-syntax,
  swift_release,
  swift-bootstrap ? null,
  xcbuild,
  srcOnly,
  xz,
  zlib,
  zstd,

  # This matches _SWIFT_DEFAULT_COMPONENTS, with specific components disabled.
  swiftComponents ? [
    "autolink-driver"
    #    "clang-builtin-headers"
    #    "clang-resource-dir-symlink"
    "compiler"
    "compiler-swift-syntax-lib"
    #    "dev"
    "editor-integration"
    #    "llvm-toolchain-dev-tools"
    "license"
    "sdk-overlay"
    (if stdenv.hostPlatform.isDarwin then "sourcekit-xpc-service" else "sourcekit-inproc")
    #    "stdlib-experimental"
    "swift-syntax-lib"
    #    "testsuite-tools"
    "toolchain-dev-tools"
    "toolchain-tools"
    #    "tools"
  ]
  ++ lib.optionals (stdlib == null) [
    "back-deployment"
    "sdk-overlay"
    "static-mirror-lib"
    "stdlib"
    "swift-remote-mirror"
    "swift-remote-mirror-headers"
  ],
}@args:

let
  getBuildHost = lib.mapAttrs (_: pkg: pkg.__spliced.buildHost or pkg);
  getHostTarget = lib.mapAttrs (_: pkg: pkg.__spliced.hostTarget or pkg);

  # SDK versions past 14.x don’t work with the c++-based bootstrap compiler due to unconditionally exposing macros.
  apple-sdk = if bootstrapStage == 2 then apple-sdk_26 else apple-sdk_14;
  # These are different because the 14.4 SDK is only good enough for building Swift. Using it when building other
  # packages good enough for building Swift usually results in `swift-frontend` crashes.
  propagated-sdk = if bootstrapStage > 0 then apple-sdk_26 else apple-sdk_14;

  buildHostPackages = getBuildHost args;
  hostTargetPackages = getHostTarget args;

  swift-driver = swift-bootstrap.swift-driver or null;

  inherit (buildHostPackages.llvmPackages)
    clang
    clang-unwrapped
    llvm
    ;

  inherit (hostTargetPackages)
    stdlib

    swift-cmark
    swift-corelibs-libdispatch

    xz
    zlib
    zstd
    ;

  inherit (hostTargetPackages.llvmPackages)
    libclang
    libllvm
    ;

  # https://github.com/NixOS/nixpkgs/issues/327836
  # Fail to build with ninja 1.12 when NIX_BUILD_CORES is low (Hydra or Github Actions).
  # Can reproduce using `nix --option cores 2 build -f . swiftPackages.swift-unwrapped`.
  # Until we find out the exact cause, follow [swift upstream][1], pin ninja to version
  # 1.11.1.
  # [1]: https://github.com/swiftlang/swift/pull/72989
  ninja = ninja_1_11;

  inherit (darwin) sigtool;

  # Swift requires three bootstrap stages (in addition to the bootstrapping it does on its own).
  # - Stage 0 builds a minimal Swift compiler using only C++.
  # - Stage 1 builds a Swift compiler using the stage 0 Swift compiler. Features needed to build macros are enabled.
  # - Stage 2 builds a full Swift compiler using the stage 1 compiler.
  bootstrapStage =
    if swift-bootstrap == null then
      0
    else if lib.hasSuffix "cxx_bootstrap" (lib.getName swift-bootstrap) then
      1
    else
      2;

  doCheck = bootstrapStage > 0;

  dylibExt = stdenv.hostPlatform.extensions.sharedLibrary;

  isNotSwiftSyntax = if bootstrapStage == 0 then c: !lib.hasInfix "swift-syntax" c else _: true;

  swiftComponents' = lib.filter isNotSwiftSyntax swiftComponents;

  swiftPlatform = stdenv.hostPlatform.swift.platform;

  swift-experimental-string-processing = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-experimental-string-processing";
    tag = "swift-${swift_release}-RELEASE";
    hash = "sha256-WtLLqdvYTmLWSS5q42b8yXFrJcC+dUy4uTuCeIflRFs=";
  };

  swift-syntax = srcOnly {
    inherit (hostTargetPackages.swift-syntax)
      name
      version
      src
      patches
      stdenv
      ;
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname =
    "swiftc"
    + lib.optionalString (bootstrapStage == 0) "-cxx_bootstrap"
    + lib.optionalString (bootstrapStage == 1) "-bootstrap";
  version = swift_release;

  outputs = [
    "out"
    #    "lib"
    "dev"
    "doc"
    "man"
  ];

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift";
    tag = "swift-${swift_release}-RELEASE";
    hash = "sha256-apbBe/TMzq0+1XLkaTOj5NaYzLQ81i+vU+O7VSEJrKo=";
  };

  postUnpack = lib.optionalString (bootstrapStage >= 1) ''
    ln -s ${lib.escapeShellArg swift-experimental-string-processing} "$NIX_BUILD_TOP/swift-experimental-string-processing"
    ln -s ${lib.escapeShellArg swift-syntax} "$NIX_BUILD_TOP/swift-syntax"
  '';

  patches = [
    # ClangImporter needs help finding the location of libc++.
    ./patches/0001-clang-importer-libcxx.patch
    # Find the location of libc++ from `nix-support` instead of probing for it.
    ./patches/0002-cmake-libcxx-flags.patch
    # Backport linking against an external swift-cmark.
    # From https://github.com/swiftlang/swift/pull/70791.
    ./patches/0003-cmark-build-revamp.patch
    # ClangImporter needs help dealing with separate glibc and libstdc++ paths on Linux.
    ./patches/0004-linux-fix-libc-paths.patch
    # Resolve any symlinks when adding rpaths. This is helpful to avoid pulling in the whole Swift closure when only
    # the stdlib is needed.
    ./patches/0005-resolve-rpath-symlinks.patch
    # Fix compilation errors when building the SIL module during bootstrap.
    # error: field has incomplete type 'clang::DeclContext::all_lookups_iterator'
    # error: field has incomplete type 'clang::DeclContext::ddiag_iterator'
    ./patches/0006-sil-missing-headers.patch
    # Use libLTO.dylib from the LLVM built for Swift
    (replaceVars ./patches/0007-specify-liblto-path.patch {
      libllvm_path = lib.getLib libllvm;
    })
    # Use libdispatch from nixpkgs instead of building it in-tree
    ./patches/0010-use-nixpkgs-libdispatch.patch
    # Fix missing <cstdint> when building against libstdc++ 15
    (fetchpatch2 {
      url = "https://github.com/swiftlang/swift/commit/a5c727125e952839c373fe47e9f9e359db3d4d38.patch";
      hash = "sha256-004zzB93Kr/kghQCxJ9gFDkWksvtML0ZDsV9d+tEKq0=";
    })
  ]
  ++ lib.optionals (bootstrapStage < 2) [
    # Revert optimizer changes that cause the C++-based bootstrap compiler to be unable to compile functions with
    # infinite loops that return from the loop. This doesn’t affect the later stages, so it’s applied conditionally.
    # https://github.com/swiftlang/swift/pull/79186
    ./patches/0008-revert-optimizer-changes.patch
    # Work around a compiler crash by partially reverting https://github.com/swiftlang/swift/pull/80920.
    ./patches/0009-siloptimizer-bootstrap-workaround.patch
  ];

  postPatch = ''
    # Need to reference $lib, so this can’t be substituted by `replaceVars`. The bootstrap compilers use their own
    # stdlib, but the final compiler uses the separately built one.
    # substituteInPlace lib/Frontend/CompilerInvocation.cpp \
    #   --replace-fail '@lib@' ${if stdlib != null then lib.getLib stdlib else ''"''${!outputLib}"''}

    # Swift doesn’t really _need_ LLVM’s build folder. It only needs to find a built LLVM, which we can provide.
    substituteInPlace cmake/modules/SwiftSharedCMakeConfig.cmake \
      --replace-fail "precondition_translate_flag(LLVM_BUILD_LIBRARY_DIR LLVM_LIBRARY_DIR)" ""

    # Fix the path to LLVM’s CMake modules.
    substituteInPlace lib/Basic/CMakeLists.txt \
      --replace-fail \''${LLVM_MAIN_SRC_DIR}/cmake/modules ${lib.escapeShellArg (lib.getDev libllvm)}/lib/cmake/llvm

    # Find `features.json` in Clang’s $out not LLVM’s.
    substituteInPlace lib/Option/CMakeLists.txt \
      --replace-fail \''${LLVM_BINARY_DIR} ${lib.escapeShellArg (lib.getBin clang-unwrapped)}

    # Make sure Swift can find Clang’s resource dir during the build.
    substituteInPlace stdlib/public/SwiftShims/swift/shims/CMakeLists.txt \
      --replace-fail \
        'set(clang_headers_location "''${LLVM_LIBRARY_OUTPUT_INTDIR}/clang/''${CLANG_VERSION${lib.optionalString (lib.versionAtLeast finalAttrs.version "6.0") "_MAJOR"}}")' \
        'set(clang_headers_location "${lib.getBin clang}/resource-root")'

    # Use absolute path references for `dlopen`.
    substituteInPlace stdlib/public/RuntimeModule/Compression.swift \
      --replace-fail liblzma${dylibExt} ${lib.escapeShellArg (lib.getLib xz)}/lib/liblzma${dylibExt} \
      --replace-fail libz${dylibExt} ${lib.escapeShellArg (lib.getLib zlib)}/lib/libz${dylibExt} \
      --replace-fail libzstd${dylibExt} ${lib.escapeShellArg (lib.getLib zstd)}/lib/libzstd${dylibExt}

    # Make sure Swift uses the external macro plugin server built with the compiler.
    substituteInPlace lib/Driver/DarwinToolChains.cpp \
      --replace-fail 'basePath, "usr", "bin", "swift-plugin-server"' "\"$out/bin/swift-plugin-server\""
  ''
  + lib.optionalString stdenv.targetPlatform.isDarwin ''
    # Swift sets the deployment target to 10.9 for some components, but nixpkgs only supports newer ones.
    # Overriding it eliminates errors due to -Wunguarded-availability.
    # substituteInPlace CMakeLists.txt \
    #   --replace-fail 'COMPATIBILITY_MINIMUM_DEPLOYMENT_VERSION_OSX "10.9"' 'COMPATIBILITY_MINIMUM_DEPLOYMENT_VERSION_OSX "${stdenv.targetPlatform.darwinMinVersion}"'

    # Only build the runtime for the target architecture. Universal builds aren’t really supported in nixpkgs,
    # and the dylibs in the SDK aren’t built as universal. Use `grep` to assert the change was made.
    sed -i cmake/modules/SwiftConfigureSDK.cmake \
      -e 's/^\( *\)remove_sdk_unsupported_archs(.*$/\1set(SWIFT_SDK_''${prefix}_ARCHITECTURES "${stdenv.targetPlatform.darwinArch}")/'
    grep -q 'set(SWIFT_SDK_''${prefix}_ARCHITECTURES "${stdenv.targetPlatform.darwinArch}")' cmake/modules/SwiftConfigureSDK.cmake
  '';

  dontFixCmake = true;

  cmakeFlags = [
    (lib.cmakeFeature "BOOTSTRAPPING_MODE" "HOSTTOOLS") # "BOOTSTRAPPING${lib.optionalString stdenv.hostPlatform.isDarwin "-WITH-HOSTLIBS"}")
    (lib.cmakeOptionType "list" "SWIFT_INSTALL_COMPONENTS" (lib.concatStringsSep ";" swiftComponents'))
    # Needs to be disabled in stage 0 to enable the C++ bootstrap.
    (lib.cmakeBool "SWIFT_ENABLE_SWIFT_IN_SWIFT" (bootstrapStage > 0))
    # Swift installs its dylibs to `$lib/lib/swift/host` instead of `$lib/lib`.
    (lib.cmakeFeature "CMAKE_INSTALL_NAME_DIR" "${placeholder "out"}/lib/swift/host")
    # Make Swift use Clang from nixpkgs instead of building its own.
    (lib.cmakeBool "SWIFT_PREBUILT_CLANG" true)
    (lib.cmakeFeature "SWIFT_NATIVE_CLANG_TOOLS_PATH" "${lib.getBin clang}/bin")
    (lib.cmakeFeature "SWIFT_NATIVE_LLVM_TOOLS_PATH" "${lib.getBin llvm}/bin")
    # Swift expects to find these relative to `$src`, but it only actually needs their final build products.
    # Instead of being built in the Swift derivation, they’re built separately. This tells CMake how to find them.
    (lib.cmakeFeature "Clang_DIR" "${lib.getDev libclang}/lib/cmake/clang")
    (lib.cmakeFeature "LLVM_DIR" "${lib.getDev libllvm}/lib/cmake/llvm")
    (lib.cmakeFeature "cmark-gfm_DIR" "${swift-cmark.out}/lib/cmake")
    # Swift defaults to 10.13, which is too old. Set the deployment target to the minimum supported in nixpkgs.
    (lib.cmakeFeature "SWIFT_DARWIN_DEPLOYMENT_VERSION_OSX" stdenv.hostPlatform.darwinMinVersion)
    (lib.cmakeFeature "SWIFT_HOST_TRIPLE" stdenv.hostPlatform.swift.triple)
    # Tests should only be built when building a regular compiler. The bootstrap compiler is not functional enough.
    (lib.cmakeBool "SWIFT_INCLUDE_TESTS" (doCheck && bootstrapStage != 2))
  ]
  ++ lib.optionals (bootstrapStage == 1) [
    # Work around crashes in ownership verifier in the bootstrap compiler.
    # See https://github.com/swiftlang/swift/issues/84552#issuecomment-3409245634
    "-DCMAKE_Swift_FLAGS=-Xfrontend -disable-sil-ownership-verifier"
  ]
  ++ lib.optionals (bootstrapStage >= 1) [
    # These features are needed for the final build due to using unguarded macros in the SDK required to build it.
    (lib.cmakeBool "SWIFT_BUILD_SWIFT_SYNTAX" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_OBSERVATION" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING" true)
  ]
  ++ lib.optionals (bootstrapStage >= 2) [
    # Build Swift with LTO for better performance. Thin LTO is used instead of full LTO because full LTO is too slow.
    #    (lib.cmakeFeature "SWIFT_TOOLS_ENABLE_LTO" "thin")
    #    (lib.cmakeFeature "SWIFT_STDLIB_ENABLE_LTO" "thin")
    # Enable the remaining features
    (lib.cmakeBool "SWIFT_ENABLE_BACKTRACING" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_CXX_INTEROP" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_PARSER_VALIDATION" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_POINTER_BOUNDS" true)
    (lib.cmakeBool "SWIFT_ENABLE_EXPERIMENTAL_RUNTIME_MODULE" true)
    (lib.cmakeBool "SWIFT_ENABLE_SYNCHRONIZATION" true)
    (lib.cmakeBool "SWIFT_ENABLE_VOLATILE" true)
    (lib.cmakeBool "SWIFT_ENABLE_RUNTIME_MODULE" true)
    (lib.cmakeBool "SWIFT_STDLIB_ENABLE_STRICT_AVAILABILITY" true)
  ];

  env = {
    # Swift uses `<arch>-apple.macosx` triples instead of `<arch>-apple-darwin`, which causes tons of warnings.
    NIX_CC_WRAPPER_SUPPRESS_TARGET_WARNING = true;
    # Swift compiles some of its stdlib for older deployment targets.
    NIX_CFLAGS_COMPILE = "-Wno-error=unguarded-availability";
  };

  preConfigure =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      # `env.NIX_LDFLAGS` can’t be done conditionally because all obvious conditions cause infinite recursions.
      if [ $NIX_APPLE_SDK_VERSION -lt 260000 ]; then
        # Swift 6.2 needs to weakly link against `swift_coroFrameAlloc`, which is only in the 26.0 SDK.
        # Unfortunately, the 26.0 SDK uses unguarded macros, so the C++ bootstrap compiler has to use the 14.4 SDK.
        NIX_LDFLAGS+=" -undefined dynamic_lookup"
      fi
    ''
    + lib.optionalString (swift-driver != null) ''
      appendToVar cmakeFlags "-DSWIFT_EARLY_SWIFT_DRIVER_BUILD:PATH=${lib.escapeShellArg (lib.getBin swift-driver)}/bin"
    ''
    + lib.optionalString (bootstrapStage >= 1) ''
      appendToVar cmakeFlags "-DSWIFT_PATH_TO_STRING_PROCESSING_SOURCE:PATH=$NIX_BUILD_TOP/swift-experimental-string-processing"
      appendToVar cmakeFlags "-DSWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE:PATH=$NIX_BUILD_TOP/swift-syntax"
    '';

  #  postConfigure =
  #    # Link the final compiler against the separate stdlib instead of building it with the compiler.
  #    lib.optionalString (stdlib != null) ''
  #      stdlibDir=lib/swift/${stdenv.hostPlatform.swift.platform}
  #      mkdir -p "$stdlibDir"
  #      for dylib in ${lib.escapeShellArg (lib.getLib stdlib)}/lib/*; do
  #        ln -s "$dylib" "$stdlibDir/$(basename "$dylib")"
  #      done
  #
  #      for module in ${lib.escapeShellArg (lib.getDev stdlib)}/lib/swift/${stdenv.hostPlatform.swift.platform}/*; do
  #        ln -s "$module" "$stdlibDir/$(basename "$module")"
  #      done
  #    '';

  strictDeps = true;

  ninjaFlags = swiftComponents';
  #  ninjaFlags = lib.optionals (bootstrapStage >= 1) [
  #    "all"
  #    "swift-syntax-lib" # `swift-syntax-lib` doesn’t seem to be included in the `all` target for some reason.
  #  ];

  nativeBuildInputs = [
    cmake
    ninja
    perl # For pod2man
    python3
    swift-bootstrap
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    llvm_libtool
    sigtool
    xcbuild
  ];

  buildInputs = [
    libedit
    libffi
    libllvm
    libxml2
    swift-cmark.out
    zlib
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ apple-sdk ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    libuuid
    (swift-corelibs-libdispatch.override { useSwift = false; })
  ];

  inherit doCheck;

  postInstall = ''
    # Swift has a separate resource root from Clang, but locates the Clang
    # resource root via subdir or symlink.
    #
    # NOTE: We don't symlink directly here, because that'd add a run-time dep
    # on the full Clang compiler to every Swift executable. The copy here is
    # just copying the 3 symlinks inside to smaller closures.
    mkdir -p "''${!outputLib}/lib/swift/clang"
    cp -P ${lib.escapeShellArg (lib.getBin clang)}/resource-root/* "''${!outputLib}/lib/swift/clang/"

    # Swift 6 installs private Swift Syntax dylibs to $lib/lib/swift/host/compiler, which `CMAKE_INSTALL_NAME_DIR`
    # mangles to the wrong paths.
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
  ''
  # Swift installs some back-deployment and stdlib components as part of the compiler component. Delete them.
  + lib.optionalString (stdlib != null) ''
    rm -rf "''${!outputLib}/lib/swift/${swiftPlatform}"
    rm -rf "''${!outputLib}/lib/swift-6.2"
    rm -rf "''${!outputLib}/lib/swift_static"
  ''
  # Remove early Swift Driver from `$out/bin`. It will be supplied by the `swift` derivation.
  + lib.optionalString (swift-driver != null) ''
    declare -a swiftDriverFiles=(
      swift
      swift-driver
      swift-help
      swift-legacy-driver
      swiftc
      swiftc-legacy-driver
    )
    for file in "''${swiftDriverFiles[@]}"; do
      rm "''${!outputBin}/bin/$file"
    done
    ln -s swift-frontend "''${!outputBin}/bin/swift"
    ln -s swift-frontend "''${!outputBin}/bin/swiftc"
  '';

  # Will effectively be `buildInputs` when swift is put in `nativeBuildInputs`.
  depsTargetTargetPropagated = lib.optionals stdenv.targetPlatform.isDarwin [ propagated-sdk ];

  __structuredAttrs = true;

  passthru.supportsMacros = bootstrapStage > 1;

  meta = {
    description = "Swift Programming Language";
    homepage = "https://github.com/swiftlang/swift";
    platforms = lib.platforms.darwin ++ lib.platforms.linux ++ lib.platforms.windows;
    badPlatforms = [ lib.systems.inspect.patterns.is32bit ];
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
