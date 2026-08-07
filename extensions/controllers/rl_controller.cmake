AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Real-robot entry, branched from the tag's e5d7968: QP on for index 0,
  # policy armed from the GUI instead of on load, refJointOrder filtered so
  # MainRobot: RHPS1 works, and an abort if no floating-base observer reaches
  # the pipeline. Branch real-robot-safe.
  # 0e339a9 adds the V5 observation (566 dims) and puts abl15 on policy index 1;
  # indices 0 and 2 are untouched and default_policy_index is still 0.
  # 441b61f switches the Encoder observer to finite differences: the real robot
  # publishes no encoder velocities and EncoderObserver::run throws on the empty
  # vector, which deactivated MCControl mid-run on hardware.
  GIT_TAG 80d78d4 # pinned 2026-08-07, was f82bfba
  DEPENDS mc_rtc mc_joystick_plugin
)
