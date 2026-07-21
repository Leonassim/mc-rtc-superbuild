if(WITH_ROS_SUPPORT)
  # catkin_make generates CMakeLists.txt with version 3.0. Kitware upgraded its
  # repository to cmake 4.0 which removes the support for cmake < 3.5 The option
  # -DCMAKE_POLICY_VERSION_MINIMUM=3.5 is a workaroound that forces the minimum cmake
  # version to 3.5

  CreateCatkinWorkspace(
    ID data_ws
    DIR "catkin_data_ws"
    CATKIN_MAKE
    CATKIN_BUILD_ARGS -DCATKIN_ENABLE_TESTING:BOOL=OFF
                      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  )
  CreateCatkinWorkspace(
    ID mc_rtc_ws
    DIR "catkin_ws"
    CATKIN_BUILD
    CATKIN_BUILD_ARGS -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    PARALLEL_JOBS 8
  )
endif()

AddProject(
  ndcurves
  GITHUB loco-3d/ndcurves
  GIT_TAG v2.0.0
  CMAKE_ARGS -DBUILD_PYTHON_INTERFACE:BOOL=OFF -DCURVES_WITH_PINOCCHIO_SUPPORT:BOOL=OFF
  SKIP_TEST
  APT_PACKAGES libndcurves-dev
)

# ArnaudDmt addWaiko branch: provides the WAIKO observer stack (leg odometry
# without contact sensors) used by the MCWaiko observer in mc_state_observation.
AddProject(
  state-observation
  GITHUB ArnaudDmt/state-observation
  GIT_TAG 693d53d76994e44ae6b2b69af7fa33ff726cc4d5 # pinned 2026-07-22, was origin/addWaiko
  CMAKE_ARGS -DBUILD_STATE_OBSERVATION_TOOLS:BOOL=OFF
  APT_PACKAGES libstate-observation-dev
)

if(PYTHON_BINDING)
  AddProject(
    Eigen3ToPython
    GITHUB jrl-umi3218/Eigen3ToPython
    GIT_TAG origin/master
    CMAKE_ARGS -DPIP_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
    APT_PACKAGES python-eigen python3-eigen
  )
  list(APPEND SpaceVecAlg_DEPENDS Eigen3ToPython)
endif()

AddProject(
  SpaceVecAlg
  GITHUB jrl-umi3218/SpaceVecAlg
  GIT_TAG bbe75c7fd4912834b311dfabe022d95f17eb409c # pinned 2026-07-22, was origin/master
  DEPENDS ${SpaceVecAlg_DEPENDS}
  APT_PACKAGES libspacevecalg-dev python-spacevecalg python3-spacevecalg
)

AddProject(
  sch-core
  GITHUB jrl-umi3218/sch-core
  GIT_TAG a04cd4ee0fbc3a799ad3c0e9a8cf8629b3eb9d62 # pinned 2026-07-22, was origin/master
  CMAKE_ARGS -DCMAKE_CXX_STANDARD=11
  APT_PACKAGES libsch-core-dev
)

if(DISTRO STREQUAL "jammy" OR DISTRO STREQUAL "noble")
  set(MESH_SAMPLING_ARGS "-DUSE_LEGACY_QHULL_STREAM=ON")
else()
  set(MESH_SAMPLING_ARGS "-DUSE_LEGACY_QHULL_STREAM=OFF")
endif()
AddProject(
  mesh-sampling
  GITHUB jrl-umi3218/mesh_sampling
  GIT_TAG 554bbc283d23c81854937955655674ebd3b7f225 # pinned 2026-07-22, was origin/master
  APT_PACKAGES libmesh-sampling-dev
  APT_DEPENDENCIES libgtest-dev libqhull-dev libassimp-dev
  CMAKE_ARGS ${MESH_SAMPLING_ARGS}
)

if(PYTHON_BINDING)
  AddProject(
    sch-core-python
    GITHUB jrl-umi3218/sch-core-python
    GIT_TAG origin/master
    CMAKE_ARGS -DPIP_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
    DEPENDS sch-core SpaceVecAlg
    APT_PACKAGES python-sch-core python3-sch-core
  )
endif()

AddProject(
  RBDyn
  GITHUB jrl-umi3218/RBDyn
  GIT_TAG a49b383e3fbc57168c7238fd93155c409b6046f5 # pinned 2026-07-22, was origin/master
  DEPENDS SpaceVecAlg
  APT_PACKAGES librbdyn-dev python-rbdyn python3-rbdyn
)

if(EMSCRIPTEN)
  set(USE_F2C_ARGS
      "-DUSE_F2C:BOOL=ON"
      "-DCMAKE_C_STANDARD_INCLUDE_DIRECTORIES=${CMAKE_INSTALL_PREFIX}/include"
  )
