# RHPS1 low-level stack: what the real robot needs on top of mc_rtc.
#
# OFF by default, and deliberately so. Turning it on pulls the whole
# choreonoid / OpenRTM / hrpsys chain through drcutil-superbuild -- an hour of
# build and an SSH key for isri-aist -- neither of which the mc_mujoco
# workflow, this repo's CI, or a workstation checkout has any use for.
#
#   cmake --preset relwithdebinfo-noble -DWITH_RHPS1_HARDWARE=ON
option(WITH_RHPS1_HARDWARE "Build the RHPS1 low-level stack (choreonoid, OpenRTM, hrpsys)" OFF)

if(WITH_RHPS1_HARDWARE)
  # RequireExtension clones into extensions/<name> if it is not already there,
  # then adds it -- so a fresh clone of this repo reproduces the stack without
  # anyone remembering a manual `git clone` into extensions/. It is idempotent
  # (AddExtension tracks what it has added), so an existing checkout is used
  # as-is and never re-fetched.
  #
  # Pinned, like every other dependency here: topic/ec-master3.2 is a moving
  # branch, and the whole point of this branch is that a checkout reproduces a
  # known state. drcutil-superbuild keys off the hostname -- rhps1c is in its
  # KNOWN_ROBOTS_WITH_IOB_V2 list, which is what sets INTERNAL_MACHINE and
  # ROBOT_IOB_VERSION=2 on the real PPC.
  RequireExtension(drcutil-superbuild
    GIT_REPOSITORY git@github.com:isri-aist/drcutil-superbuild.git
    GIT_TAG d8fa6ce0201ac3b4c8c581b668e1eb3f90f704f6 # pinned 2026-07-31, was origin/topic/ec-master3.2
  )

  # The RHPS1 hrpsys/choreonoid bridge. Lands in SOURCE_DESTINATION
  # (workspace/devel) like every other AddProject.
  #
  # DEPENDS are its actual build dependencies, read from its CMakeLists:
  # find_package(OpenHRP), pkg_check_modules(hrpsys-base),
  # find_package(mc_rtc), find_package(choreonoid). All three of the low-level
  # ones are declared by drcutil-superbuild, which RequireExtension above has
  # already added by the time we get here.
  AddProject(hrpcnoid_rhps1
    GITHUB ThomasDuvinage/hrpcnoid_rhps1
    GIT_TAG 7a6da6984a42bd40395cf0d28b04a3403345c4fa # pinned 2026-07-31, was origin/ubuntu2204
    DEPENDS mc_rtc openhrp3 hrpsys-base choreonoid
  )
endif()
