{ buildPackages, version_src }:

# Swift needs to be built against the matching tag from the LLVM fork in the swiftlang repo.
# Ideally, it would build against upstream LLVM, but it depends on APIs that have not been upstreamed.
# For example: https://github.com/swiftlang/llvm-project/blob/901f89886dcd5d1eaf07c8504d58c90f37b0cfdf/clang/include/clang/AST/StableHash.h
let
  self = buildPackages.targetPackages.llvmPackages.override rec {
    buildLlvmTools = buildPackages.llvmPackages.tools // {
      tblgen = self.tblgen;
    };
    officialRelease = { }; # Set but empty because we're overriding everything from it.
    inherit (version_src.llvm) version;
    src = buildPackages.fetchFromGitHub {
      inherit (version_src.llvm)
        owner
        repo
        tag
        hash
        ;
    };
    monorepoSrc = src;
    patchesFn =
      patches:
      patches
      // {
        "clang/gnu-install-dirs.patch" = [
          {
            before = "19";
            path = ./patches;
          }
        ];
        "llvm/sancov-libc++-compat.patch" = [
          {
            before = "19";
            path = ./patches;
          }
        ];
      };
    doCheck = false;
  };
in
self
