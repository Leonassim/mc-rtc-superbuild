AddProject(FootSteps_Planner
  GITHUB antodld/FootSteps_Planner
  GIT_TAG origin/main
  DEPENDS mc_rtc
)

AddProject(pendulum_feasibility_solver
  GITHUB antodld/pendulum_feasibility_solver
  GIT_TAG origin/master
  DEPENDS SpaceVecAlg eigen-quadprog
)

AddProject(ismpc_walking
  GITE adallard/ismpc_walking
  GIT_TAG origin/main
  DEPENDS FootSteps_Planner mc_state_observation pendulum_feasibility_solver mc_joystick_plugin
)
