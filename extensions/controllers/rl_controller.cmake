AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Pinned for the working-rhps1-newrlqp-2026-07-28 release tag -- a tag
  # that says "origin/main" resolves to whatever main is *when checked out*,
  # not what it was at tag time, which defeats the point of tagging even for
  # a fully-controlled repo. Fine to float back to origin/main on main
  # afterward; day-to-day dev doesn't need this pin, a release snapshot does.
  GIT_TAG 764f84533222290ed73a90bcbb94b01d3828db90 # pinned 2026-07-28, was origin/main
  DEPENDS mc_rtc mc_joystick_plugin
)