else()
  set(USE_F2C_ARGS "")
endif()

AddProject(
  eigen-qld
  GITHUB jrl-umi3218/eigen-qld
  GIT_TAG ebdf5d6246c671b7a55fb4b678551c495164e694 # pinned 2026-07-22, was origin/master
  NO_NINJA NO_COLOR
  CMAKE_ARGS ${USE_F2C_ARGS}
  APT_PACKAGES libeigen-qld-dev python-eigen-qld python3-eigen-qld
)

AddProject(
  eigen-quadprog
  GITHUB jrl-umi3218/eigen-quadprog
  GIT_TAG 2da94c5d2a44d0db75b7a2eddd4bc547939d229f # pinned 2026-07-22, was origin/master
  NO_NINJA
  CMAKE_ARGS ${USE_F2C_ARGS}
  APT_PACKAGES libeigen-quadprog-dev
)

if(WITH_LSSOL)
  if(USE_MC_RTC_APT_MIRROR)
    message(WARNING "LSSOL will not be used by mc-rtc if mc-rtc apt packages are used")
  endif()
  AddProject(
    eigen-lssol
    GITE multi-contact/eigen-lssol
    GIT_TAG origin/master
    NO_NINJA
    CMAKE_ARGS ${USE_F2C_ARGS}
  )
endif()

set(Tasks_DEPENDS RBDyn eigen-qld sch-core)
if(WITH_LSSOL)
  list(APPEND Tasks_DEPENDS eigen-lssol)
endif()
if(PYTHON_BINDING)
  list(APPEND Tasks_DEPENDS sch-core-python)
endif()
AddProject(
  Tasks
  GITHUB_PRIVATE bastien-muraccioli/Tasks
  GIT_TAG 827e136322da3e2f1d9c28141b00fe43a9f35a4a # pinned 2026-07-22, was origin/master
  DEPENDS ${Tasks_DEPENDS}
  APT_PACKAGES libtasks-qld-dev python-tasks python3-tasks
)

AddProject(
  lexls
  GITHUB jrl-umi3218/lexls
  GIT_TAG f13b6b668146aabbf838b1e2fc3fe9b65d752db5 # pinned 2026-07-22, was origin/master
  CMAKE_ARGS -DINSTALL_PDF_DOCUMENTATION:BOOL=OFF -DINSTALL_HTML_DOCUMENTATION:BOOL=OFF
  APT_PACKAGES liblexls-dev
)

if(WITH_LSSOL)
  set(tvm_EXTRA_DEPENDS eigen-lssol)
else()
  set(tvm_EXTRA_DEPENDS)
endif()

AddProject(tvm
  GITHUB_PRIVATE bastien-muraccioli/tvm
  GIT_TAG 62aacd80d49a11e2d56dd3a7dcf712340f7f6b68 # pinned 2026-07-22, was origin/master
  DEPENDS eigen-qld eigen-quadprog lexls ${tvm_EXTRA_DEPENDS}
  CMAKE_ARGS -DTVM_WITH_QLD:BOOL=ON
             -DTVM_WITH_QUADPROG:BOOL=ON -DTVM_WITH_LEXLS:BOOL=ON
             -DTVM_WITH_ROBOT:BOOL=OFF -DTVM_THOROUGH_TESTING:BOOL=OFF
             -DTVM_WITH_LSSOL:BOOL=${WITH_LSSOL}
  APT_PACKAGES libtvm-dev
)

if(NOT WITH_ROS_SUPPORT)
  set(MC_RTC_ROS_BRANCH origin/ROSFree)
else()
  set(MC_RTC_ROS_BRANCH origin/master)
endif()
AddCatkinProject(
  mc_rtc_data
  GITHUB jrl-umi3218/mc_rtc_data
  GIT_TAG 3f13055e7abfdd97e5ec597057b3c681a18d429e # pinned 2026-07-22, was ${MC_RTC_ROS_BRANCH} (origin/master, WITH_ROS_SUPPORT=ON)
  WORKSPACE data_ws
  APT_PACKAGES mc-rtc-data ros-${ROS_DISTRO}-mc-rtc-data
  CMAKE_ARGS ${MC_RTC_ROS_OPTION}
)

# bastien-muraccioli/mc_rtc's master branch (used since we moved off the
# nonexistent 'devel' branch) hard-requires mc_rtc_ros_compat, unlike the old
# devel branch we depended on before -- not previously declared here.
AddProject(mc_rtc_ros_compat
  GITHUB jrl-umi3218/mc_rtc_ros_compat
  GIT_TAG d294d5d7a7526db1c2d5ab4605569255dc3a459e # pinned 2026-07-22, was origin/main
)

