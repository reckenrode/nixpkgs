{
  lib,
  stdenv,
  fetchFromGitHub,
  gettext,
  autoreconfHook,
  libiconv,
}:

stdenv.mkDerivation rec {
  pname = "wavpack";
  version = "5.8.1";

  enableParallelBuilding = true;

  nativeBuildInputs = [
    autoreconfHook
    gettext
  ];
  buildInputs = [ libiconv ];

  # `configure` fails to detect libiconv on Darwin because `AM_ICONV` from gettext checks for bugs,
  # which causes it to reject Darwin’s libiconv.
  env = lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    NIX_LDFLAGS = "-liconv";
  };

  src = fetchFromGitHub {
    owner = "dbry";
    repo = "WavPack";
    rev = version;
    hash = "sha256-V9jRIuDpZYIBohJRouGr2TI32BZMXSNVfavqPl56YO0=";
  };

  patches = [ ./Fix-autoreconf-with-gettext-0.25.patch ];

  outputs = [
    "out"
    "dev"
    "doc"
    "man"
  ];

  meta = {
    description = "Hybrid audio compression format";
    homepage = "https://www.wavpack.com/";
    changelog = "https://github.com/dbry/WavPack/releases/tag/${version}";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ codyopel ];
  };
}
