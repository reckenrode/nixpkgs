{
  lib,
  callPackage,
  stdenvNoCC,
  stdlib,
  swift-corelibs-xctest,
  swift-driver,
  swift-testing,
  swift_release,
  swiftc,
}@args:

let
  getBuildHost = lib.mapAttrs (_: pkg: pkg.__spliced.buildHost or pkg);
  getHostTarget = lib.mapAttrs (_: pkg: pkg.__spliced.hostTarget or pkg);

  buildHostPackages = getBuildHost args;
  hostTargetPackages = getHostTarget args;

  inherit (buildHostPackages)
    swiftc

    swift-corelibs-xctest
    swift-driver
    swift-testing
    ;

  inherit (hostTargetPackages) stdlib;

  stdlibDevPath = lib.escapeShellArg (lib.getDev stdlib);

  includeTesting = swiftc.supportsMacros && swift-testing != null;
  swiftPlatform = stdenvNoCC.hostPlatform.swift.platform;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "swift" + lib.removePrefix "swiftc" (lib.getName swiftc);
  version = swift_release;

  inherit (swiftc) outputs;

  #  swiftcOutputs = lib.genAttrs swiftc.outputs (output: lib.getOutput output swiftc);

  strictDeps = true;

  # Will effectively be `buildInputs` when swift is put in `nativeBuildInputs`.
  depsTargetTargetPropagated = lib.optionals (stdlib != null) [
    # Propagate the stdlib to make sure the linker wrapper will pick up the dynamic and static libraries.
    stdlib
  ];

  # Will effectively be `nativeBuildInputs` when swift is put in `nativeBuildInputs`.
  propagatedBuildInputs = lib.optionals includeTesting [
    swift-corelibs-xctest
    swift-testing
  ];

  buildCommand = ''
    recordPropagatedDependencies
  ''
  + lib.concatMapStringsSep "\n" (
    output:
    let
      outputPath = lib.escapeShellArg (lib.getOutput output swiftc);
    in
    # Special handling is needed to set up $out/bin for swift-driver. The stdlib also needs linked.
    if output == "out" then
      ''
        # Set up `bin` so that `swift-driver` can be added to it later.
        mkdir -p "$out/bin"
        for file in ${outputPath}/bin/*; do
          dest_file=$out/bin/$(basename "$file")
          if [[ -L "$file" && "$(basename "$(readlink -f "$file")")" = swift-frontend ]]; then
            ln -s swift-frontend "$dest_file"
          else
            ln -s "$file" "$dest_file"
          fi
        done

        # Set up `lib` so that the stdlib can be symlinked into it when it’s a separate derivation.
        mkdir -p "$out/lib"
        for file in ${outputPath}/lib/*; do
          dname=$(basename "$file")
          if [[ "$dname" =~ ^swift ]]; then
            mkdir -p "$out/lib/$dname"
            for f in "$file"/*; do
              ln -s "$f" "$out/lib/$dname/$(basename "$f")"
            done
          else
            ln -s "$file" "$out/lib/$(basename "$file")"
          fi
        done

        # Symlink any other files and folders.
        for file in ${outputPath}/*; do
          dname=$(basename "$file")
          if [ ! -e "$out/$dname" ]; then
            ln -s "$file" "$out/$dname"
          fi
        done
      ''
      + lib.optionalString (stdlib != null) ''
        # `swift-frontend` expects to find everything relative to its location after resolving symlinks.
        # It’s easier to copy it instead of patching Swift to work with this.
        rm "$out/bin/swift-frontend"
        cp ${outputPath}/bin/swift-frontend "$out/bin/swift-frontend"
        # Set up the stdlib and Swift compiler libs. These are together under the same lib folder in the toolchain.
        for file in ${stdlibDevPath}/lib/*; do
          dname=$(basename "$file")
          if [ -d "$file" ]; then
            mkdir -p "$out/lib/$dname"
            for f in "$file"/*; do
              ln -s "$f" "$out/lib/$dname/$(basename "$f")"
            done
          else
            ln -s "$file" "$out/lib/$dname"
          fi
        done
      ''
    # Propagated inputs in $dev/nix-support have to be substituted to use this derivation instead of swiftc.
    else if output == "dev" then
      ''
        mkdir -p "$dev/nix-support"
        for file in ${outputPath}/nix-support/*; do
          dest_file=$dev/nix-support/$(basename "$file")
          cat "$file" >> "$dest_file"
          substituteInPlace "$dev/nix-support/$(basename "$file")" \
            ${lib.concatStringsSep " " (
              lib.zipListsWith (
                swiftcOutput: output:
                "--replace-quiet ${lib.escapeShellArg (lib.getOutput swiftcOutput swiftc)} ${placeholder output}"
              ) swiftc.outputs finalAttrs.outputs
            )}
        done

        # Set up the include folder so that stdlib headers can also be symlinked into them.
        mkdir -p "$dev/include/swift"
        for file in ${outputPath}/include/*; do
          dname=$(basename "$file")
          if [ "$dname" = "swift" ]; then
            for f in "$file"/*; do
              ln -s "$f" "$dev/include/$dname/$(basename "$f")"
            done
          else
            ln -s "$file" "$dev/include/$dname"
          fi
        done
      ''
      + lib.optionalString (stdlib != null) ''
        # Link any headers installed to `$dev/include` from the stdlib.
        mkdir -p "$dev/include/swift"
        for file in ${stdlibDevPath}/include/swift/*; do
          ln -s "$file" "$dev/include/swift/$(basename "$file")"
        done
      ''
    else
      ''
        ln -s ${outputPath} ${placeholder output}
      ''
  ) finalAttrs.outputs
  + lib.optionalString (swift-driver != null) (
    ''
      ln -s ${lib.escapeShellArg (lib.getExe swift-driver)} "$out/bin/swift-driver"
      ln -s ${lib.escapeShellArg (lib.getExe' swift-driver "swift-help")} "$out/bin/swift-help"
      for exe in swift swiftc; do
        mv "$out/bin/$exe" "$out/bin/$exe-legacy-driver"
        ln -s swift-driver "$out/bin/$exe"
      done
    ''
    + lib.optionalString (stdlib != null) ''
      # `swift-driver` expects to find everything relative to its location after resolving symlinks.
      # It’s easier to copy it instead of patching Swift to work with this.
      rm "$out/bin/swift-driver"
      cp ${lib.escapeShellArg (lib.getExe swift-driver)} "$out/bin/swift-driver"
    ''
  );

  __structuredAttrs = true;

  passthru = {
    inherit swiftc swift-driver;
  };

  meta = {
    description = "Swift Programming Language";
    homepage = "https://github.com/swiftlang/swift";
    inherit (swiftc.meta) platforms;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
})
