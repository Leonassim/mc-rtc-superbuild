AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Branch real-robot-safe: QP on, policy armed from the GUI rather than on
  # load, refJointOrder filtered so MainRobot: RHPS1 works, and an abort if no
  # floating-base observer reaches the pipeline.
  #
  # default_policy_index is 0, the only policy validated on hardware. Les
  # index 1, 2 et 3 sont au mieux valides en simulation -- ne pas les armer
  # sur le robot. L'index 2 en particulier n'observe pas projected_gravity
  # et n'a vu aucune randomisation.
  #
  # Adding a policy index needs BOTH a yaml entry and a case in the
  # switch(currentPolicyIndex) that builds the observation. Missing the switch
  # case is silent until runtime, where it reads "Wrote 0 expects 246".
  GIT_TAG 54e9ea5 # pinned 2026-09-30, slot 4 arms into the policy's own stance
  DEPENDS mc_rtc mc_joystick_plugin
)
