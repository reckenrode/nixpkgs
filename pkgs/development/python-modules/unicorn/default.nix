{
  lib,
  stdenv,
  buildPythonPackage,
  capstone,
  pytestCheckHook,
  setuptools-scm,
  setuptools,
  unicorn,
}:

buildPythonPackage rec {
  pname = "unicorn";
  version = lib.getVersion unicorn;
  pyproject = true;

  src = unicorn.src;

  sourceRoot = "${src.name}/bindings/python";

  prePatch = ''
    ln -s ${unicorn}/lib/libunicorn.* prebuilt/
  '';

  # Needed on non-x86 linux
  setupPyBuildFlags = lib.optionals stdenv.hostPlatform.isLinux [
    "--plat-name"
    "linux"
  ];

  build-system = [
    setuptools
    setuptools-scm
  ];

  nativeCheckInputs = [
    capstone
    pytestCheckHook
  ];

  # this test does not appear to be intended as a pytest-style test
  disabledTests = [ "test_i386" ];

  pythonImportsCheck = [ "unicorn" ];

  meta = {
    description = "Python bindings for Unicorn CPU emulator engine";
    homepage = "https://www.unicorn-engine.org/";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [
      bennofs
      ris
    ];
  };
}
