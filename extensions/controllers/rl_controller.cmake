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
  # 801f3c4 met le run 2026-08-07_15-40-43 (checkpoint 7050) sur l'index 1,
  # observation 246 dims. Les blocs gait_phase et raw_torque deviennent
  # optionnels dans le switch au lieu d'un quatrieme corps duplique.
  # 4acbf5d ajoute l'index 4 : run 2026-08-12_20-36-28, premiere policy
  # entrainee avec le filtre de PostureTask modelise (posture_stiffness=1600
  # lu par policy, plus le global). RESERVE : metriques finales en deca de la
  # policy 0 (impact_vel -0.474 vs -0.19, fell_down 0.645 vs 0.000) -- essai
  # mc_mujoco voulu malgre ca, ne pas armer sur robot reel. use_QP toujours
  # true sur les cinq, default_policy_index toujours 0.
  # 5d0fcf5 corrige "Wrote 0 expects 246" : 4acbf5d ajoutait l'index 4 au yaml
  # sans ajouter sa case dans le switch(currentPolicyIndex) qui construit
  # l'observation. Sans elle l'index 4 tombait dans default: et l'observation
  # restait a zero. Symptome vu au premier essai mc_mujoco de l'index 4.
  GIT_TAG 5d0fcf5 # pinned 2026-08-14, was 4acbf5d
  DEPENDS mc_rtc mc_joystick_plugin
)
