AddProject(mc_residual_estimation
  GITHUB bastien-muraccioli/mc_residual_estimation
  # main, not devel: devel needs mc_rbdyn/VirtualTorqueSensor.h, which no
  # available mc_rtc branch provides yet. bastien/main now points this at
  # origin/simple_generalized_residual instead -- kept on our known-working
  # main pin (2026-07-27 merge) since we don't use this component in the
  # RHPS1/rl_controller pipeline and haven't verified that branch against
  # the same VirtualTorqueSensor.h constraint. Worth revisiting on its own.
  GIT_TAG 7ad9a5911da0a0124d1c4857307505e9e7cea226 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
)
