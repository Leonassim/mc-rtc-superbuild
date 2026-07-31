AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Real-robot entry, branched from the tag's e5d7968: QP on for index 0,
  # policy armed from the GUI instead of on load, refJointOrder filtered so
  # MainRobot: RHPS1 works, and an abort if no floating-base observer reaches
  # the pipeline. Branch real-robot-safe.
  GIT_TAG 4f432d3 # pinned 2026-07-31, was e5d7968a (superbuild tag 2026-07-22)
  DEPENDS mc_rtc mc_joystick_plugin
)
