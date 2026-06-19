cmake_minimum_required(VERSION 3.16)

project(qt_client VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network QuickControls2)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appqt_client
    main.cpp
    avataruploader.h
    avataruploader.cpp
)

qt_add_qml_module(appqt_client
    URI qt_client
    QML_FILES
        Main.qml
        QML_FILES LoginPage.qml
        RESOURCES resource.qrc
        QML_FILES RegisterPage.qml
        QML_FILES ChatPage.qml
        QML_FILES ResetPage.qml
        # SOURCES avataruploader.h avataruploader.cpp
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appqt_client PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appqt_client
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appqt_client
    PRIVATE Qt6::Quick Qt6::Network Qt6::QuickControls2
)

include(GNUInstallDirs)
install(TARGETS appqt_client
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
