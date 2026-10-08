{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  autoreconfHook,
  makeWrapper,
  pkg-config,
  doxygen,
  freetype,
  libx11,
  libftdi,
  libusb-compat-0_1,
  libusb1,
  ncurses,
  perl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lcdproc";
  version = "0.5.9";

  src = fetchFromGitHub {
    owner = "lcdproc";
    repo = "lcdproc";
    rev = "v${finalAttrs.version}";
    hash = "sha256-9U7QnLWLNUdgMqMdIZQIB0732vrbmT6IRAjqF/YvCOU=";
  };

  patches = [
    ./hardcode_mtab.patch

    # Pull upstream fix for -fno-common toolchains:
    #   https://github.com/lcdproc/lcdproc/pull/148
    (fetchpatch {
      name = "fno-common.patch";
      url = "https://github.com/lcdproc/lcdproc/commit/fda5302878692da933dc03cd011f8ddffefa07a4.patch";
      hash = "sha256-npWBckjZJDyYT1fTA7TssohOy6WDOzVMllbLTHK4plE=";
    })

    # Fix building on aarch64-darwin by avoiding Intel-only assembly.
    (fetchpatch {
      name = "fix-lpt-port-detection.patch";
      url = "https://github.com/lcdproc/lcdproc/commit/695aa0f76173a03295a6d897d7260a09951931bc.patch?full_index=1";
      hash = "sha256-F+i7sPVpzSGBcaAQ2WJYncJUMVrlfKcqqfj//TkckZU=";
    })
  ];

  # we don't need to see the GPL every time we launch lcdd in the foreground
  postPatch = ''
    substituteInPlace server/main.c \
      --replace-fail 'output_GPL_notice();' '// output_GPL_notice();'
  '';

  configureFlags = [
    "--enable-lcdproc-menus"
    "--enable-drivers=all"
    "--with-pidfile-dir=/run"
    # Prevent autoconf from defaulting to C23.
    # Otherwise, lcdproc fails to build on Darwin due to conflicting `getopt` prototypes.
    "ac_cv_prog_cc_c23=no"
  ];

  strictDeps = true;

  buildInputs = [
    freetype
    libx11
    libftdi
    libusb-compat-0_1
    libusb1
    ncurses
    perl
  ];

  nativeBuildInputs = [
    autoreconfHook
    doxygen
    makeWrapper
    pkg-config
  ];

  # In 0.5.9: gcc: error: libbignum.a: No such file or directory
  enableParallelBuilding = false;

  postFixup = ''
    patchShebangs --host $out/bin

    # NixOS will not use this file anyway but at least we can now execute LCDd
    substituteInPlace $out/etc/LCDd.conf \
      --replace-fail server/drivers/ $out/lib/lcdproc/
  '';

  __structuredAttrs = true;

  meta = {
    description = "Client/server suite for controlling a wide variety of LCD devices";
    homepage = "https://lcdproc.org/";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [ peterhoeg ];
    platforms = lib.platforms.unix;
  };
})
