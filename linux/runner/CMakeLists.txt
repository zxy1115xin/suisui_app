cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# 定义应用目标。若要修改名称，请修改顶层 CMakeLists.txt 中的 BINARY_NAME，
# 不要在这里直接改，否则 `flutter run` 将无法正常工作。
#
# 任何新增的源文件都应添加到这里。
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# 应用标准构建设置。若应用需要不同的构建配置，可以移除这一项。
apply_standard_settings(${BINARY_NAME})

# 为应用 ID 添加预处理器定义。
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# 添加依赖库。任何应用特定的依赖都可以写在这里。
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
