{ lib, cmake, ninja, fetchFromGitHub, stdenv }:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-cmark";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-cmark";
    tag = finalAttrs.version;
    hash = "sha256-iHCHMs+UG2QhOFLF1g+3nicDZE0ul3A2dYhFp/Q2ipo=";
  };

  strictDeps = true;

  nativeBuildInputs = [ cmake ninja ];

  __structuredAttrs = true;
})
