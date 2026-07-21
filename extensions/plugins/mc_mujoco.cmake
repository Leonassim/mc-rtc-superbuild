# Boost filesystem link flags (2026-07-22, Léo): RBDyn's CMakeLists calls
# add_project_dependency(Boost REQUIRED) with no COMPONENTS ("technically we
# don't need filesystem but it is likely to be here" -- a comment that held
# with the old FindBoost module but not with Boost 1.83's own CMake config
# package, which no longer pulls filesystem in transitively). RBDyn::Parsers
# uses boost::filesystem internally, so the undefined symbols only surface
# at mc_mujoco's final link. Forcing the link explicitly here rather than
# patching RBDyn upstream.
AddProject(mc_mujoco
  GITHUB mathieu-celerier/mc_mujoco
  GIT_TAG 8934988254b8a297f6eaadb02a94be63671b4d11 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
  CMAKE_ARGS -DCMAKE_EXE_LINKER_FLAGS=-lboost_filesystem
             -DCMAKE_SHARED_LINKER_FLAGS=-lboost_filesystem
             -DCMAKE_MODULE_LINKER_FLAGS=-lboost_filesystem
)
