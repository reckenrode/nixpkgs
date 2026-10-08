{
  lib,
  cctools,
  meson,
  ninja,
  openssl,
  stdenv,
}:

# Building all of cctools on non-Darwin platforms is too much work, but `vtool` is needed by Swift.
stdenv.mkDerivation (
  {
    pname = "vtool";
    version = lib.getVersion cctools;

    outputs = [
      "out"
      "man"
    ];

    strictDeps = true;
    __structuredAttrs = true;

    meta = {
      description = "Examine and manipulate version information in Mach-O binaries";
      platforms = lib.platforms.unix;
      inherit (cctools.meta) homepage license teams;
    };
  }
  // (
    if stdenv.hostPlatform.isDarwin then
      {
        buildCommand = ''
          mkdir -p "$out/bin" "$man/share/man/man1"
          ln -s ${lib.getExe' cctools "vtool"} "$out/bin/vtool"
          ln -s ${lib.getMan cctools}/share/man/man1/vtool.1.gz "$man/share/man/man1/vtool.1.gz"
        '';
      }
    else
      {
        inherit (cctools) src postUnpack xcodeHash;

        postPatch = ''
          substitute ${./meson.build} meson.build \
            --subst-var version
        '';

        nativeBuildInputs = [
          meson
          ninja
          openssl
        ];

        installPhase = ''
          runHook preInstall
          install -m755 -D build/what "$out/bin/what"
          install -m755 -D what/what.1 "$man/share/man/man1/what.1"
          runHook postInstall
        '';
      }
  )
)
