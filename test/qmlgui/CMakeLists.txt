find_package(Qt6 REQUIRED COMPONENTS Test)

set(qmlGuiTestFiles
    testformat.cpp
    testsessionfacade.cpp
)

foreach(testFile ${qmlGuiTestFiles})
    get_filename_component(testFilename "${testFile}" NAME_WLE)

    add_executable("${testFilename}" "${testFile}")
    target_link_libraries("${testFilename}" PRIVATE Qt::Test qbt_qmlgui qbt_base)
    add_test(NAME "${testFilename}" COMMAND "${testFilename}")

    add_dependencies(check "${testFilename}")
endforeach()
