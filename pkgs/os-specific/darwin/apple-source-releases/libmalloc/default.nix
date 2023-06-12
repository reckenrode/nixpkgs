{ appleDerivation', stdenvNoCC }:

# Unfortunately, buiding libmalloc is not feasible due to its use of non-public headers, but
# it’s still use to provide its header (`malloc.h`) because it’s needed by the Libsystem derivation.
appleDerivation' stdenvNoCC {
  installPhase = ''
    mkdir -p $out/include
    cp -R include/malloc $out/include/
  '';
}
