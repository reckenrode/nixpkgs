set(SyntaxModules
    SwiftBasicFormat
    SwiftCompilerPluginMessageHandling
    SwiftDiagnostics
    SwiftIDEUtils
    SwiftIfConfig
    SwiftLexicalLookup
    SwiftOperators
    SwiftParser
    SwiftParserDiagnostics
    SwiftSyntax
    SwiftSyntaxBuilder
    SwiftSyntaxMacroExpansion
    SwiftSyntaxMacros
)

foreach(SyntaxModule ${SyntaxModules})
    add_library(SwiftSyntax::${SyntaxModule} @buildType@ IMPORTED)
    set_target_properties(SwiftSyntax::${SyntaxModule} PROPERTIES
        IMPORTED_LOCATION "@lib@/lib/${CMAKE_@buildType@_LIBRARY_PREFIX}${SyntaxModule}${CMAKE_@buildType@_LIBRARY_SUFFIX}"
        INTERFACE_INCLUDE_DIRECTORIES "@include@/lib/swift/host"
    )
endforeach()
