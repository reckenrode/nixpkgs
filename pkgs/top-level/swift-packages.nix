let
  autoCalledPackages = import ./by-name-overlay.nix ../development/compilers/swiftPackages/by-name;
in

{
  lib,
  clangStdenv,
  darwin,
  generateSplicesForMkScope,
  llvmPackages,
  makeScopeWithSplicing',
  overrideCC,
  stdenvNoCC,
  otherSplices ? generateSplicesForMkScope "swiftPackages",
}:

makeScopeWithSplicing' {
  inherit otherSplices;
  extra =
    self:
    let
      bootstrapSwiftPackages = self.overrideScope (
        final: prev:
        let
          swift-stage0 = prev.swift.override {
            swiftc = prev.swiftc.override { swift-bootstrap = null; };
            swift-corelibs-libdispatch = null;
            swift-driver = null;
            swift-foundation = null;
            swift-testing = null;
          };
        in
        {
          stdlib = null; # Have the bootstrap compiler use its own build of the stdlib.
          swift-bootstrap = prev.swift.override {
            swiftc = prev.swiftc.override { swift-bootstrap = null; };
            swift-corelibs-libdispatch = null;
            swift-driver = null;
            swift-foundation = null;
            swift-testing = null;
          };
          #          swift-bootstrap = swift-stage0.override {
          #            # Swift Experimental String Processing depends on Foundation.
          #            # Darwin can get it from the SDK, but Linux needs to build it first.
          #            swift-foundation = lib.optionalDrvAttr stdenvNoCC.hostPlatform.isLinux final.swift-foundation;
          #          };
          #          swift-collections = prev.swift-collections.override { swift-minimal = swift-stage0; };
          #          swift-corelibs-foundation = prev.swift-corelibs-foundation.override { swift-minimal = swift-stage0; };
          swift-driver = prev.swift-driver.overrideAttrs (old: {
            pname = "early-${old.pname}";
          });
          #          swift-foundation = prev.swift-foundation.override { swift-minimal = swift-stage0; swift-syntax = null; };
          #          swift-syntax = prev.swift-syntax.override { swift-minimal = swift-stage0; };
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

      swift-minimal = self.swift.override {
        swift-corelibs-libdispatch = null;
        swift-driver = null;
        swift-foundation = null;
        swift-testing = null;
      };

      #      getBuildHost = pkg: pkg.__spliced.buildHost or pkg;
      #      getHostTarget = pkg: pkg.__spliced.hostTarget or pkg;

      #      swift-argument-parser = self.swift-argument-parser;
    };
  f = lib.extends autoCalledPackages (self: {
    stdenv = clangStdenv;
    #    stdenv = (overrideCC clangStdenv (clangStdenv.cc.override { libcxx = null; })).override {
    #      extraBuildInputs = [ self.sysroot ];
    #    }; # libc++/libstdc++ will be provided via the sysroot.
    swift-corelibs-icu = darwin.ICU; # Reuse the packaging done for the ICU source release.
    swift_release = "6.2.4";

    Dispatch = lib.warn "Dispatch has been renamed to swift-corelibs-libdispatch. It is also now included in the default Swift SDK and no longer needs referenced as a separate package." self.swift-corelibs-libdispatch;
    Foundation = lib.warn "Foundation has been renamed to swift-corelibs-foundation. It is also now included in the default Swift SDK and no longer needs referenced as a separate package." self.swift-corelibs-foundation;
    XCTest = lib.warn "XCTest has been renamed to swift-corelibs-xctest. It is also now included in the default Swift SDK and no longer needs referenced as a separate package." self.swift-corelibs-xctest;
  });
}
