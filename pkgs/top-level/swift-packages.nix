let
  autoCalledPackages = import ./by-name-overlay.nix ../development/compilers/swiftPackages/by-name;
in

{
  lib,
  clangStdenv,
  generateSplicesForMkScope,
  llvmPackages,
  makeScopeWithSplicing',
  stdenvNoCC,
  otherSplices ? generateSplicesForMkScope "swiftPackages",
}:

makeScopeWithSplicing' {
  inherit otherSplices;
  extra =
    self:
    let
      bootstrapSwiftPackages = self.overrideScope (
        final: prev: {
          stdlib = null; # Have the bootstrap compiler use its own build of the stdlib.
          swift-bootstrap = prev.swiftc.override { swift-bootstrap = null; };
          swift-driver = prev.swift-driver.overrideAttrs (old: {
            pname = "early-${old.pname}";
          });
        }
      );

      llvm_libtool = stdenvNoCC.mkDerivation {
        pname = "libtool";
        version = lib.getVersion llvmPackages.llvm;

        buildCommand = ''
          mkdir -p "$out/bin"
          ln -s ${lib.getExe' llvmPackages.llvm "llvm-libtool-darwin"} "$out/bin/libtool"
        '';
      };

      #      vtool = stdenvNoCC.mkDerivation {
      #        pname = "cctools-vtool";
      #        version = lib.getVersion cctools;
      #
      #        buildCommand = ''
      #          mkdir -p "$out/bin"
      #          ln -s ${lib.getExe' cctools "vtool"} "$out/bin/vtool"
      #        '';
      #      };
    in
    {
      inherit (self.swift) mkSwiftPackage;
      inherit llvm_libtool;

      llvmPackages_current = llvmPackages;
      swift-bootstrap = bootstrapSwiftPackages.swift;
      swift-no-swift-driver = self.swift.override { swift-driver = null; swift-testing = null; };
      swift-no-testing = self.swift.override { swift-testing = null; };

#      getBuildHost = pkg: pkg.__spliced.buildHost or pkg;
#      getHostTarget = pkg: pkg.__spliced.hostTarget or pkg;

       swift-argument-parser = self.swift-argument-parser;
    };
  f = lib.extends autoCalledPackages (self: {
    stdenv = clangStdenv;
    swift_release = "6.2.4";
  });
}
