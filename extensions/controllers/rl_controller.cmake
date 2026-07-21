AddProject(rl_controller
  GITHUB leonassim/new-rl-qp-controller
  # Kept floating on origin/main (unlike the other 2026-07-22 pins): this is
  # Léo's own repo, fully controlled, so there's no risk of an upstream fork
  # moving/deleting the branch out from under us.
  GIT_TAG origin/main
  DEPENDS mc_rtc mc_joystick_plugin
)
