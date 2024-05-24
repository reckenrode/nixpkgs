{ callPackage, lib, overrideCC, pkgs, buildPackages, openssl, python3, fetchpatch2, enableNpm ? true }:

let
  # Clang 16+ cannot build Node v18 due to -Wenum-constexpr-conversion errors.
  # Use an older version of clang with the current libc++ for compatibility (e.g., with icu).
  ensureCompatibleCC = packages:
    if packages.stdenv.cc.isClang && lib.versionAtLeast (lib.getVersion packages.stdenv.cc.cc) "16"
      then overrideCC packages.llvmPackages_15.stdenv (packages.llvmPackages_15.stdenv.cc.override {
        inherit (packages.llvmPackages) libcxx;
      })
      else packages.stdenv;

  buildNodejs = callPackage ./nodejs.nix {
    inherit openssl;
    stdenv = ensureCompatibleCC pkgs;
    buildPackages = buildPackages // { stdenv = ensureCompatibleCC buildPackages; };
    python = python3;
  };
in
buildNodejs {
  inherit enableNpm;
  version = "18.20.2";
  sha256 = "sha256-iq6nycfpJ/sJ2RSY2jEbbk0YIzOQ4jxyOlO4kfrUxz8=";
  patches = [
    ./disable-darwin-v8-system-instrumentation.patch
    ./bypass-darwin-xcrun-node16.patch
    ./node-npm-build-npm-package-logic.patch
    ./trap-handler-backport.patch
    ./use-correct-env-in-tests.patch
    (fetchpatch2 {
      url = "https://github.com/nodejs/node/commit/534c122de166cb6464b489f3e6a9a544ceb1c913.patch";
      hash = "sha256-4q4LFsq4yU1xRwNsM1sJoNVphJCnxaVe2IyL6AeHJ/I=";
    })
    # Fixes return address signing when cross-compiling to aarch64
    (fetchpatch2 {
      url = "https://github.com/nodejs/node/commit/39916bf4f320d536aece3f0f9fe215f8cf03cbc7.patch";
      hash = "sha256-wlqFf3HFztn0oZSBJooPKfJL6kXNIn2swGHW97v30Es=";
    })
    # Remove unused `fdopen` in vendored zlib, which causes compilation failures with clang 18 on Darwin.
    (fetchpatch {
      url = "https://github.com/madler/zlib/commit/4bd9a71f3539b5ce47f0c67ab5e01f3196dc8ef9.patch";
      extraPrefix = "deps/v8/third_party/zlib/";
      stripLen = 1;
      hash = "sha256-BXym9kB/Ezk6xtfvLAb/Okm/P696IwtffpgvRKQvUeM=";
    })
  ];
}
