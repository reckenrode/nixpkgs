add_library(SwiftSystem::SystemPackage STATIC IMPORTED)
set_target_properties(SwiftSystem::SystemPackage PROPERTIES
    IMPORTED_LOCATION "@lib@/lib/${CMAKE_STATIC_LIBRARY_PREFIX}SystemPackage${CMAKE_STATIC_LIBRARY_SUFFIX}"
    INTERFACE_INCLUDE_DIRECTORIES "@include@/include;@include@/lib/swift_static/@swiftPlatform@"
)
