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
  # 52e2df8 embarque toutes les politiques dans policy/ (fini les chemins
  # absolus vers un $HOME, le PC du robot n'a plus besoin de mjlab-rhps1) et
  # ajoute l'index 3, abl15 au checkpoint final. use_QP true sur les quatre,
  # default_policy_index toujours 0.
  # 6b505f1 corrige q_tracking_error, qui indexait encoderValues() en ordre
  # filtre : tout le bras droit se comparait au joint voisin.
  GIT_TAG b55b030 # pinned 2026-08-07, was 6b505f1
  DEPENDS mc_rtc mc_joystick_plugin
)
