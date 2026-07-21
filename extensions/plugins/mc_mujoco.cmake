# boost::filesystem isn't declared as a Boost component anywhere in the
# dependency chain, so mc_mujoco fails to link against it. CMAKE_*_LINKER_FLAGS
# inserts too early in the link line to fix this (order matters to ld);
# CMAKE_CXX_STANDARD_LIBRARIES is appended at the very end instead.
AddProject(mc_mujoco
  GITHUB mathieu-celerier/mc_mujoco
  GIT_TAG 8934988254b8a297f6eaadb02a94be63671b4d11 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
  CMAKE_ARGS -DCMAKE_CXX_STANDARD_LIBRARIES=-lboost_filesystem
  # X11 headers required by vendored glfw
  APT_DEPENDENCIES libxinerama-dev libxrandr-dev libxcursor-dev libxi-dev
)
