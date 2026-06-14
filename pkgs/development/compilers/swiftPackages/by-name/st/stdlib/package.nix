{
  lib,
  makeSetupHook,
  stdenv,
  swiftc,
}:

let
  swiftPlatform = stdenv.hostPlatform.swift.platform;
  libraryExtension = stdenv.hostPlatform.extensions.library;
in
(swiftc.override {
  stdlib = null;
  swiftComponents = [
    "back-deployment"
    "sdk-overlay"
    "static-mirror-lib"
    "swift-remote-mirror"
    "swift-remote-mirror-headers"
    "stdlib"
  ];
}).overrideAttrs
  (old: {
    pname = "stdlib";

    outputs = [
      "out"
      "dev"
    ];

    postInstall = ''
      moveToOutput "lib/swift/${swiftPlatform}" "''${!outputLib}"

      # Static libraries, Swift modules, and shims are only needed for development.
      moveToOutput "lib/swift/${swiftPlatform}/*.swiftmodule" "''${!outputDev}"
      moveToOutput "lib/swift/_InternalSwiftStaticMirror" "''${!outputDev}"
      moveToOutput "lib/swift/embedded" "''${!outputDev}"
      moveToOutput "lib/swift/module.modulemap" "''${!outputDev}"
      moveToOutput "lib/swift/shims" "''${!outputDev}"
      moveToOutput "lib/swift_static" "''${!outputDev}"

      # Move libraries out of `lib/swift/`, so ld-wrapper will find them automatically.
      mv -v "''${!outputLib}/lib/swift/${swiftPlatform}"/*${libraryExtension} "''${!outputLib}/lib"

      # Install C++ interop libraries and headers
      cp -v lib/swift/${swiftPlatform}/libswiftCxx*.a "''${!outputDev}/lib"
      cp -rv lib/swift/${swiftPlatform}/Cxx*.swiftmodule "''${!outputDev}/lib/swift/${swiftPlatform}"

      mkdir -p "''${!outputDev}/include/swiftToCxx"
      cp -v ../lib/PrintAsClang/{_SwiftCxxInteroperability.h,_SwiftStdlibCxxOverlay.h,experimental-interoperability-version.json} \
        "''${!outputDev}/include/swiftToCxx"
      cp -v lib/swift/${swiftPlatform}/libcxx* "''${!outputDev}/lib/swift/${swiftPlatform}"
    ''
    # libstdc++ does not come with a modulemap. It needs one provided by Swift.
    + lib.optionalString (stdenv.cc.libcxx == null) ''
      moveToOutput "lib/swift/${swiftPlatform}/libstdcxx.*" "''${!outputDev}"
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      # Linux has some extra development files that need moved to $dev
      moveToOutput lib/swift/${swiftPlatform}/${stdenv.hostPlatform.swift.arch} "''${!outputDev}"
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      # Back-deployment libraries are installed as part of the compiler component, so install them manually.
      cp -rv lib/swift/macosx/libswiftCompatibility*.a "''${!outputDev}/lib"
      # Install `Span`-compatibility back-deployment library.
      mkdir -p "''${!outputLib}/lib/swift-6.2/macosx"
      cp -v lib/swift-6.2/macosx/libswiftCompatibilitySpan.dylib "''${!outputLib}/lib/swift-6.2/macosx/libswiftCompatibilitySpan.dylib"
      # macOS 26.4 dropped the Swift Differentiation dylibs. Use the one in the store instead of `/usr/lib/swift`.
      install_name_tool "''${!outputLib}/lib/libswift_Differentiation.dylib" -id "''${!outputLib}/lib/libswift_Differentiation.dylib"

      # Clean up empty folders.
      rmdir "''${!outputLib}/lib/swift/${swiftPlatform}" "''${!outputLib}/lib/swift"
    '';
  })
