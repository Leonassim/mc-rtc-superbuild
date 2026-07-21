AddProject(mc_residual_estimation
  GITHUB bastien-muraccioli/mc_residual_estimation
  # main, not devel: devel needs mc_rbdyn/VirtualTorqueSensor.h, which no
  # available mc_rtc branch provides yet.
  GIT_TAG 7ad9a5911da0a0124d1c4857307505e9e7cea226 # pinned 2026-07-22, was origin/main
  DEPENDS mc_rtc
)
