AddCatkinProject(
  rhp7_description
  GITHUB_PRIVATE isri-aist/rhp7_description
  GIT_TAG origin/main
  WORKSPACE data_ws
)

AddProject(
  mc_rhp7
  GITHUB_PRIVATE Yoshida-Lab-TUS/mc_rhp7
  GIT_TAG origin/main
  DEPENDS rhp7_description mc_rtc
)
