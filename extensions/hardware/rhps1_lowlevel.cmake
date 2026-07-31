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

  # The OpenHRP VRML model. drcutil-superbuild ships HRP2/HRP2KAI/HRP4CR/HRP5P
  # but nothing for RHPS1, so without this nobody installs
  # share/OpenHRP-3.1/robot/RHPS1/model/ and RobotHardware dies at startup on
  #
  #   ModelLoaderException: .../RHPS1main_sake_sake.wrl cannot be found
  #   VRML and IOB are inconsistent: joints 0(VRML), 42(IOB)
  #
  # The doubled "sake" is not a typo: models are named
  # RHPS1main_<right_ee>_<left_ee>, and hrpcnoid_rhps1 hardcodes
  # RHPS1_MODEL_NAME = RHPS1main_sake_sake. The concrete .wrl is not in the
  # repo either -- it is configure_file'd from RHPS1main_tool.wrl.in for every
  # pair in EE_TYPES (sake sake2 wrench plate plug leap) and installed to
  # share/OpenHRP-3.1/robot/RHPS1.
  #
  # SUBFOLDER openhrp and SKIP_TEST mirror how drcutil declares HRP5P.
  AddProject(RHPS1
    GITHUB_PRIVATE isri-aist/RHPS1
    GIT_TAG 45050f31f1dc1d50dbf3cf1d67d0832075bfd7f3 # pinned 2026-07-31, was origin/master
    SUBFOLDER openhrp
    SKIP_TEST
  )

  # The RHPS1 RTC components: AngleToCylinder / CylinderToAngle, the conversion
  # between joint angles and the crotch/ankle parallel-cylinder mechanism.
  # Missing from drcutil too, which is why nocnoid.py died on
  #
  #   [nocnoid.py] FATAL ERROR: CylinderToAngle cannot be created
  #
  # hrpcnoid_rhps1 only *uses* these components (ms.load("CylinderToAngle")) and
  # ships their calibration tables; nothing in the declared set built them.
  #
  # openrtm2, not master: it is the branch that matches the rest of this stack
  # (hrpsys-base is on ubuntu2204+rtm2, hrpcnoid_rhps1 on ubuntu2204), and it
  # is what the PPC's working tree was actually checked out on.
  AddProject(hrpsys-rhps1
    GITHUB_PRIVATE isri-aist/hrpsys-rhps1
    GIT_TAG c6f5d19c987073efcd17aff7d91f8029ed193ed4 # pinned 2026-07-31, was origin/openrtm2
    SUBFOLDER openhrp
    SKIP_TEST
    DEPENDS openhrp3 hrpsys-base
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
    DEPENDS mc_rtc openhrp3 hrpsys-base choreonoid RHPS1 hrpsys-rhps1
  )
endif()
