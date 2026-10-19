qt_policy(SET QTP0001 NEW) # default resource prefix is /qt/qml

# Main.qml is addressed as Flux/Main, not Flux/qml/Main
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)

qt_add_library(qbt_qmlgui STATIC)

qt_add_qml_module(qbt_qmlgui
    URI Flux
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Flux"
    QML_FILES
        qml/Main.qml
    SOURCES
        fluxshell.h
        fluxshell.cpp
        backend/format.h
        backend/format.cpp
)

target_link_libraries(qbt_qmlgui
    PUBLIC
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
    PRIVATE
        qbt_base
)

# qmltyperegistrations includes QML_ELEMENT headers by file name only
target_include_directories(qbt_qmlgui PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/backend")
