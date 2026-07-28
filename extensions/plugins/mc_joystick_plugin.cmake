AddProject(mc_joystick_plugin
  # Fork of bastien-muraccioli/mc_joystick_plugin (2026-07-28): carries a fix
  # for before()'s datastore().assign<bool>("Joystick::connected", ...)
  # throwing (uncaught, crashes mc_mujoco) after "Reset simulation" rebuilds
  # the controller's DataStore -- this plugin instance survives the reset,
  # so init()'s original make<bool> never re-fires. See
  # ensureDataStoreKeys(), now called from both init() and reset().
  GITHUB Leonassim/mc_joystick_plugin
  GIT_TAG 792168341f1b980c58fe79315780a30c07390d81 # pinned 2026-07-28, fix-datastore-reset-crash branch
  DEPENDS mc_rtc
)
