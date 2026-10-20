find_package(Qt6 REQUIRED COMPONENTS Test QuickTest)

set(qmlGuiTestFiles
    testformat.cpp
    testpreferences.cpp
    testprofilemigrator.cpp
    testsessionfacade.cpp
    testsystemprefs.cpp
    teststreamplanner.cpp
    teststreamstatestore.cpp
    testhttprange.cpp
    teststreamserver.cpp
    testwatchhistory.cpp
)

foreach(testFile ${qmlGuiTestFiles})
    get_filename_component(testFilename "${testFile}" NAME_WLE)

    add_executable("${testFilename}" "${testFile}")
    target_link_libraries("${testFilename}" PRIVATE Qt::Test qbt_qmlgui qbt_base)
    add_test(NAME "${testFilename}" COMMAND "${testFilename}")

    add_dependencies(check "${testFilename}")
endforeach()

# The first-run flow end to end: real dialog on the offscreen platform, a throw-away profile
add_executable(testfirstrun testfirstrun.cpp)
target_link_libraries(testfirstrun PRIVATE Qt::Test Qt6::Quick qbt_qmlgui qbt_qmlguiplugin qbt_base)
add_test(NAME testfirstrun COMMAND testfirstrun)
add_dependencies(check testfirstrun)

# FluxShell's load-failure reporting, on the offscreen platform (no window is ever created)
add_executable(testfluxshell testfluxshell.cpp)
target_link_libraries(testfluxshell PRIVATE Qt::Test Qt6::Quick qbt_qmlgui qbt_qmlguiplugin qbt_base)
add_test(NAME testfluxshell COMMAND testfluxshell)
add_dependencies(check testfluxshell)

# Qt Quick Test: runs every tst_*.qml under qml/ (later QML tasks add their files there)
add_executable(flux_qml qmltests.cpp)
target_compile_definitions(flux_qml PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
target_link_libraries(flux_qml PRIVATE Qt6::QuickTest qbt_qmlgui qbt_qmlguiplugin qbt_base)
add_test(NAME flux_qml COMMAND flux_qml)
# Opens real, visible windows on the desktop: excluded by `ctest -LE gui` (scripts/build.ps1 -Test), run
# with -GuiTests. Tests on the offscreen platform (testfirstrun, testfluxshell) do not need the label.
set_tests_properties(flux_qml PROPERTIES LABELS gui)
add_dependencies(check flux_qml)
