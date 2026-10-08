{
  lib,
  _experimental-update-script-combinators,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  gitUpdater,
  stdenv,
  swift,
  swiftpm,
  swiftpmDepsUpdater,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-bundler";
  version = "2.0.7";

  src = fetchFromGitHub {
    owner = "moreSwift";
    repo = "swift-bundler";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xzAO8CMLGZ8galiAfoiO2kBNEg69oeq6ya4ZHDmEa3k=";
  };

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-nbJq/M8YGLG8Qw2RGHUy+uE6ZHEmRcUBi3okNYzd9Ow=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  passthru.updateScript = _experimental-update-script-combinators.sequence [
    (gitUpdater { rev-prefix = "v"; })
    (swiftpmDepsUpdater { })
  ];

  __structuredAttrs = true;

  meta = {
    description = "Tool for creating cross-platform Swift apps";
    homepage = "https://swiftbundler.dev";
    license = lib.licenses.asl20;
    mainProgram = "needle";
    maintainers = with lib.maintainers; [ matteopacini ];
    platforms = lib.platforms.darwin;
  };
})
