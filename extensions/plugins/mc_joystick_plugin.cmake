AddProject(mc_joystick_plugin
  # Fork de Leo, le temps du correctif de reset : MCGlobalController::reset()
  # reconstruit le controleur puis appelle plugin->reset() et jamais
  # plugin->init(), donc tout ce qu'init() enregistrait disparaissait et
  # before() levait sur "Joystick::connected", ce qui tuait mc_mujoco manette
  # branchee. Revenir a bastien-muraccioli/mc_joystick_plugin quand le
  # correctif y sera remonte.
  GITHUB Leonassim/mc_joystick_plugin
  GIT_TAG 206783b # pinned 2026-09-14, branche fix/reset-simulation-crash
  DEPENDS mc_rtc
)
