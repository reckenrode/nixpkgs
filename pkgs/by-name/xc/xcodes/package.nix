{
  lib,
  aria2,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  makeWrapper,
  stdenv,
  swiftPackages_5,
}:

let
  inherit (swiftPackages_5) swift swiftpmHook;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "xcodes";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "XcodesOrg";
    repo = "xcodes";
    tag = finalAttrs.version;
    hash = "sha256-TwPfASRU98rifyA/mINFfoY0MbbwmAh8JneVpJa38CA=";
  };

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-4z5a+Y6MuQDh80jbwONLWOebY7Z+YsxTNwLoZEyf4Ac=";
  };

  nativeBuildInputs = [
    swift
    swiftpmHook
    makeWrapper
  ];

  postInstall = ''
    wrapProgram $out/bin/xcodes \
      --prefix PATH : ${lib.makeBinPath [ aria2 ]}
  '';

  meta = {
    changelog = "https://github.com/XcodesOrg/xcodes/releases/tag/${finalAttrs.version}";
    description = "Command-line tool to install and switch between multiple versions of Xcode";
    homepage = "https://github.com/XcodesOrg/xcodes";
    license = with lib.licenses; [
      mit
      # unxip
      lgpl3Only
    ];
    maintainers = with lib.maintainers; [
      _0x120581f
      emilytrau
    ];
    platforms = lib.platforms.darwin;
  };
})
