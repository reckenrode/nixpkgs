{
  fetchFromGitHub,
  stdenv,
  swift,
  xcbuildHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dark-mode";
  version = "3.0.2";

  src = fetchFromGitHub {
    owner = "sindresorhus";
    repo = "dark-mode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vgk26fXrtICYyjxsAomVsgr+iEf3ca3U+KRyXF0HxTM=";
  };

  postPatch = ''
    substituteInPlace dark-mode.xcodeproj/project.pbxproj \
      --replace-fail 'MACOSX_DEPLOYMENT_TARGET = 10.10' 'MACOSX_DEPLOYMENT_TARGET = ${stdenv.hostPlatform.darwinMinVersion}'
  '';

  strictDeps = true;

  nativeBuildInputs = [
    swift
    xcbuildHook
  ];

  installPhase = ''
    runHook preInstall
    install -D -m755 -t "$out/bin" Products/Release/dark-mode
    runHook postInstall
  '';

  env.NIX_CFLAGS_LINK = "-L/usr/lib/swift -lswiftCore";

  __structuredAttrs = true;
})
