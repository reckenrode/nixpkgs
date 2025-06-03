{
  lib,
  buildPackages,
  callPackage,
  generateSplicesForMkScope,
  llvmPackages,
  makeScopeWithSplicing',
  overrideCC,
  pkgsBuildBuild,
  stdenv,
  wrapCC,
}:

let
  versions = lib.importJSON ./versions.json;

  makeSwiftScope =
    release_version:
    makeScopeWithSplicing' {
      otherSplices = generateSplicesForMkScope "swiftPackages_${lib.versions.major release_version}";
      f =
        self:
        let
          release_major = lib.versions.major release_version;
        in
        lib.packagesFromDirectoryRecursive {
          callPackage = self.callPackage;
          directory = ./common;
        }
        // {
          inherit release_version;
          bootSwift =
            if !lib.systems.equals stdenv.buildPlatform stdenv.hostPlatform then
              buildPackages.swiftPackages.swift
            else if release_major == "5" then
              self.swift.override {
                bootSwift = null;
                enableBuildingSwiftWithSwift = false;
              }
            else
              self.swift.override {
                bootSwift = pkgsBuildBuild.swiftPackageSets.${toString (lib.toInt release_major - 1)}.swift;
                enableSwiftDriver = false;
              };

          bootSwiftpm = self.swiftpm.override {
            swift = self.bootSwift;
            enableCmakeBuild = true;
          };

          bootSwiftpmHook = self.swiftpmHook.override { swiftpm = self.bootSwiftpm; };

          # Compiling Swift with GCC isn’t very well supported. It also tends to expect LLVM bintools.
          stdenv =
            if stdenv.cc.isGNU then
              overrideCC llvmPackages.stdenv (
                llvmPackages.stdenv.cc.override { bintools = llvmPackages.bintools; }
              )
            else
              stdenv;

          swift-driver = self.swift.driver;

          # Apply defaults based on the Swift release, but use the values from `versions.json` if they exist.
          version_src = lib.mapAttrs (
            name: value:
            value
            // {
              tag = value.tag or "swift-${release_version}-RELEASE";
              version = value.version or release_version;
            }
          ) versions.${self.release_version};
        };
    };

  packageSets = lib.genAttrs (lib.attrNames versions) makeSwiftScope;
in
lib.mapAttrs' (version: packageSet: {
  name = lib.versions.major version;
  value = lib.removeAttrs packageSet [
    "bootSwift"
    "bootSwiftpm"
    "bootSwiftpmHook"
    "callPackage"
    #    "llvmPackages"
    "newScope"
    "overrideScope"
    "packages"
    "stdenv"
    "version_src"
  ];
}) packageSets
