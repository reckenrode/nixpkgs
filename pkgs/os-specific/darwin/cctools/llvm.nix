# Create a cctools-compatible bintools that uses equivalent tools from LLVM in place of the ones
# from cctools when possible.

{ lib, stdenv, makeWrapper, cctools-port, llvmPackages, useLLD ? false }:

let
  cctoolsVersion = lib.getVersion cctools-port;
  llvmVersion = llvmPackages.release_version;

  # A compatible implementation of `otool` was not added until LLVM 13.
  useLLVMOtool = lib.versionAtLeast llvmVersion "13";

  # Older versions of `strip` cause problems for the version of `codesign_allocate` available in
  # the version of cctools in nixpkgs. The version of `codesign_allocate` in cctools-1005.2 does
  # not appear to have issues, but the source is not available yet (as of June 2023).
  useLLVMStrip = lib.versionAtLeast llvmVersion "15" || lib.versionAtLeast cctoolsVersion "1005.2";

  llvm_bins = [
    "bitcode_strip"
    "dwarfdump"
    "nm"
    "objdump"
    "ranlib"
    "size"
    "strings"
  ]
  ++ lib.optional useLLVMOtool "otool"
  ++ lib.optional useLLVMStrip "strip";

  # Only include the tools that LLVM doesn’t provide and that are present normally on Darwin.
  # The only exceptions are the following tools, which should be reevaluated when LLVM is bumped.
  # - install_name_tool (llvm-objcopy): unrecognized linker commands when building open source CF;
  # - libtool (llvm-libtool-darwin): not fully compatible when used with xcbuild; and
  # - lipo (llvm-lipo): crashes when running the LLVM test suite.
  cctools_bins = [
    "cmpdylib"
    "codesign_allocate"
    "ctf_insert"
    "install_name_tool"
    "libtool"
    "lipo"
    "nmedit"
    "pagestuff"
    "segedit"
    "vtool"
  ]
  ++ lib.optional (!useLLVMOtool) "otool"
  ++ lib.optional (!useLLVMStrip) "strip";

  ld_path = if useLLD
    then "${lib.getBin llvmPackages.lld}/bin/ld64.lld"
    else "${lib.getBin cctools-port}/bin/ld";

  inherit (stdenv.cc) targetPrefix;
in
stdenv.mkDerivation {
  pname = "cctools-llvm-${if useLLD then "lld" else "ld64-${cctoolsVersion}"}";
  version = llvmVersion;

  nativeBuildInputs = [ makeWrapper ];

  outputs = [ "out" "dev" "man" ];

  buildCommand = ''
    mkdir -p "$out/bin"

    ln -s "${lib.getDev cctools-port}" "$dev"
    ln -s "${lib.getMan cctools-port}" "$man"

    # Use the clang-integrated assembler instead of using `as` from cctools.
    makeWrapper "${lib.getBin llvmPackages.clang-unwrapped}/bin/clang" "$out/bin/${targetPrefix}as" \
      --add-flags "-x assembler -integrated-as -c"

    ln -s "${lib.getBin llvmPackages.bintools-unwrapped}/bin/llvm-ar" "$out/bin/${targetPrefix}ar"

    for tool in ${toString llvm_bins}; do
      llvmTool=''${tool/_/-}
      ln -s "${lib.getBin llvmPackages.llvm}/bin/llvm-$llvmTool" "$out/bin/${targetPrefix}$tool"
    done

    for tool in ${toString cctools_bins}; do
      ln -s "${lib.getBin cctools-port}/bin/${targetPrefix}$tool" "$out/bin/${targetPrefix}$tool"
    done

    ln -s "${ld_path}" "$out/bin/${targetPrefix}ld"
  '';

  passthru = { inherit targetPrefix; };
}
