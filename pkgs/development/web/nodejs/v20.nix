{ callPackage, fetchpatch2, openssl, python3, enableNpm ? true }:

let
  buildNodejs = callPackage ./nodejs.nix {
    inherit openssl;
    python = python3;
  };
in
buildNodejs {
  inherit enableNpm;
  version = "20.12.2";
  sha256 = "sha256-18vMX7+zHpAB8/AVC77aWavl3XE3qqYnOVjNWc41ztc=";
  patches = [
    ./disable-darwin-v8-system-instrumentation-node19.patch
    ./bypass-darwin-xcrun-node16.patch
    ./node-npm-build-npm-package-logic.patch
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
  ];
}
