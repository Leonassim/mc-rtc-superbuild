AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Pinned for the working-rhps1-newrlqp-2026-07-28 release tag -- a tag
  # that says "origin/main" resolves to whatever main is *when checked out*,
  # not what it was at tag time, which defeats the point of tagging even for
  # a fully-controlled repo. Fine to float back to origin/main on main
  # afterward; day-to-day dev doesn't need this pin, a release snapshot does.
  #
  # WARNING: this pin makes any superbuild rebuild hard-checkout the SHA in
  # ~/src/rl_controller, silently discarding uncommitted/unpushed work there
  # and reinstalling binaries built from the pinned code. That bit us on
  # 2026-07-29: a routine superbuild rebuild reverted a day of controller
  # fixes and the resulting binary/config mismatch looked like a policy
  # failure in mc_mujoco. Bump this SHA whenever rl_controller moves.
  GIT_TAG 127ac4a229bbd634478fcc923bb90975c09475ae # pinned 2026-07-29, was origin/main
  DEPENDS mc_rtc mc_joystick_plugin
)
