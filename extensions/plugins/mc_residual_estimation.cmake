AddProject(mc_residual_estimation
  GITHUB bastien-muraccioli/mc_residual_estimation
  # main (was devel, 2026-07-22, Léo): devel's ExternalForcesEstimator.h
  # requires mc_rbdyn/VirtualTorqueSensor.h, which doesn't exist in any
  # currently available mc_rtc branch (bastien's master/hrp5p, or upstream
  # jrl-umi3218 master) -- devel is ahead of what mc_rtc can build against
  # right now. main's ExternalForcesEstimator.h doesn't need it.
  GIT_TAG origin/main
  DEPENDS mc_rtc
)
