{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  fetchurl,
#  swift,
#  swiftpm,
  swiftPackages_5,
  libarchive,
  p7zip,
  # Building from source on x86_64 fails (among other things) due to:
  # error: cannot load underlying module for 'Darwin'
  fromSource ? true,
}:

let
  inherit (swiftPackages_5) swift swiftpmHook;

  pname = "dockutil";
  version = "3.1.3";

  meta = with lib; {
    description = "Tool for managing dock items";
    homepage = "https://github.com/kcrawford/dockutil";
    license = licenses.asl20;
    maintainers = with maintainers; [ tboerger ];
    mainProgram = "dockutil";
    platforms = platforms.darwin;
  };

  buildFromSource = stdenv.mkDerivation (finalAttrs: {
    inherit pname version meta;

    src = fetchFromGitHub {
      owner = "kcrawford";
      repo = "dockutil";
      rev = finalAttrs.version;
      hash = "sha256-mmk4vVZhq4kt05nI/dDM1676FDWyf4wTSwY2YzqKsLU=";
    };

    swiftpmDeps = fetchSwiftPMDeps {
      inherit (finalAttrs) pname version src;
      hash = "sha256-WPI42HrrLXZLdXB8rCnv3ZbmtzhPmiQPRjpX9gx8V9Y=";
    };

    nativeBuildInputs = [
      swift
      swiftpmHook
    ];
  });

  installBinary = stdenvNoCC.mkDerivation (finalAttrs: {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/kcrawford/dockutil/releases/download/${finalAttrs.version}/dockutil-${finalAttrs.version}.pkg";
      hash = "sha256-9g24Jz/oDXxIJFiL7bU4pTh2dcORftsAENq59S0/JYI=";
    };

    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [
      libarchive
      p7zip
    ];

    unpackPhase = ''
      7z x $src
      bsdtar -xf Payload~
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -Dm755 usr/local/bin/dockutil -t $out/bin
      runHook postInstall
    '';

    meta = meta // {
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  });
in
if fromSource then buildFromSource else installBinary
