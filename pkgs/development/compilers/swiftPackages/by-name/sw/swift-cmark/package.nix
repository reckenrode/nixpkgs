{
  lib,
  cmake,
  fetchFromGitHub,
  ninja,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swift-cmark";
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "swiftlang";
    repo = "swift-cmark";
    tag = finalAttrs.version;
    hash = "sha256-8Q65DBWL5QfBmqBIEFWBBNCGXe91Yt++uv7BsMgBW9U=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  __structuredAttrs = true;

  doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  meta = {
    description = "CommonMark parsing and rendering library";
    homepage = "https://github.com/swiftlang/swift-cmark";
    platforms = lib.platforms.unix ++ lib.platforms.windows ++ lib.platforms.wasi;
    license = [
      lib.licenses.bsd2
      lib.licenses.mit
    ];
    teams = [ lib.teams.swift ];
  };
})
