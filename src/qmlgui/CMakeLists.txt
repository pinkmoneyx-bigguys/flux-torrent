qt_policy(SET QTP0001 NEW) # default resource prefix is /qt/qml

# Main.qml is addressed as Flux/Main, not Flux/qml/Main
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(qml/Theme.qml PROPERTIES QT_RESOURCE_ALIAS Theme.qml)
set_source_files_properties(qml/Icons.qml PROPERTIES QT_RESOURCE_ALIAS Icons.qml)
set_source_files_properties(qml/controls/Icon.qml PROPERTIES QT_RESOURCE_ALIAS controls/Icon.qml)
set_source_files_properties(qml/controls/GlowHalo.qml PROPERTIES QT_RESOURCE_ALIAS controls/GlowHalo.qml)
set_source_files_properties(qml/controls/PillButton.qml PROPERTIES QT_RESOURCE_ALIAS controls/PillButton.qml)
set_source_files_properties(qml/controls/IconButton.qml PROPERTIES QT_RESOURCE_ALIAS controls/IconButton.qml)
set_source_files_properties(qml/controls/GlassSwitch.qml PROPERTIES QT_RESOURCE_ALIAS controls/GlassSwitch.qml)
set_source_files_properties(qml/controls/GlassCheckBox.qml PROPERTIES QT_RESOURCE_ALIAS controls/GlassCheckBox.qml)
set_source_files_properties(qml/controls/SegmentedControl.qml PROPERTIES QT_RESOURCE_ALIAS controls/SegmentedControl.qml)
set_source_files_properties(qml/controls/FluxProgressBar.qml PROPERTIES QT_RESOURCE_ALIAS controls/FluxProgressBar.qml)
set_source_files_properties(qml/controls/Toast.qml PROPERTIES QT_RESOURCE_ALIAS controls/Toast.qml)
set_source_files_properties(qml/glass/GlassBackground.qml PROPERTIES QT_RESOURCE_ALIAS glass/GlassBackground.qml)
set_source_files_properties(qml/glass/GlassPanel.qml PROPERTIES QT_RESOURCE_ALIAS glass/GlassPanel.qml)

# Singletons must be flagged before qt_add_qml_module sees the files
set_source_files_properties(qml/Theme.qml qml/Icons.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(qbt_qmlgui STATIC)

qt_add_qml_module(qbt_qmlgui
    URI Flux
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Flux"
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Icons.qml
        qml/controls/Icon.qml
        qml/controls/GlowHalo.qml
        qml/controls/PillButton.qml
        qml/controls/IconButton.qml
        qml/controls/GlassSwitch.qml
        qml/controls/GlassCheckBox.qml
        qml/controls/SegmentedControl.qml
        qml/controls/FluxProgressBar.qml
        qml/controls/Toast.qml
        qml/glass/GlassBackground.qml
        qml/glass/GlassPanel.qml
    RESOURCES
        fonts/Onest-Variable.ttf
        fonts/Unbounded-Variable.ttf
        fonts/JetBrainsMono-Variable.ttf
        fonts/OFL.txt
    SOURCES
        fluxshell.h
        fluxshell.cpp
        backend/format.h
        backend/format.cpp
        backend/sessionfacade.h
        backend/sessionfacade.cpp
        backend/systemprefs.h
        backend/systemprefs.cpp
)

# Compiled to .qsb for every RHI backend, served as qrc:/flux/shaders/glass.frag.qsb
qt_add_shaders(qbt_qmlgui "flux_shaders"
    PREFIX "/flux"
    FILES
        shaders/glass.frag
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
