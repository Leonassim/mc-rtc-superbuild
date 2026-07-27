# boost_filesystem force-link hack removed (2026-07-27 bastien/main merge):
# mc_rtc migrated src/mc_rtc/path.cpp + path.h from boost::filesystem to
# std::filesystem (verified by source inspection -- zero boost::filesystem
# hits left in a repo-wide code search). RBDyn only touches
# boost::filesystem in its own tests/CMakeLists.txt, not its public
# interface, and mc_mujoco doesn't use it directly either. Nothing left in
# the dependency chain that needs it force-linked. CI will confirm.
AddProject(mc_mujoco
  GITHUB mathieu-celerier/mc_mujoco
  GIT_TAG 8934988254b8a297f6eaadb02a94be63671b4d11 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
  # X11 headers required by vendored glfw
  APT_DEPENDENCIES libxinerama-dev libxrandr-dev libxcursor-dev libxi-dev
)
