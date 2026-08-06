{
  lib,
  stdenv,
  swift,
  swiftpm,
}:

# The primary goal of this test is to confirm that the foundation macros built with the toolchain work on Darwin.
stdenv.mkDerivation {
  name = "swift-test-foundation-macros";

  src = ./src;

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  installCheckPhase = ''
    swift run -c release foundation-macros | grep 'Hello, foundation macros'
    touch "$out"
  '';
}
