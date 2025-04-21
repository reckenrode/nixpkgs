{
  bootSwiftpmHook,
  pkg-config,
  stdenv,
  xctest,
}:

final: prev: {
  pname = "swiftpm";

  dontUseSwiftpmInstall = true;

  nativeBuildInputs = (prev.nativeBuildInputs or [ ]) ++ [
    bootSwiftpmHook
    pkg-config
  ];
  buildInputs = (prev.buildInputs or [ ]) ++ [ xctest ];

  # SwiftPM does not define any installable products in `Package.swift`, so install them manually.
  # These products match what is shipped with Xcode.
  installPhase = ''
    runHook preInstall

    modulePath=${if final.version == "5.10.1" then "." else "Modules"}

    install -D -t "''${!outputBin}/bin" \
      "$(swiftpmBinPath)"/{swift-build,swift-experimental-sdk,swift-package,swift-run,swift-test}

    install -D -t "''${!outputLib}/lib/swift/pm/ManifestAPI" \
      "$(swiftpmBinPath)/$modulePath"/{CompilerPluginSupport,PackageDescription}.swiftmodule \
      "$(swiftpmBinPath)/libPackageDescription${stdenv.hostPlatform.extensions.sharedLibrary}"

    install -D -t "''${!outputLib}/lib/swift/pm/PluginAPI" \
      "$(swiftpmBinPath)/$modulePath/PackagePlugin.swiftmodule" \
      "$(swiftpmBinPath)/libPackagePlugin${stdenv.hostPlatform.extensions.sharedLibrary}"

    runHook postInstall
  '';
}
