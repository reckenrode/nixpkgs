let
  autoCalledPackages = import ./by-name-overlay.nix ../development/compilers/swiftPackages/by-name;
in

{
  lib,
  buildPackages,
  clangStdenv,
  darwin,
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
          swift-bootstrap = prev.swift.override {
            swiftc = prev.swiftc.override { swift-bootstrap = null; };
            swift-corelibs-libdispatch = null;
            swift-driver = null;
            swift-foundation = null;
            swift-testing = null;
            enableRepl = false;
          };
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
    in
    {
      inherit (self.swift) mkSwiftPackage;
      inherit llvm_libtool;

      llvmPackages_current = llvmPackages;
      swift-bootstrap = bootstrapSwiftPackages.swift.override { enableRepl = false; };

      swift-minimal = self.swift.override {
        swift-corelibs-libdispatch = null;
        swift-driver = null;
        swift-foundation = null;
        swift-testing = null;
        enableRepl = false;
      };
    };
  f = lib.extends autoCalledPackages (self: {
    stdenv = clangStdenv;

    swift-corelibs-icu = darwin.ICU; # Reuse the packaging done for the ICU source release.

    # Compatibility aliases for the old Swift packaging.
    swift-unwrapped = lib.warn "Swift is no longer wrapped. Use `swift` directly." self.swift;
    swiftNoSwiftDriver = lib.warn "swiftNoSwiftDriver is an alias. Override `swift` and set `swift-driver` to `null` instead." self.swift.override { swift-driver = null; };

    Dispatch = lib.warn "Dispatch has been renamed to swift-corelibs-libdispatch. It is also now included in the default Swift SDK and no longer needs referenced as a separate package." self.swift-corelibs-libdispatch;
    Foundation = lib.warn "Foundation has been renamed to swift-corelibs-foundation. It is also now included in the default Swift SDK and no longer needs referenced as a separate package." self.swift-corelibs-foundation;
    XCTest = lib.warn "XCTest has been renamed to swift-corelibs-xctest. It is also now included in the default Swift SDK and no longer needs referenced as a separate package." self.swift-corelibs-xctest;

    swift_release = "6.2.4";
  });
}
