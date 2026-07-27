find_package(mc_mujoco QUIET)

if(mc_mujoco_FOUND)
  AddProject(
    h1_mj_description
    GITHUB_PRIVATE bastien-muraccioli/h1_mj_description
    GIT_TAG origin/safe-rl-qp
    DEPENDS mc_rtc
  )
endif()
