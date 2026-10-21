# Flux's setup for Windows (see scripts/release.ps1):
#   flux_setup_stub  the setup's first stage: no dependencies (static runtime); unpacks what fluxpack put after it
#   fluxpack         makes the setup: the stub, then the deployed Flux packed (payload.h)
#   FluxSetup        the setup's interface, in Flux's look; it runs on Flux's own Qt from the unpacked files,
#                    and stays in the installed folder as the uninstaller

string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" FLUX_VERSION_MATCH "${FLUX_VERSION}")
set(FLUX_VERSION_MAJOR ${CMAKE_MATCH_1})
set(FLUX_VERSION_MINOR ${CMAKE_MATCH_2})
set(FLUX_VERSION_PATCH ${CMAKE_MATCH_3})
set(FLUX_ICON "${PROJECT_SOURCE_DIR}/src/icons/flux.ico")

# ---- fluxpack
add_executable(fluxpack fluxpack.cpp payload.h)
target_compile_definitions(fluxpack PRIVATE UNICODE _UNICODE)
target_link_libraries(fluxpack PRIVATE Cabinet)

# ---- the stub
set(FLUX_INTERNAL_NAME "FluxSetupStub")
set(FLUX_MANIFEST_RESOURCE "1 24 \"${CMAKE_CURRENT_SOURCE_DIR}/stub.manifest\"")
configure_file(installer.rc.in "${CMAKE_CURRENT_BINARY_DIR}/stub.rc" @ONLY)
add_executable(flux_setup_stub WIN32 stub.cpp payload.h "${CMAKE_CURRENT_BINARY_DIR}/stub.rc")
set_property(TARGET flux_setup_stub PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded")
target_compile_definitions(flux_setup_stub PRIVATE UNICODE _UNICODE)
# the manifest is our own (stub.manifest): per-user, no administrator rights
target_link_options(flux_setup_stub PRIVATE /MANIFEST:NO)
target_link_libraries(flux_setup_stub PRIVATE Cabinet Gdiplus Dwmapi Shell32 Ole32 User32)

# ---- the interface
qt_policy(SET QTP0001 NEW) # the module under /qt/qml, where the engine looks
set(FLUX_INTERNAL_NAME "FluxSetup")
set(FLUX_MANIFEST_RESOURCE "")
configure_file(installer.rc.in "${CMAKE_CURRENT_BINARY_DIR}/setup.rc" @ONLY)
qt_add_executable(FluxSetup WIN32 ui/main.cpp "${CMAKE_CURRENT_BINARY_DIR}/setup.rc")
set_source_files_properties(ui/qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(ui/qml/Strings.js PROPERTIES QT_RESOURCE_ALIAS Strings.js)
qt_add_qml_module(FluxSetup
    URI FluxSetup
    VERSION 1.0
    QML_FILES ui/qml/Main.qml ui/qml/Strings.js
    SOURCES ui/setup.cpp ui/setup.h
)
qt_add_resources(FluxSetup "fluxsetup_fonts"
    PREFIX "/fluxsetup/fonts"
    BASE "${PROJECT_SOURCE_DIR}/src/qmlgui/fonts"
    FILES
        "${PROJECT_SOURCE_DIR}/src/qmlgui/fonts/Geist-Variable.ttf"
        "${PROJECT_SOURCE_DIR}/src/qmlgui/fonts/GeistMono-Variable.ttf"
)
target_include_directories(FluxSetup PRIVATE ui)
target_compile_definitions(FluxSetup PRIVATE
    UNICODE _UNICODE
    FLUX_VERSION="${FLUX_VERSION}"
    FLUX_GITHUB_REPO="${FLUX_GITHUB_REPO}"
)
target_link_libraries(FluxSetup PRIVATE Qt6::Quick Qt6::Qml QWindowKit::Quick Shell32 Ole32 Advapi32 Uuid)
# the MSVC manifest asks for no administrator rights (a name with "setup" would otherwise make Windows ask)
target_link_options(FluxSetup PRIVATE "/MANIFESTUAC:level='asInvoker' uiAccess='false'")

# these do not take the project's common flags (qbt_common_cfg): their own standard and source encoding
foreach(target fluxpack flux_setup_stub FluxSetup)
    target_compile_features(${target} PRIVATE cxx_std_20)
    target_compile_options(${target} PRIVATE /utf-8 /W3)
endforeach()
