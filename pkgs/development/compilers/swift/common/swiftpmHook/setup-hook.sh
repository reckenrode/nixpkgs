# shellcheck shell=bash

swiftpm_addCVars() {
    # See ../setup-hooks/role.bash
    # local role_post
    # getHostRoleEnvHook

    # TODO: Figure out how to make this work with cross-compilation
    swiftLibDir='.*/lib/swift\(_static\)?/\(linux\|macosx\|windows\)\(/[A-Za-z0-9_-]*$\)?'
    while IFS= read -d "" d; do
        appendToVar swiftpmFlags "-Xswiftc" "-I" "-Xswiftc" "$d"
    done < <(find "$1" -maxdepth 4 -type d -and -regex "$swiftLibDir" -print0)
}

addEnvHooks "$targetOffset" swiftpm_addCVars

swiftpmUnpackDeps() {
    echo "Unpacking SwiftPM dependencies"
    buildRoot=$NIX_BUILD_TOP/${swiftpmRoot-"$sourceRoot"}/.build
    mkdir -p "$buildRoot/checkouts"
    for dep in "$swiftpmDeps/checkouts"/*; do
        ln -s "$dep" "$buildRoot/checkouts/$(basename "$dep")"
    done
    install -m 0600 "$swiftpmDeps/workspace-state.json" "$buildRoot/workspace-state.json"
}

if [ -n "${swiftpmDeps-}" ]; then
    postUnpackHooks+=(swiftpmUnpackDeps)
fi

# Build using 'swift-build'.
swiftpmBuildPhase() {
    runHook preBuild

    local buildCores=1
    if [ "${enableParallelBuilding-1}" ]; then
        buildCores="$NIX_BUILD_CORES"
    fi

    local flagsArray=(
        -j "$buildCores"
        -c "${swiftpmBuildConfig-release}"
    )
    concatTo flagsArray swiftpmFlags swiftpmFlagsArray

    echoCmd 'SwiftPM flags' "${flagsArray[@]}"
    TERM=dumb swift-build "${flagsArray[@]}"

    runHook postBuild
}

if [ -z "${dontUseSwiftpmBuild-}" ] && [ -z "${buildPhase-}" ]; then
    buildPhase=swiftpmBuildPhase
fi

# Check using 'swift-test'.
swiftpmCheckPhase() {
    runHook preCheck

    local buildCores=1
    if [ "${enableParallelBuilding-1}" ]; then
        buildCores="$NIX_BUILD_CORES"
    fi

    local flagsArray=(
        -j "$buildCores"
        -c "${swiftpmBuildConfig-release}"
    )
    concatTo flagsArray swiftpmFlags swiftpmFlagsArray

    echoCmd 'check flags' "${flagsArray[@]}"
    TERM=dumb swift-test "${flagsArray[@]}"

    runHook postCheck
}

if [ -z "${dontUseSwiftpmCheck-}" ] && [ -z "${checkPhase-}" ]; then
    checkPhase=swiftpmCheckPhase
fi

# Helper used to find the binary output path.
# Useful for performing the installPhase of swiftpm packages.
swiftpmBinPath() {
    local flagsArray=(
        -c "${swiftpmBuildConfig-release}"
    )
    concatTo flagsArray swiftpmFlags swiftpmFlagsArray

    swift-build --show-bin-path "${flagsArray[@]}"
}

# TODO: Only use install_name_tool on Darwin, support static libraries
swiftpmInstallPhase() {
    runHook preInstall

    local products=$(swiftpmBinPath)
    while IFS= read -d "" exe; do
        install -D -m 755 "$products/$exe" "${!outputBin}/bin/$exe"
    done < <(swift-package dump-package | @jq@ --raw-output0 '.products[] | select(.type | has("executable")) | .name')

    local libsToInstall=()
    while IFS= read -d "" library; do
        if [ -e "$products/lib$library@sharedLibrary@" ]; then
            install_name_tool "$products/lib$library@sharedLibrary@" \
               -id "${!outputLib}/lib/swift/@swiftPlatform@/lib$library@sharedLibrary@"
            appendToVar libsToInstall "$products/lib$library@sharedLibrary@"
        fi
        if [ -e "$products/$library.swiftmodule" ]; then
            appendToVar libsToInstall "$products/$library.swiftmodule"
        fi
        if [ -e "$products/Modules/$library.swiftmodule" ]; then
           appendToVar libsToInstall "$products/Modules/$library.swiftmodule"
        fi
    done < <(swift-package dump-package | @jq@ --raw-output0 '.products[] | select(.type | has("library")) | .name')
    if [ -n "${libsToInstall}" ]; then
        install -D -t "${!outputLib}/lib/swift/@swiftPlatform@" "${libsToInstall[@]}"
    fi

    runHook postInstall
}

if [ -z "${dontUseSwiftpmInstall-}" ] && [ -z "${installPhase-}" ]; then
    installPhase=swiftpmInstallPhase
fi
