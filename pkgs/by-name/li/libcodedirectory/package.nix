{
  lib,
  ld64,
  meson,
  ninja,
  swift-corelibs-libdispatch,
  openssl,
  pkg-config,
  stdenv,
}:

# Building all of ld64 on non-Darwin platforms is too much work, but `libcodedirectory` is needed by vtool.
stdenv.mkDerivation (
  {
    pname = "libcodedirectory";
    version = lib.getVersion ld64;

    strictDeps = true;
    __structuredAttrs = true;

    meta = {
      description = "Examine and manipulate Mach-O code directory";
      platforms = lib.platforms.unix;
      inherit (ld64.meta) homepage license teams;
    };
  }
  // (
    if stdenv.hostPlatform.isDarwin then
      {
        buildCommand = ''
          mkdir -p "$out/lib" "$out/include"
          ln -s ${lib.getDev ld64} "$out/lib/libcodedirectory.a"
          ln -s ${lib.getInclude ld64}/cs_blobs.h "$out/include/cs_blobs.h"
          ln -s ${lib.getInclude ld64}/libcodedirectory.h "$out/include/libcodedirectory.h"
        '';
      }
    else
      {
        inherit (ld64) src prePatch patches;

        nativeBuildInputs = [
          meson
          ninja
          pkg-config
          swift-corelibs-libdispatch
        ];

        buildInputs = [ openssl ];

        postPatch = ''
          export sourceRoot=$sourceRoot/subprojects/libcodedirectory
          cd subprojects/libcodedirectory
        '';
      }
  )
)
