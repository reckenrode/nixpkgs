{ lib
, pkgs
, stdenv
}:

# Provides overriden stdenv and gccStdenvs plus a callPackage with additional packages that have
# been overriden to use this SDK instead of the standard one for the target Darwin architecture.
# This is set up so it should default to the standard stdenv and package environment on non-Darwin
# platforms. On platforms where this SDK is the default, it should also pass through.
let
  needsOverrides = stdenv.isDarwin && stdenv.isx86_64;

  nixpkgsFun = newArgs: import ../../../.. ((removeAttrs pkgs [ "system" ]) // newArgs);

  sdkPkgs =
    if !needsOverrides then pkgs
    else
      nixpkgsFun rec {
        # darwinSdkVersion determines which version of the SDK will be used by the stdenv bootstrap.
        # Don’t override the system-defined minimum version to preserve compatibility with older
        # systems when using a newer SDK.
        localSystem = lib.systems.elaborate stdenv.targetPlatform.system // {
          darwinMaxVersion = "11.0";
          darwinSdkVersion = "11.0";
        };
      };
in
{
  callPackage =
    pkgs.newScope (lib.optionalAttrs needsOverrides {
      inherit (sdkPkgs) gccStdenv gcc10Stdenv gcc11Stdenv stdenv
        darwin xcbuild xcodebuild
        cmake rustPlatform;
    });

  inherit (sdkPkgs) gccStdenv gcc10StdenvCompat gcc11Stdenv stdenv;
}
