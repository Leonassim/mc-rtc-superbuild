AddProject(mc_residual_estimation
  GITHUB bastien-muraccioli/mc_residual_estimation
  # main, not devel: devel's ExternalForcesEstimator.h requires
  # mc_rbdyn/VirtualTorqueSensor.h, which exists in no currently available mc_rtc
  # branch. main's does not need it.
  GIT_TAG 7ad9a5911da0a0124d1c4857307505e9e7cea226 # pinned 2026-07-22
  DEPENDS mc_rtc
)
