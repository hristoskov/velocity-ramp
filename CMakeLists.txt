
cmake_minimum_required(VERSION 3.12)

project(velocity_ramp_controller_Project LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)

enable_testing()

add_definitions(-DCPPHTTPLIB_OPENSSL_SUPPORT)

include_directories(dependencies/include)
link_directories(dependencies/lib)

file(GLOB SOURCE_FILES "*.c")

add_executable(velocity_ramp_controller ${SOURCE_FILES})
set_target_properties(velocity_ramp_controller PROPERTIES LINKER_LANGUAGE CXX)
if (WIN32)
    target_link_libraries(velocity_ramp_controller CppModelBase ixwebsocket crypto ssl z crypt32 ws2_32)
else()
    target_link_libraries(velocity_ramp_controller CppModelBase ixwebsocket crypto ssl z)
endif()

add_test(NAME velocity_ramp_controller_Test COMMAND velocity_ramp_controller)

