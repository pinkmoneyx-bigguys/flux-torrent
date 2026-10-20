include_directories(${CMAKE_CURRENT_SOURCE_DIR})

if (QML_GUI)
    # Flux's own version (releases are tagged v<version>) and the GitHub repository its releases are
    # published in: the executable's version info, About and the update check use them
    set(FLUX_VERSION "0.1.0" CACHE STRING "Flux version")
    set(FLUX_GITHUB_REPO "pinkmoneyx-bigguys/flux-torrent" CACHE STRING "GitHub repository of Flux releases (owner/name)")
endif()

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
