{
  lib,
  cctools,
  jq,
  makeSetupHook,
  stdenvNoCC,
  swift,
  swiftpm,
}:

let
  vtool = stdenvNoCC.mkDerivation {
    pname = "cctools-vtool";
    version = lib.getVersion cctools;

    buildCommand = ''
      mkdir -p "$out/bin"
      ln -s ${lib.getExe' cctools "vtool"} "$out/bin/vtool"
    '';
  };
in
makeSetupHook {
  name = "swiftpm-hook-${lib.getVersion swiftpm}";
  propagatedBuildInputs =
    [ swiftpm ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [
      # swiftpm requires these tools to build for Darwin. xcrun is part of the Darwin stdenv.
      cctools.libtool
      vtool
    ];
  substitutions = {
    inherit (stdenvNoCC.hostPlatform.extensions) sharedLibrary;
    inherit (swift) swiftPlatform;
    jq = lib.getExe jq;
  };
} ./setup-hook.sh
