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
set_source_files_properties(qml/controls/Surface.qml PROPERTIES QT_RESOURCE_ALIAS controls/Surface.qml)
set_source_files_properties(qml/controls/PageHeader.qml PROPERTIES QT_RESOURCE_ALIAS controls/PageHeader.qml)
set_source_files_properties(qml/glass/GlassBackground.qml PROPERTIES QT_RESOURCE_ALIAS glass/GlassBackground.qml)
set_source_files_properties(qml/glass/GlassPanel.qml PROPERTIES QT_RESOURCE_ALIAS glass/GlassPanel.qml)
set_source_files_properties(qml/shell/TitleBar.qml PROPERTIES QT_RESOURCE_ALIAS shell/TitleBar.qml)
set_source_files_properties(qml/shell/Sidebar.qml PROPERTIES QT_RESOURCE_ALIAS shell/Sidebar.qml)
set_source_files_properties(qml/shell/EmptyPage.qml PROPERTIES QT_RESOURCE_ALIAS shell/EmptyPage.qml)
set_source_files_properties(qml/shell/CommandPalette.qml PROPERTIES QT_RESOURCE_ALIAS shell/CommandPalette.qml)
set_source_files_properties(qml/firstrun/FirstRunWindow.qml PROPERTIES QT_RESOURCE_ALIAS firstrun/FirstRunWindow.qml)
set_source_files_properties(qml/pages/TransfersPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/TransfersPage.qml)
set_source_files_properties(qml/pages/SearchPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/SearchPage.qml)
set_source_files_properties(qml/pages/RssPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/RssPage.qml)
set_source_files_properties(qml/pages/MediaPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/MediaPage.qml)
set_source_files_properties(qml/pages/SettingsPage.qml PROPERTIES QT_RESOURCE_ALIAS pages/SettingsPage.qml)
set_source_files_properties(qml/ui/UiButton.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiButton.qml)
set_source_files_properties(qml/ui/UiBadge.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiBadge.qml)
set_source_files_properties(qml/ui/UiCheckBox.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiCheckBox.qml)
set_source_files_properties(qml/ui/UiTabs.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiTabs.qml)
set_source_files_properties(qml/ui/UiInput.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiInput.qml)
set_source_files_properties(qml/ui/UiProgress.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiProgress.qml)
set_source_files_properties(qml/ui/UiMenu.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiMenu.qml)
set_source_files_properties(qml/ui/UiMenuItem.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiMenuItem.qml)
set_source_files_properties(qml/ui/UiMenuSeparator.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiMenuSeparator.qml)
set_source_files_properties(qml/ui/UiDialog.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiDialog.qml)
set_source_files_properties(qml/pages/transfers/TorrentStatus.qml PROPERTIES QT_RESOURCE_ALIAS pages/transfers/TorrentStatus.qml)
set_source_files_properties(qml/pages/transfers/TransfersState.qml PROPERTIES QT_RESOURCE_ALIAS pages/transfers/TransfersState.qml)
set_source_files_properties(qml/pages/transfers/TorrentDetailsPane.qml PROPERTIES QT_RESOURCE_ALIAS pages/transfers/TorrentDetailsPane.qml)
set_source_files_properties(qml/pages/transfers/AddTorrentDialog.qml PROPERTIES QT_RESOURCE_ALIAS pages/transfers/AddTorrentDialog.qml)
set_source_files_properties(qml/ui/UiSwitch.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiSwitch.qml)
set_source_files_properties(qml/ui/UiSelect.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiSelect.qml)
set_source_files_properties(qml/ui/UiSpinner.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiSpinner.qml)
set_source_files_properties(qml/ui/UiToast.qml PROPERTIES QT_RESOURCE_ALIAS ui/UiToast.qml)
set_source_files_properties(qml/pages/search/PluginsDialog.qml PROPERTIES QT_RESOURCE_ALIAS pages/search/PluginsDialog.qml)
set_source_files_properties(qml/pages/rss/RulesDialog.qml PROPERTIES QT_RESOURCE_ALIAS pages/rss/RulesDialog.qml)
set_source_files_properties(qml/pages/settings/SettingRow.qml PROPERTIES QT_RESOURCE_ALIAS pages/settings/SettingRow.qml)
set_source_files_properties(qml/pages/settings/SettingsGroup.qml PROPERTIES QT_RESOURCE_ALIAS pages/settings/SettingsGroup.qml)
set_source_files_properties(qml/pages/settings/ThemePicker.qml PROPERTIES QT_RESOURCE_ALIAS pages/settings/ThemePicker.qml)

# Singletons must be flagged before qt_add_qml_module sees the files
set_source_files_properties(qml/Theme.qml qml/Icons.qml qml/pages/transfers/TorrentStatus.qml
    qml/pages/transfers/TransfersState.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

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
        qml/controls/Surface.qml
        qml/controls/PageHeader.qml
        qml/glass/GlassBackground.qml
        qml/glass/GlassPanel.qml
        qml/shell/TitleBar.qml
        qml/shell/Sidebar.qml
        qml/shell/EmptyPage.qml
        qml/shell/CommandPalette.qml
        qml/firstrun/FirstRunWindow.qml
        qml/pages/TransfersPage.qml
        qml/pages/SearchPage.qml
        qml/pages/RssPage.qml
        qml/pages/MediaPage.qml
        qml/pages/SettingsPage.qml
        qml/ui/UiButton.qml
        qml/ui/UiBadge.qml
        qml/ui/UiCheckBox.qml
        qml/ui/UiTabs.qml
        qml/ui/UiInput.qml
        qml/ui/UiProgress.qml
        qml/ui/UiMenu.qml
        qml/ui/UiMenuItem.qml
        qml/ui/UiMenuSeparator.qml
        qml/ui/UiDialog.qml
        qml/pages/transfers/TorrentStatus.qml
        qml/pages/transfers/TransfersState.qml
        qml/pages/transfers/TorrentDetailsPane.qml
        qml/pages/transfers/AddTorrentDialog.qml
        qml/ui/UiSwitch.qml
        qml/ui/UiSelect.qml
        qml/ui/UiSpinner.qml
        qml/ui/UiToast.qml
        qml/pages/search/PluginsDialog.qml
        qml/pages/rss/RulesDialog.qml
        qml/pages/settings/SettingRow.qml
        qml/pages/settings/SettingsGroup.qml
        qml/pages/settings/ThemePicker.qml
    RESOURCES
        fonts/Onest-Variable.ttf
        fonts/Unbounded-Variable.ttf
        fonts/JetBrainsMono-Variable.ttf
        fonts/Geist-Variable.ttf
        fonts/GeistMono-Variable.ttf
        fonts/OFL-Geist.txt
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
        backend/uisettings.h
        backend/uisettings.cpp
        backend/torrentlistmodel.h
        backend/torrentlistmodel.cpp
        backend/torrentfiltermodel.h
        backend/torrentfiltermodel.cpp
        backend/torrentdetails.h
        backend/torrentdetails.cpp
        backend/searchresults.h
        backend/searchresults.cpp
        backend/searchengine.h
        backend/searchengine.cpp
        backend/rssmanager.h
        backend/rssmanager.cpp
        backend/medialibrary.h
        backend/medialibrary.cpp
        backend/appsettings.h
        backend/appsettings.cpp
        backend/addtorrentdraft.h
        backend/addtorrentdraft.cpp
        streaming/streamplanner.h
        streaming/streamplanner.cpp
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
