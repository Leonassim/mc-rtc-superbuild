AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Branch real-robot-safe: QP on, policy armed from the GUI rather than on
  # load, refJointOrder filtered so MainRobot: RHPS1 works, and an abort if no
  # floating-base observer reaches the pipeline.
  #
  # default_policy_index is 0, the only policy validated on hardware. Index 1
  # is simulation-validated at best -- do not arm it on the robot.
  #
  # Adding a policy index needs BOTH a yaml entry and a case in the
  # switch(currentPolicyIndex) that builds the observation. Missing the switch
  # case is silent until runtime, where it reads "Wrote 0 expects 246".
  GIT_TAG d1844f1 # pinned 2026-08-25, index 5 = long-stride policy
  DEPENDS mc_rtc mc_joystick_plugin
)
