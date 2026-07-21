# Boost filesystem link fix. RBDyn's CMakeLists calls
# add_project_dependency(Boost REQUIRED) with no COMPONENTS ("technically we
# don't need filesystem but it is likely to be here" -- true with the old
# FindBoost module, false with Boost 1.83's own CMake config package, which no
# longer pulls filesystem in transitively). RBDyn::Parsers uses
# boost::filesystem internally, so the undefined symbols only surface at
# mc_mujoco's final link.
#
# It has to go through CMAKE_CXX_STANDARD_LIBRARIES, not CMAKE_*_LINKER_FLAGS:
# those insert *before* the object files on the link line, where GNU ld has
# nothing needing the symbols yet, so -lboost_filesystem there is a silent
# no-op. CMAKE_CXX_STANDARD_LIBRARIES is appended at the very end, which
# actually resolves them. Verified in a fresh container.
AddProject(mc_mujoco
  GITHUB mathieu-celerier/mc_mujoco
  GIT_TAG 8934988254b8a297f6eaadb02a94be63671b4d11 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
  CMAKE_ARGS -DCMAKE_CXX_STANDARD_LIBRARIES=-lboost_filesystem
  # X11 headers required by vendored glfw
  APT_DEPENDENCIES libxinerama-dev libxrandr-dev libxcursor-dev libxi-dev
)
