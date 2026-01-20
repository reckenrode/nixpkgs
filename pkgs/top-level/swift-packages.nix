let
  # Because of Nix's import-value cache, importing lib is free
  lib = import ../../lib;

  autoCalledPackages' = import ./by-name-overlay.nix ../development/compilers/swiftPackages/by-name;

  # Split `autoCalledPackages'` into a set of packages that are internal to `swiftPackages` (“extras”) or exposed as
  # public attributes. The dividing line is whether the package is useful on its own (e.g., provides binaries) or
  # should normally be taken via `fetchSwiftPMDeps` or `swiftpm2nix`.

  # Trying to do this via passthru attributes on the packages causes an infinite recursion.
  extras = [
#    "cxx-interop-test"
    "swift-argument-parser"
    "swift-asn1"
    #    "swift-bin"
    "swift-certificates"
    "swift-cmark"
    "swift-collections"
    "swift-crypto"
    "swift-llbuild"
    "swift-system"
    "swift-tools-support-core"
    "wrapper"
  ];

  autoCalledExtraPackages =
    final: prev: lib.filterAttrs (n: _: lib.elem n extras) (autoCalledPackages' final prev);

  autoCalledPackages = final: prev: lib.removeAttrs (autoCalledPackages' final prev) extras;
in

{
  clangStdenv,
  generateSplicesForMkScope,
  llvmPackages,
  makeScopeWithSplicing',
  stdenvNoCC,
  otherSplices ? generateSplicesForMkScope "swiftPackages",
}:

makeScopeWithSplicing' {
  inherit otherSplices;
  extra = lib.extends autoCalledExtraPackages (
    self:
    let
      bootstrapSwiftPackages = self.overrideScope (
        final: prev: {
          stdlib = null; # Have the bootstrap compiler use its own build of the stdlib.
          swift-bootstrap = prev.swift.override {
            swiftc = self.swift-bin-unwrapped;
            swift-driver = self.swift-bin-unwrapped;
          };
          #          }; # prev.swiftc.override { swift-bootstrap = null; };
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
      swift-no-swift-driver = self.swift.override {
        swift-driver = null;
        swift-testing = null;
      };
      swift-no-testing = self.swift.override { swift-testing = null; };

      wrapSwiftcWith = args: self.wrapSwiftc.override args;

      #      getBuildHost = pkg: pkg.__spliced.buildHost or pkg;
      #      getHostTarget = pkg: pkg.__spliced.hostTarget or pkg;

      #       swift-argument-parser = self.swift-argument-parser;
    }
  );
  f = lib.extends autoCalledPackages (self: {
    stdenv = clangStdenv;
    swift_release = "6.3.3";
  });
}
