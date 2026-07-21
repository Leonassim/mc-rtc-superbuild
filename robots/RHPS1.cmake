option(WITH_RHPS1 "Build RHPS1 support" ON)

if(NOT WITH_RHPS1)
  return()
endif()

AddCatkinProject(
  rhps1_description
  GITHUB_PRIVATE isri-aist/rhps1_description
  GIT_TAG 3931f45e9b7dedcb1bebdc8fdd22155df8e6758c # pinned 2026-07-22, was origin/master
  WORKSPACE data_ws
  CMAKE_ARGS ${MC_RTC_ROS_OPTION}
)

AddProject(
  mc_rhps1
  GITHUB_PRIVATE isri-aist/mc_rhps1
  GIT_TAG e4778dc176a49e7c1cc9a440f48643342456de22 # pinned 2026-07-22, was origin/master
  DEPENDS rhps1_description mc_rtc
)

AddProject(
  rhps1_mj_description
  GITHUB_PRIVATE isri-aist/rhps1_mj_description
  GIT_TAG ac2d198b21b6f431fffc2c93ad03b04f98c4135a # pinned 2026-07-22, was origin/master
  DEPENDS mc_rtc mc_mujoco
)
