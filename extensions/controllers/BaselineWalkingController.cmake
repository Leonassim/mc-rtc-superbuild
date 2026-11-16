# BaselineWalkingController (isri-aist): the AIST reference biped walker --
# preview-control ZMP, wrench distribution, swing trajectories, driven from the
# mc_rtc GUI. Useful here as the model-based control against which the RL
# policy is judged: same robot, same plant, same Timestep.
#
# ON by default, but it pulls six repositories and none of them is small. To
# skip it:
#
#   cmake --preset relwithdebinfo -DWITH_BASELINE_WALKING_CONTROLLER=OFF
#
# RHPS1 needs no work here: mc_rhps1 already ships and installs
# etc/controllers/BaselineWalkingController/rhps1.yaml, which mc_rtc merges on
# top of the controller's own config because RHPS1RobotModule's module name is
# the literal "rhps1" (rhps1.cpp:21) for every variant, mujoco included. So the
# same file covers MainRobot: RHPS1 and MainRobot: RHPS1_MuJoCo.
#
# To run it, prepend the overlay that flips Enabled -- see
# etc/mc_rtc_superbuild_bwc.in.yaml, or just use the mc_mujoco_bwc launcher.
option(WITH_BASELINE_WALKING_CONTROLLER
       "Build BaselineWalkingController and its dependency chain" ON
)

if(NOT WITH_BASELINE_WALKING_CONTROLLER)
  return()
endif()

# Everything below is built STANDALONE -- deliberately no -DUSE_ROS2=ON.
#
# mc-rtc/superbuild-extensions does pass it whenever WITH_ROS_SUPPORT is on and
# ROS_VERSION is 2. That is wrong for this superbuild. USE_ROS2 makes these
# projects ament packages: ament_package() replaces the install(EXPORT ...)
# branch, so <pkg>Targets.cmake never lands in lib/cmake. BaselineWalkingController
# picks its own branch on CATKIN_DEVEL_PREFIX (ROS1 only), so under ROS2 it takes
# the standalone path and asks for exactly those plain targets --
# trajectory_collection::TrajColl, force_control_collection::ForceColl,
# centroidal_control_collection::CCC. ament would not have installed them.
#
# AddProject is a plain CMake configure/build/install into one prefix; standalone
# is the layout that matches. ROS support in mc_rtc itself is unaffected.
#
# BaselineWalkingController's CMakeLists still error_and_throw's without
# mc_rtc::mc_rtc_ros even though no BWC source includes a ROS header -- vestigial
# from the catkin days. WITH_ROS_SUPPORT=ON already provides the target.

# QLD and QuadProg only. QpSolverCollection::getAnyQpSolverType() returns them in
# declaration order and QLD is first, which is what ForceControlCollection's
# wrench distribution asks for (QpSolverType::Any, no override in the RHPS1
# config). Upstream's -DDEFAULT_ENABLE_ALL=ON would drag in jrl-qp, qpOASES,
# osqp-eigen, nasoq, hpipm, proxsuite and qpmad to be ignored at runtime.
# Both solvers are already built by mc_rtc.cmake.
AddProject(QpSolverCollection
  GITHUB isri-aist/QpSolverCollection
  GIT_TAG 42cb58674e692bea0bf64c7ab7a4a80137023aee # pinned 2026-08-27, was origin/master
  CMAKE_ARGS -DDEFAULT_ENABLE_ALL=OFF -DENABLE_QLD=ON -DENABLE_QUADPROG=ON
  DEPENDS eigen-qld eigen-quadprog
)

# Super-repo: its CMakeLists drives nmpc_cgmres / nmpc_ddp / nmpc_fmpc as
# ExternalProjects into CMAKE_INSTALL_PREFIX. Only nmpc_ddp is used here
# (CentroidalControlCollection's DDP-ZMP method), the other two come along.
# Header-only Eigen, no ROS.
AddProject(NMPC
  GITHUB isri-aist/NMPC
  GIT_TAG c98321f232937eb65d0e767b18fc408cd65e2edb # pinned 2026-08-27, was origin/master
)

AddProject(ForceControlCollection
  GITHUB isri-aist/ForceControlCollection
  GIT_TAG 55de5119347987e9e3bc76783aec439748202cf5 # pinned 2026-08-27, was origin/master
  DEPENDS QpSolverCollection mc_rtc
)

AddProject(CentroidalControlCollection
  GITHUB isri-aist/CentroidalControlCollection
  GIT_TAG a874f6a09e4f1431509c166fb622af25781fe396 # pinned 2026-08-27, was origin/master
  DEPENDS ForceControlCollection NMPC QpSolverCollection mc_rtc
)

AddProject(TrajectoryCollection
  GITHUB isri-aist/TrajectoryCollection
  GIT_TAG 3f18e7a8748e40dbccdd28b0b3ec98353a33f58d # pinned 2026-08-27, was origin/master
  DEPENDS SpaceVecAlg
)

# Footstep planning from a goal pose (BWC::FootstepPlanner state). Optional:
# BaselineWalkingController's src/states/CMakeLists.txt find_package()s it QUIET
# and simply drops the state when absent, so the GUI walk interface -- which is
# what a first test needs -- works without it. sbpl is a 2018 tree that needs
# CMAKE_POLICY_VERSION_MINIMUM to configure under modern CMake.
#
# Turning this ON later is not enough on its own: BaselineWalkingController
# resolves the planner at ITS configure time, so force a reconfigure with
#   cmake --build <build> --target force-BaselineWalkingController
option(WITH_BASELINE_FOOTSTEP_PLANNER
       "Build BaselineFootstepPlanner (adds the BWC::FootstepPlanner state)" OFF
)

if(WITH_BASELINE_FOOTSTEP_PLANNER)
  AddProject(sbpl
    GITHUB sbpl/sbpl
    GIT_TAG 4d654845aa3b92aa1b4282a342e9011bac95aeb9 # pinned 2026-08-27, was origin/master
    CMAKE_ARGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  )
  AddProject(BaselineFootstepPlanner
    GITHUB isri-aist/BaselineFootstepPlanner
    GIT_TAG a7865cd0b7e9048a424a9103ebdb91a2e62e6340 # pinned 2026-08-27, was origin/master
    DEPENDS sbpl
  )
  set(BaselineWalkingController_PLANNER_DEPENDS BaselineFootstepPlanner)
else()
  set(BaselineWalkingController_PLANNER_DEPENDS)
endif()

AddProject(BaselineWalkingController
  GITHUB isri-aist/BaselineWalkingController
  GIT_TAG 9cba7e2fcc95b990774599f405471b86cc0f9e07 # pinned 2026-08-27, was origin/master
  DEPENDS CentroidalControlCollection ForceControlCollection TrajectoryCollection
          mc_rtc ${BaselineWalkingController_PLANNER_DEPENDS}
)
