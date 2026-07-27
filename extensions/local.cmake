set(EXTENSIONS_DIR ${CMAKE_CURRENT_LIST_DIR}/superbuild-extensions)
include(${CMAKE_CURRENT_LIST_DIR}/plugins/mc_joystick_plugin.cmake)
# mc_residual_estimation removed (2026-07-27): main branch's
# ExternalForcesEstimator.cpp calls mc_rbdyn::Robot::setExternalTorques /
# setExternalTorquesAcc, which no longer exist on the mc_rtc SHA we just
# pinned (removed/renamed upstream between the 2026-07-22 and 2026-07-27
# mc_rtc pins). Not used by the RHPS1/rl_controller pipeline; not worth
# chasing a moved mc_rtc API for a component we don't run.
include(${CMAKE_CURRENT_LIST_DIR}/plugins/mc_mujoco.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/controllers/rl_controller.cmake)
