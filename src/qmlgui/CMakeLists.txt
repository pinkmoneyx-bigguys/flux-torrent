qt_policy(SET QTP0001 NEW) # default resource prefix is /qt/qml

# QWindowKit: frameless window with native snap, shadow and rounded corners (Qt Quick part only).
# Built static so no extra DLLs ship; its build helper qmsetup comes from the nested git submodule.
set(QWINDOWKIT_BUILD_QUICK ON)
set(QWINDOWKIT_BUILD_WIDGETS OFF)
set(QWINDOWKIT_BUILD_STATIC ON)
set(QWINDOWKIT_ENABLE_STYLE_AGENT OFF)
set(QWINDOWKIT_INSTALL OFF)
add_subdirectory(${PROJECT_SOURCE_DIR}/3rdparty/qwindowkit qwindowkit EXCLUDE_FROM_ALL)

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
set_source_files_properties(qml/shell/TitleBar.qml PROPERTIES QT_RESOURCE_ALIAS shell/TitleBar.qml)
set_source_files_properties(qml/shell/Sidebar.qml PROPERTIES QT_RESOURCE_ALIAS shell/Sidebar.qml)
set_source_files_properties(qml/shell/EmptyPage.qml PROPERTIES QT_RESOURCE_ALIAS shell/EmptyPage.qml)
set_source_files_properties(qml/firstrun/FirstRunWindow.qml PROPERTIES QT_RESOURCE_ALIAS firstrun/FirstRunWindow.qml)
set_source_files_properties(qml/pages/TransfersPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/TransfersPage.qml)
set_source_files_properties(qml/pages/SearchPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/SearchPage.qml)
set_source_files_properties(qml/pages/RssPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/RssPage.qml)
set_source_files_properties(qml/pages/MediaPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/MediaPage.qml)
set_source_files_properties(qml/pages/SettingsPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/SettingsPage.qml)

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
        qml/shell/TitleBar.qml
        qml/shell/Sidebar.qml
        qml/shell/EmptyPage.qml
        qml/firstrun/FirstRunWindow.qml
        qml/pages/TransfersPage.qml
        qml/pages/SearchPage.qml
        qml/pages/RssPage.qml
        qml/pages/MediaPage.qml
        qml/pages/SettingsPage.qml
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
        migration/firstrun.h
        migration/firstrun.cpp
        migration/profilemigrator.h
        migration/profilemigrator.cpp
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
        QWindowKit::Quick
    PRIVATE
        qbt_base
)

# qmltyperegistrations includes QML_ELEMENT headers by file name only
target_include_directories(qbt_qmlgui PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/backend")

# English source strings in QML (qsTr), Russian in i18n/flux_ru.ts. The .qm files are embedded under
# :/i18n and FluxShell installs the one that matches the system locale.
# After changing UI strings refresh the .ts with: cmake --build build --target flux_lupdate
find_package(Qt6 REQUIRED COMPONENTS LinguistTools)
qt_add_translations(qbt_qmlgui
    TS_FILES i18n/flux_ru.ts
    SOURCE_TARGETS qbt_qmlgui
    LUPDATE_TARGET flux_lupdate
    LRELEASE_TARGET flux_lrelease
    LUPDATE_OPTIONS -no-obsolete -locations none
)
