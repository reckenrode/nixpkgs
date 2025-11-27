{
  lib,
  stdenv,
  swift,
  swiftpmHook,
  swiftPackages,
}:

swiftPackages.stdenv.mkDerivation (finalAttrs: {
  name = "swift-cxx-interop-test";

  src = ./src;

  nativeBuildInputs = [
    swift
    swiftpmHook
  ];

  postBuild = ''
    make
  '';

  postInstall = ''
    cp SwiftToCxxInteropTest "$out/bin/SwiftToCxxInteropTest"
  '';

  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/${finalAttrs.meta.mainProgram}" | grep 'Hello, Swift!'
    "$out/bin/SwiftToCxxInteropTest" | grep 'Hello, C++!'

    runHook postInstallCheck
  '';

  doInstallCheck = true;

#  env = {
#    # Gross hack copied from `protoc-gen-swift` :(
#    LD_LIBRARY_PATH = lib.optionalString stdenv.hostPlatform.isLinux (
#      lib.makeLibraryPath [
#        swiftPackages.Dispatch
#      ]
#    );
#  };

  meta = {
    inherit (swift.meta)
      team
      platforms
      ;
    license = lib.licenses.mit;
    mainProgram = "CxxInteropTest";
  };
})
