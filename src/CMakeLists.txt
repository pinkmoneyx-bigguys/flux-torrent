include_directories(${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(app)
add_subdirectory(base)

if (GUI)
    add_subdirectory(gui)
endif()

if (QML_GUI)
    add_subdirectory(qmlgui)
endif()

if (WEBUI)
    add_subdirectory(webui)
endif()
