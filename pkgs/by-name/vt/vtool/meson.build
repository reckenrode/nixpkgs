# Build settings based on the upstream Xcode project.
# See: https://github.com/apple-oss-distributions/cctools/blob/main/cctools.xcodeproj/project.pbxproj

# Project settings
project(
    'cctools',
    'c',
    version : '@version@',
    default_options : {
        'c_args': [
            '-DCCTB_MACOS=YES',
            '-DCCTB_PROJECT=cctools',
            '-DCCTB_PROJVERS=cctools-@version@',
            '-DCCTB_VERSION=@version@',
            '-DCURRENT_PROJECT_VERSION="cctools-@version@"',
            '-DCODEDIRECTORY_SUPPORT',
            '-DLTO_SUPPORT',
        ],
    },
)


# Dependencies
cc = meson.get_compiler('c')

incdirs = include_directories('include')

# Static libraries
libstuff = static_library(
    'stuff',
    c_args : [
        '-DCPU_TYPE_RISCV32=24', # Per src/abstraction/MachOFileAbstraction.hpp from ld64
    ],
    include_directories : [incdirs, 'include/stuff'],
    sources : [
        'libstuff/SymLoc.c',
        'libstuff/align.c',
        'libstuff/allocate.c',
        'libstuff/apple_version.c',
        'libstuff/arch.c',
        'libstuff/arch_usage.c',
        'libstuff/args.c',
        'libstuff/best_arch.c',
        'libstuff/breakout.c',
        'libstuff/bytesex.c',
        'libstuff/checkout.c',
        'libstuff/code_directory.c',
        'libstuff/coff_bytesex.c',
        'libstuff/crc32.c',
        'libstuff/depinfo.c',
        'libstuff/diagnostics.c',
        'libstuff/dylib_roots.c',
        'libstuff/dylib_table.c',
        'libstuff/errors.c',
        'libstuff/execute.c',
        'libstuff/fatal_arch.c',
        'libstuff/fatals.c',
        'libstuff/get_arch_from_host.c',
        'libstuff/get_toc_byte_sex.c',
        'libstuff/guess_short_name.c',
        'libstuff/hash_string.c',
        'libstuff/hppa.c',
        'libstuff/llvm.c',
        'libstuff/lto.c',
        'libstuff/macosx_deployment_target.c',
        'libstuff/ofile.c',
        'libstuff/ofile_error.c',
        'libstuff/ofile_get_word.c',
        'libstuff/print.c',
        'libstuff/reloc.c',
        'libstuff/rnd.c',
        'libstuff/seg_addr_table.c',
        'libstuff/set_arch_flag_name.c',
        'libstuff/swap_headers.c',
        'libstuff/symbol_list.c',
        'libstuff/unix_standard_mode.c',
        'libstuff/version_number.c',
        'libstuff/vm_flush_cache.c',
        'libstuff/write64.c',
        'libstuff/writeout.c',
        'libstuff/xcode.c',
    ],
)

# Binaries
vtool = executable(
    f'vtool',
    dependencies : [libcodedirectory],
    include_directories : [incdirs, 'include/stuff'],
    install : true,
    link_with : [libstuff],
    sources : ['misc/vtool.c'],
)
install_man('man/vtool.1')
