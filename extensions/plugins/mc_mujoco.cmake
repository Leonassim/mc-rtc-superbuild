# boost_filesystem force-link hack removed then restored (2026-07-27):
# mc_rtc itself did migrate path.cpp/path.h to std::filesystem, but mc_mujoco
# has its own, separate boost::filesystem usage (src/mj_utils.cpp,
# src/mj_sim.cpp: `#include <boost/filesystem.hpp>`, `namespace bfs =
# boost::filesystem`) -- missed the first time because GitHub's code search
# API doesn't reliably match tokens containing `::`, and a repo-wide search
# for "boost::filesystem" came back empty; grepping the actual fetched
# source proved otherwise (undefined reference to
# boost::filesystem::detail::dir_itr_imp at final link on a fresh noble
# build). boost::filesystem isn't declared as a Boost component anywhere in
# the dependency chain, so the fix is the same as before:
# CMAKE_CXX_STANDARD_LIBRARIES appended at the very end of the link line.
AddProject(mc_mujoco
  GITHUB mathieu-celerier/mc_mujoco
  GIT_TAG 8934988254b8a297f6eaadb02a94be63671b4d11 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
  # BUILD_EXAMPLES=OFF (2026-07-27): mc_mujoco's bundled SampleNeckPolicy
  # example fails to compile on a fresh noble build; unrelated to RHPS1 /
  # rl_controller, which don't depend on it.
  CMAKE_ARGS -DBUILD_EXAMPLES=OFF -DCMAKE_CXX_STANDARD_LIBRARIES=-lboost_filesystem
  # X11 headers required by vendored glfw
  APT_DEPENDENCIES libxinerama-dev libxrandr-dev libxcursor-dev libxi-dev
)
