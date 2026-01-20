{
  name ? "",
  lib,
  runtimeShell,
  cc ? clang,
  #  libc ? null,
  bintools,
  coreutils ? null,
  #  apple-sdk ? null,
  #  nativeTools,
  #  noLibc ? false,
  #  nativeLibc,
  #  nativePrefix ? "",
  #  propagateDoc ? swiftc != null && swiftc ? man,
  #  extraTools ? [ ],
  #  extraPackages ? [ ],
  #  extraBuildCommands ? "",
  #  nixSupport ? { },
  #  isGNU ? false,
  #  isClang ? cc.isClang or false,
  #  isZig ? cc.isZig or false,
  #  isArocc ? cc.isArocc or false,
  #  isCcache ? cc.isCcache or false,
  gnugrep ? null,
  expand-response-params,
  #  libcxx ? null,

  clang,
  swiftc,
  swift-driver,
  stdenvNoCC,
}:

#wrapperParams = {
#    inherit bintools;
#    coreutils_bin = lib.getBin coreutils;
#    gnugrep_bin = gnugrep;
#    suffixSalt = lib.replaceStrings [ "-" "." ] [ "_" "_" ] targetPlatform.config;
#    use_response_file_by_default = 1;
#    swiftDriver = "";
#    # NOTE: @cc_wrapper@ and @prog@ need to be filled elsewhere.
#  }
let
  inherit (stdenvNoCC) buildPlatform hostPlatform targetPlatform;

  suffixSalt =
    lib.replaceStrings [ "-" "." ] [ "_" "_" ] targetPlatform.config
    + lib.optionalString (targetPlatform.isDarwin && targetPlatform.isStatic) "_static";

  targetPrefix = lib.optionalString (targetPlatform != hostPlatform) (targetPlatform.config + "-");

  swiftName = lib.getName swiftc;
  swiftVersion = lib.getVersion swiftc;

  useSwiftDriver = swift-driver != null;
  swiftDriverExe = lib.getExe' swift-driver "swift-driver"; # swift-driver may be a swift-bin with other files in it.

  coreutils_bin = lib.getBin coreutils;
  gnugrep_bin = lib.getBin gnugrep;
in
stdenvNoCC.mkDerivation ({
  pname = targetPrefix + (if name != "" then name else "${swiftName}-wrapper");
  version = swiftVersion;

  preferLocalBuild = true;

  strictDeps = true;

  outputs = [ "out" ];

  passthru = {
    inherit targetPrefix suffixSalt;
  };

  dontBuild = true;
  dontConfigure = true;
  enableParallelBuilding = true;

  unpackPhase = ''
    src=$PWD
  '';

  wrapper = ./wrapper.sh;

  installPhase = ''
    mkdir -p $out/bin $out/nix-support

    wrap() {
      local dst="$1"
      local wrapper="$2"
      export prog="$3"
      export use_response_file_by_default=1
      substituteAll "$wrapper" "$out/bin/$dst"
      chmod +x "$out/bin/$dst"
    }

    substituteAll ${./setup-hook.sh} "$out/nix-support/setup-hook"

    wrap swift-frontend ${./wrapper.sh} "$swiftc/bin/swift-frontend"
  ''
  + lib.optionalString useSwiftDriver ''
    wrap swift-driver ${./wrapper.sh} "$swiftDriver/bin/swift-driver"
  '';

  env = {
    cc_wrapper = cc;

    expandResponseParams = lib.optionalString (expand-response-params != "") (
      lib.getExe expand-response-params
    );

    shell = lib.getBin runtimeShell + runtimeShell.shellPath or "";

    inherit
      suffixSalt
      bintools
      coreutils_bin
      gnugrep_bin
      swiftc
      ;

    swiftDriver = lib.optionalString useSwiftDriver swift-driver;
  }
  // lib.mapAttrs (_: lib.optionalString targetPlatform.isDarwin) {
    # These will become empty strings when not targeting Darwin.
    inherit (targetPlatform) darwinMinVersion darwinMinVersionVariable;
  };

  __structuredAttrs = true;
})
