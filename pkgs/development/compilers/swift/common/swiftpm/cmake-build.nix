{
  lib,
  cctools,
  cmake,
  ninja,
  stdenv,
  swift,
}:

final: prev: {
  pname = "swiftpm-boot";

  nativeBuildInputs =
    (prev.nativeBuildInputs or [ ])
    ++ [
      cmake
      ninja
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      cctools.libtool
    ];

  postUnpack =
    (prev.postUnpack or "")
    + ''
      ln -s "$swiftpmDeps/checkouts" "$NIX_BUILD_TOP/deps"
    '';

  env.NIX_LDFLAGS = lib.optionalString stdenv.hostPlatform.isDarwin "-headerpad_max_install_names";

  preConfigure =
    (prev.preConfigure or "")
    # Build the dependencies required by swiftpm. This has to be done manually due to building with CMake.
    + ''
      declare -A extraFlags=(
        [swift-argument-parser]="-DBUILD_TESTING=OFF"
        [swift-certificates]="
          -DSwiftASN1_DIR=$NIX_BUILD_TOP/deps-build/swift-asn1/cmake/modules
          -DSwiftCrypto_DIR=$NIX_BUILD_TOP/deps-build/swift-crypto/cmake/modules
          -DTSC_DIR=$NIX_BUILD_TOP/deps-build/swift-tools-support-core/cmake/modules
        "
        [swift-driver]="
          -DArgumentParser_DIR=$NIX_BUILD_TOP/deps-build/swift-argument-parser/cmake/modules
          -DLLBuild_DIR=$NIX_BUILD_TOP/deps-build/swift-llbuild/cmake/modules
          -DSwiftSystem_DIR=$NIX_BUILD_TOP/deps-build/swift-system/cmake/modules
          -DTSC_DIR=$NIX_BUILD_TOP/deps-build/swift-tools-support-core/cmake/modules
          -DYams_DIR=$NIX_BUILD_TOP/deps-build/yams/cmake/modules
        "
        [swift-llbuild]="
          -DLLBUILD_SUPPORT_BINDINGS=Swift
          -DCMAKE_OSX_ARCHITECTURES=${stdenv.hostPlatform.darwinArch}
        "
        [swift-tools-support-core]="-DSwiftSystem_DIR=$NIX_BUILD_TOP/deps-build/swift-system/cmake/modules"
      )

      # Some dependencies are built first because they are dependeices of the rest
      for dep in "$NIX_BUILD_TOP/deps"/{swift-{crypto,llbuild,system,tools-support-core},yams,*}; do
        name=$(basename "$dep")
        build_dir=$NIX_BUILD_TOP/deps-build/$name

        if [ ! -d "$build_dir" ]; then
          echo "Building $name"
          echo "cmake flags: -G Ninja ''${extraFlags[$name]} ''${CMAKE_OSX_DEPLOYMENT_TARGET-} -B $build_dir"
          cd "$dep"
          cmake -G Ninja ''${extraFlags[$name]} ''${CMAKE_OSX_DEPLOYMENT_TARGET-} -B "$build_dir"
          cd "$build_dir"
          ninjaBuildPhase
        fi
      done

      appendToVar cmakeFlags "-DArgumentParser_DIR=$NIX_BUILD_TOP/deps-build/swift-argument-parser/cmake/modules"
      appendToVar cmakeFlags "-DLLBuild_DIR=$NIX_BUILD_TOP/deps-build/swift-llbuild/cmake/modules"
      appendToVar cmakeFlags "-DSwiftASN1_DIR=$NIX_BUILD_TOP/deps-build/swift-asn1/cmake/modules"
      appendToVar cmakeFlags "-DSwiftCertificates_DIR=$NIX_BUILD_TOP/deps-build/swift-certificates/cmake/modules"
      appendToVar cmakeFlags "-DSwiftCollections_DIR=$NIX_BUILD_TOP/deps-build/swift-collections/cmake/modules"
      appendToVar cmakeFlags "-DSwiftCrypto_DIR=$NIX_BUILD_TOP/deps-build/swift-crypto/cmake/modules"
      appendToVar cmakeFlags "-DSwiftDriver_DIR=$NIX_BUILD_TOP/deps-build/swift-driver/cmake/modules"
      appendToVar cmakeFlags "-DSwiftSystem_DIR=$NIX_BUILD_TOP/deps-build/swift-system/cmake/modules"
      appendToVar cmakeFlags "-DTSC_DIR=$NIX_BUILD_TOP/deps-build/swift-tools-support-core/cmake/modules"
      appendToVar cmakeFlags "-DYams_DIR=$NIX_BUILD_TOP/deps-build/yams/cmake/modules"
    ''
    + lib.optionalString (lib.versionAtLeast final.version "6.0") ''
      appendToVar cmakeFlags "-DSwiftSyntax_DIR=$NIX_BUILD_TOP/deps-build/swift-syntax/cmake/modules"
    ''
    + ''

      cd "$NIX_BUILD_TOP/$sourceRoot"
    '';

  postInstall =
    (prev.postInstall or "")
    + ''
      soext=${lib.escapeShellArg stdenv.hostPlatform.extensions.sharedLibrary}

      mkdir -p "$out/bin"
      cp -v bin/* "$out/bin"
      rm "$out/bin/swift-bootstrap" # Only used when bootstrapping SwiftPM

      mkdir -p "$out/lib/swift/${swift.swiftPlatform}"
      cp -v lib/*$soext "$out/lib/swift/${swift.swiftPlatform}"

      cp -v "$NIX_BUILD_TOP/deps-build/swift-argument-parser/lib/libArgumentParser$soext" "$out/lib/swift/${swift.swiftPlatform}/libArgumentParser$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-asn1/lib/libSwiftASN1$soext" "$out/lib/swift/${swift.swiftPlatform}/libSwiftASN1$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-certificates/lib/libX509$soext" "$out/lib/swift/${swift.swiftPlatform}/libX509$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-certificates/lib/lib_CertificateInternals$soext" "$out/lib/swift/${swift.swiftPlatform}/lib_CertificateInternals$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-collections/lib/libDequeModule$soext" "$out/lib/swift/${swift.swiftPlatform}/libDequeModule$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-collections/lib/libOrderedCollections$soext" "$out/lib/swift/${swift.swiftPlatform}/libOrderedCollections$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-crypto/lib/libCrypto$soext" "$out/lib/swift/${swift.swiftPlatform}/libCrypto$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-crypto/lib/lib_CryptoExtras$soext" "$out/lib/swift/${swift.swiftPlatform}/lib_CryptoExtras$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-driver/lib/libSwiftDriver$soext" "$out/lib/swift/${swift.swiftPlatform}/libSwiftDriver$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-driver/lib/libSwiftOptions$soext" "$out/lib/swift/${swift.swiftPlatform}/libSwiftOptions$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-llbuild/lib/libllbuildSwift$soext" "$out/lib/swift/${swift.swiftPlatform}/libllbuildSwift$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-tools-support-core/lib/libTSCBasic$soext" "$out/lib/swift/${swift.swiftPlatform}/libTSCBasic$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/swift-tools-support-core/lib/libTSCUtility$soext" "$out/lib/swift/${swift.swiftPlatform}/libTSCUtility$soext"
      cp -v "$NIX_BUILD_TOP/deps-build/yams/lib/libYams$soext" "$out/lib/swift/${swift.swiftPlatform}/libYams$soext"
    ''
    + lib.optionalString (lib.versionAtLeast final.version "6.1.1") ''
      cp -v "$NIX_BUILD_TOP/deps-build/swift-collections/lib/libInternalCollectionsUtilities$soext" "$out/lib/swift/${swift.swiftPlatform}/libInternalCollectionsUtilities$soext"
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      # Fix up the install names of all the dylibs generated by the build process. fixupDarwinDylibNames doesn’t work.
      find "$out/lib" -name '*.dylib' -print0 | while IFS= read -d "" dylib; do
        dylib_name=$(basename "$dylib")
        echo "$dylib: fixing dylib"
        install_name_tool "$dylib" -id "$dylib"
        find "$out" -print0 | while IFS= read -d "" exe; do
          if [ -f "$exe" ] && isMachO "$exe"; then
            install_name_tool "$exe" -change "@rpath/$dylib_name" "$dylib"
          fi
        done
      done
    '';
}
