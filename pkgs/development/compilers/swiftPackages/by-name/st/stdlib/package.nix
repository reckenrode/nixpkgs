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
      rmdir "''${!outputLib}/lib/swift/${swiftPlatform}" "''${!outputLib}/lib/swift"

      # Install C++ interop libraries and headers
      cp -v lib/swift/${swiftPlatform}/libswiftCxx*.a "''${!outputDev}/lib"
      cp -rv lib/swift/${swiftPlatform}/Cxx*.swiftmodule lib/swift/${swiftPlatform}/libcxx* "''${!outputDev}/lib/swift/${swiftPlatform}"

      mkdir -p "''${!outputDev}/include/swiftToCxx"
      cp -v ../lib/PrintAsClang/{_SwiftCxxInteroperability.h,_SwiftStdlibCxxOverlay.h,experimental-interoperability-version.json} \
        "''${!outputDev}/include/swiftToCxx"

      mkdir -p "''${!outputDev}/nix-support"
      cat <<EOF > "''${!outputDev}/nix-support/setup-hook"
      export NIX_SWIFT_STDLIB_\${lib.replaceString "-" "_" stdenv.hostPlatform.config}_RUNTIME_PATH="''${!outputDev}"
      EOF
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      # Back-deployment libraries are installed as part of the compiler component, so install them manually.
      cp -rv lib/swift/macosx/libswiftCompatibility*.a "''${!outputDev}/lib"
      # Install `Span`-compatibility back-deployment library.
      mkdir -p "''${!outputLib}/lib/swift-6.2/macosx"
      cp -v lib/swift-6.2/macosx/libswiftCompatibilitySpan.dylib "''${!outputLib}/lib/swift-6.2/macosx/libswiftCompatibilitySpan.dylib"
    '';
  })
