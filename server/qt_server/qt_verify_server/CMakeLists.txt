cmake_minimum_required(VERSION 3.19)
project(qt_verify_server LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core LinguistTools Network HttpServer Sql)

qt_standard_project_setup()

qt_add_executable(qt_verify_server
    main.cpp
    smtpclient.h smtpclient.cpp
    verifyserver.h verifyserver.cpp
    registeruser.h registeruser.cpp
    chatserver.h chatserver.cpp

)

qt_add_translations(
    TARGETS qt_verify_server
    TS_FILES qt_verify_server_zh_CN.ts
)

target_link_libraries(qt_verify_server
    PRIVATE
        Qt6::Core
        Qt6::Network
        Qt6::HttpServer
        Qt6::Sql
)

include(GNUInstallDirs)
install(TARGETS qt_verify_server
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)