cmake_minimum_required(VERSION 3.25)
project(albench_cpp CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(include)

find_package(Threads REQUIRED)

add_executable(server src/main.cpp)
target_link_libraries(server PRIVATE Threads::Threads)

enable_testing()
add_executable(server_test tests/server_test.cpp)
target_link_libraries(server_test PRIVATE Threads::Threads)
add_test(NAME server_test COMMAND server_test)
