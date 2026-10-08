{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,

  # Build the FMUs following the latest FMI standard
  FMIVersion ? 3,
}:

# C.f. <https://fmi-standard.org/>
assert lib.asserts.assertMsg (
  FMIVersion >= 2 && FMIVersion <= 3
) "FMIVersion must be a valid FMI specification standard of: 2 or 3; not ${toString FMIVersion}";

stdenv.mkDerivation (finalAttrs: {
  pname = "reference-fmus";
  version = "0.0.42";
  src = fetchFromGitHub {
    owner = "modelica";
    repo = "reference-fmus";
    rev = "v${finalAttrs.version}";
    hash = "sha256-lJODxTu346n4/BE1EYJr4vzCnAcqpEZlfHA2LZb/Lm8=";
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DFMI_VERSION=${toString FMIVersion}"
    (lib.cmakeFeature "FMI_ARCHITECTURE"  stdenv.hostPlatform.parsed.cpu.name)
  ];

  env = lib.optionalAttrs (stdenv.hostPlatform.cc.isGNU && FMIVersion == 3) {
    CFLAGS = "-Wno-stringop-truncation";
  };

  meta = {
    description = "Functional Mock-up Units for development, testing and debugging";
    homepage = "https://github.com/modelica/Reference-FMUs";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [ tmplt ];
    platforms = lib.platforms.all;
  };
})
