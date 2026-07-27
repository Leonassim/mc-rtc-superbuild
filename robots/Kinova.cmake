option(WITH_Kinova "Build Kinova support" OFF)
option(WITH_Kinova_Bota "Build Kinova with Bota support" OFF)

if(NOT WITH_Kinova)
  return()
endif()

if(NOT WITH_ROS_SUPPORT OR NOT ROS_IS_ROS2)
  message(FATAL_ERROR "ROS2 support is required to use the Kinova robot")
endif()

set(MC_KINOVA_DEPENDS mc_rtc ros_kortex)
if(WITH_Kinova_Bota)
  AddCatkinProject(
    bota_driver_ros2
    GITLAB botasys/drivers/bota_driver_ros2
    GIT_TAG origin/main
    WORKSPACE data_ws INSTALL_DEPENDENCIES
  )
  AddCatkinProject(
    bota_driver_ros2_example
    GITLAB botasys/drivers/bota_driver_ros2_example
    GIT_TAG origin/main
    WORKSPACE data_ws INSTALL_DEPENDENCIES
  )
  list(APPEND MC_KINOVA_DEPENDS bota_driver_ros2)
endif()

AddCatkinProject(
  ros_kortex
  GITHUB Kinovarobotics/ros2_kortex
  GIT_TAG origin/${ROS_DISTRO}
  WORKSPACE data_ws INSTALL_DEPENDENCIES
)

AddProject(
  mc_kinova
  GITHUB_PRIVATE mathieu-celerier/mc_kinova
  GIT_TAG origin/devel-rl
  DEPENDS ${MC_KINOVA_DEPENDS}
)

AddProject(
  mc_kortex
  GITHUB_PRIVATE mathieu-celerier/mc_kortex
  GIT_TAG origin/main
  DEPENDS mc_rtc ros_kortex
)