set(mc_rtc_DEPENDS tvm Tasks mc_rtc_data ndcurves state-observation mesh-sampling mc_rtc_ros_compat)
if(WITH_ROS_SUPPORT)
  AddCatkinProject(
    mc_rtc_msgs
    GITHUB jrl-umi3218/mc_rtc_msgs
    GIT_TAG 93ae1865ccef05caeed61039a90492664ccb7cfe # pinned 2026-07-22, was origin/master
    WORKSPACE data_ws
    APT_PACKAGES ros-${ROS_DISTRO}-mc-rtc-msgs
  )
  list(APPEND mc_rtc_DEPENDS mc_rtc_msgs)
endif()

if(TARGET spdlog)
  list(APPEND mc_rtc_DEPENDS spdlog)
endif()
if(NOT DEFINED MC_LOG_UI_PYTHON_EXECUTABLE)
  set(MC_LOG_UI_PYTHON_EXECUTABLE ${MC_RTC_SUPERBUILD_DEFAULT_PYTHON})
endif()
if(WITH_ROS_SUPPORT)
  set(MC_RTC_ROS_OPTION "-DDISABLE_ROS=OFF")
else()
  set(MC_RTC_ROS_OPTION "-DDISABLE_ROS=ON")
endif()
if(EMSCRIPTEN)
  set(MC_RTC_EXTRA_OPTIONS
      -DMC_RTC_BUILD_STATIC=ON
      -DMC_RTC_DISABLE_NETWORK=ON
      -DMC_RTC_DISABLE_STACKTRACE=ON
      -DJVRC_DESCRIPTION_PATH=/assets/jvrc_description
      -DMC_ENV_DESCRIPTION_PATH=/assets/mc_env_description
      -DMC_INT_OBJ_DESCRIPTION_PATH=/assets/mc_int_obj_description
  )
else()
  set(MC_RTC_EXTRA_OPTIONS)
endif()
AddProject(mc_rtc
  GITHUB_PRIVATE bastien-muraccioli/mc_rtc
  GIT_TAG 542a88432d30d04dfd33cd6f0e0ab1c7be7f598b # pinned 2026-07-22, was origin/master
  CMAKE_ARGS -DMC_LOG_UI_PYTHON_EXECUTABLE=${MC_LOG_UI_PYTHON_EXECUTABLE}
             ${MC_RTC_ROS_OPTION} ${MC_RTC_EXTRA_OPTIONS}
  DEPENDS ${mc_rtc_DEPENDS}
  APT_PACKAGES libmc-rtc-dev mc-rtc-utils python-mc-rtc python3-mc-rtc
               ros-${ROS_DISTRO}-mc-rtc-plugin
)

if(WITH_ROS_SUPPORT)
  AddCatkinProject(
    mc_rtc_ros
    GITHUB jrl-umi3218/mc_rtc_ros
    GIT_TAG 7e130cb94721738520a29c0d96140fc4d2324fec # pinned 2026-07-22, was origin/master
    WORKSPACE mc_rtc_ws
    DEPENDS mc_rtc
    APT_PACKAGES ros-${ROS_DISTRO}-mc-rtc-plugin ros-${ROS_DISTRO}-mc-rtc-tools
  )
endif()

set(MC_STATE_OBSERVATION_DEPENDS mc_rtc)
set(MC_STATE_OBSERVATION_OPTIONS "-DWITH_ROS_OBSERVERS=OFF")

if(WITH_ROS_SUPPORT)
  AddProject(
    gram_savitzky_golay
    GITHUB jrl-umi3218/gram_savitzky_golay
    GIT_TAG 3f767e3ca366677ed189c33ee14a86cc6e9b34a6 # pinned 2026-07-22, was origin/master
    APT_PACKAGES libgram-savitzky-golay-dev
  )
  list(APPEND MC_STATE_OBSERVATION_DEPENDS gram_savitzky_golay)
  set(MC_STATE_OBSERVATION_OPTIONS "-DWITH_ROS_OBSERVERS=ON")
  AptInstall(ros-${ROS_DISTRO}-tf2-eigen)
endif()

AddProject(
  mc_state_observation
  # GITHUB jrl-umi3218/mc_state_observation
  # GIT_TAG origin/main
  # GITHUB_PRIVATE bastien-muraccioli/mc_state_observation
  # GIT_TAG origin/main
  GITHUB ArnaudDmt/mc_state_observation
  GIT_TAG 309a692d816ba2cec4de9df97b4b0c85331929a8 # pinned 2026-07-22, was origin/addWaiko
  CMAKE_ARGS ${MC_STATE_OBSERVATION_OPTIONS}
  DEPENDS ${MC_STATE_OBSERVATION_DEPENDS}
  APT_PACKAGES mc-state-observation ros-${ROS_DISTRO}-mc-state-observation
)
