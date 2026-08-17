#!/usr/bin/env python3
"""Give mc_mujoco the RHPS1's real armatures without touching the model.

rhps1_mj_description declares armature="1" in its <default> block, so on all 30
driven joints. The real knee is 0.10672 -- a factor of ten on rotor inertia, in
the misleading direction, since too much armature damps and stabilises. Without
this, mc_mujoco simulates a robot more forgiving than both the real one and the
one the policy trains against.

Writes two derived files into mc_mujoco's user config directory, which MjSimImpl
reads BEFORE the installed version (mj_sim.cpp, get_robot_cfg_path):

  <user>/RHPS1main_real_armature.xml   the model, armature per joint
  <user>/rhps1.yaml                    points xmlModelPath at it

meshdir is rewritten absolute, or the derived XML would not find the meshes from
its new directory. Regenerated on every launch by the mc_mujoco shim.

Values from the RHPS1_gains calibration document, armature = n_channels * JM *
N^2, JM checked against the SANMOTION datasheet. The eight cylinder-driven
joints (hip and ankle, roll and pitch) stay at 1.0: converting their
cylinder-side effort into joint-side inertia needs attachment geometry that is
in neither repository. Same split as on the training side.
"""

import os
import pathlib
import re
import sys

ARMATURE = {
  "L_CROTCH_Y": 0.06252, "R_CROTCH_Y": 0.06252,
  "L_KNEE_P": 0.10672, "R_KNEE_P": 0.10672,
  "CHEST_Y": 0.19251, "CHEST_P": 0.19251,
  "HEAD_Y": 0.00331, "HEAD_P": 0.00331,
  "L_SHOULDER_P": 0.15040, "R_SHOULDER_P": 0.15040,
  "L_SHOULDER_R": 0.02556, "R_SHOULDER_R": 0.02556,
  "L_SHOULDER_Y": 0.02556, "R_SHOULDER_Y": 0.02556,
  "L_ELBOW_P": 0.02640, "R_ELBOW_P": 0.02640,
  "L_ELBOW_Y": 0.02640, "R_ELBOW_Y": 0.02640,
  "L_WRIST_R": 0.01485, "R_WRIST_R": 0.01485,
  "L_WRIST_Y": 0.01485, "R_WRIST_Y": 0.01485,
}
CYLINDER = {"L_CROTCH_P", "R_CROTCH_P", "L_CROTCH_R", "R_CROTCH_R",
            "L_ANKLE_P", "R_ANKLE_P", "L_ANKLE_R", "R_ANKLE_R"}

# Effort limits [N.m], same table as the training actuators and the controller's
# effort_limit block. Used only by RHPS1_FORCE_LIMITS.
EFFORT = {"CHEST_Y": 120, "CHEST_P": 120, "HEAD_Y": 13, "HEAD_P": 13}
for _s in ("L", "R"):
  EFFORT.update({
      f"{_s}_SHOULDER_P": 50, f"{_s}_SHOULDER_R": 50, f"{_s}_SHOULDER_Y": 50,
      f"{_s}_ELBOW_P": 40, f"{_s}_ELBOW_Y": 40,
      f"{_s}_WRIST_R": 30, f"{_s}_WRIST_Y": 30,
      f"{_s}_CROTCH_Y": 35, f"{_s}_CROTCH_R": 100, f"{_s}_CROTCH_P": 140,
      f"{_s}_KNEE_P": 70, f"{_s}_ANKLE_R": 45, f"{_s}_ANKLE_P": 65,
  })


def main() -> int:
  # DISABLED BY DEFAULT. The real armatures make the model numerically unstable
  # with the current PD gains, and it is not a matter of fine tuning: measured on
  # a 1-DoF system reproducing the wrist (I 0.0033, armature 0.01485, kp 14000,
  # kd 240), the explicit-integration criterion kd*dt/M is 13 against a threshold
  # of 2. Unclamped the joint runs to 2420 rad; clamped it buzzes at 1-2 degrees
  # pinned to its torque limit. implicitfast changes nothing -- MuJoCo cannot
  # implicitly integrate a torque supplied through ctrl.
  #
  # The 20000/400 gains were tuned WITH armature=1.0 and are not separable from
  # it. Using the real values requires retuning kp and kd per joint, hence
  # redoing action_scale (= effort_limit/kp).
  #
  # RHPS1_REAL_ARMATURE=1 re-enables the override; RHPS1_ARMATURE_ONLY is a regex
  # restricting which joints receive it, to bisect a problem without editing this
  # script.
  if not os.environ.get("RHPS1_REAL_ARMATURE"):
    only_re = re.compile("$^")  # matches nothing
  else:
    only = os.environ.get("RHPS1_ARMATURE_ONLY")
    only_re = re.compile(only) if only is not None else None
    if only_re is not None:
      print(f"mc_mujoco: RHPS1_ARMATURE_ONLY={only!r} -- armature reelle "
            f"restreinte a ce filtre", file=sys.stderr)

  share, user = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
  src = share / "RHPS1" / "xml" / "RHPS1main.xml"
  meshes = share / "RHPS1" / "meshes"
  pdgains = share / "RHPS1" / "pdgains" / "RHPS1main" / "PDgains_sim.dat"
  for p in (src, meshes, pdgains):
    if not p.exists():
      print(f"rhps1_real_armature: introuvable: {p}", file=sys.stderr)
      return 1

  xml = src.read_text()

  # meshdir absolu : le XML derive vit ailleurs que l'original.
  xml, n = re.subn(r'meshdir="[^"]*"', f'meshdir="{meshes}"', xml, count=1)
  if n != 1:
    print("rhps1_real_armature: meshdir not found in the XML", file=sys.stderr)
    return 1

  # RHPS1_INTEGRATOR: the XML <option> specifies no integrator, so MuJoCo uses
  # Euler while mjlab trains under implicitfast -- a structural difference
  # between the two simulators. Dividing inertia by ten without touching kd moves
  # the loop closer to its stability limit, which is the first suspect for the
  # vibration seen with the real armatures.
  integrator = os.environ.get("RHPS1_INTEGRATOR")
  if integrator:
    m = re.search(r"<option\b[^>]*>", xml)
    if not m:
      print("rhps1_real_armature: balise <option> introuvable", file=sys.stderr)
      return 1
    tag = re.sub(r'\s+integrator="[^"]*"', "", m.group(0))
    tag = tag[:-2].rstrip() + f' integrator="{integrator}"/>' if tag.endswith("/>") \
        else tag[:-1].rstrip() + f' integrator="{integrator}">'
    xml = xml[: m.start()] + tag + xml[m.end():]
    print(f"mc_mujoco: integrateur force a {integrator!r}", file=sys.stderr)

  # RHPS1_FORCE_LIMITS: bound the actuator force like training does.
  #
  # mjlab's PD ends in torch.clamp(torque, +/-force_limit) (pd_actuator.py:68), and
  # with a raw demand of 3-4x the limit that clamp bites on nearly every step -- the
  # policy learned a plant where torque is always bounded. mc_mujoco bounds nothing:
  # MjRobot::PD returns kp*e_p + kd*e_v unclamped, and the XML <default> declares
  # forcelimited="false". Measured in mc_mujoco the demand reaches 72x the limit, so
  # the same command that mjlab caps becomes an unbounded torque here.
  #
  # Opt-in: this changes the plant, and index 0 currently walks without it.
  if os.environ.get("RHPS1_FORCE_LIMITS"):
    missing_act = []
    for joint, limit in EFFORT.items():
      # Match on joint=, not on the motor name: the knees are L_KNEE_motor for
      # joint L_KNEE_P, so the name is not derivable from the joint.
      pattern = rf'(<motor\b[^>]*?\bjoint="{joint}")([^>]*?)(\s*/>)'
      def repl(m: re.Match, limit: float = limit) -> str:
        body = re.sub(r'\s+force(limited|range)="[^"]*"', "", m.group(2))
        return (f'{m.group(1)}{body} forcelimited="true"'
                f' forcerange="{-limit:g} {limit:g}"{m.group(3)}')
      xml, k = re.subn(pattern, repl, xml, count=1, flags=re.S)
      if k != 1:
        missing_act.append(joint)
    if missing_act:
      print(f"rhps1_real_armature: actionneurs non trouves: {missing_act}", file=sys.stderr)
      return 1
    print(f"mc_mujoco: forcerange applique sur {len(EFFORT)} actionneurs", file=sys.stderr)

  # Une armature par articulation. Le `armature="1"` du bloc <default> reste et
  # continue de servir a tout le reste : verins, mains, doigts.
  missing = []
  applied = []
  for joint, value in ARMATURE.items():
    if only_re is not None and not only_re.search(joint):
      continue
    applied.append(joint)
    pattern = rf'(<joint name="{joint}")((?:(?!/>).)*?)(\s*/>)'
    def repl(m: re.Match) -> str:
      body = re.sub(r'\s+armature="[^"]*"', "", m.group(2))
      return f'{m.group(1)}{body} armature="{value}"{m.group(3)}'
    xml, k = re.subn(pattern, repl, xml, count=1, flags=re.S)
    if k != 1:
      missing.append(joint)
  if missing:
    print(f"rhps1_real_armature: articulations non trouvees: {missing}", file=sys.stderr)
    return 1

  # Verification: aucune articulation a verin ne doit avoir ete touchee.
  for joint in CYLINDER:
    m = re.search(rf'<joint name="{joint}"((?:(?!/>).)*?)/>', xml, re.S)
    if m and "armature=" in m.group(1):
      print(f"rhps1_real_armature: {joint} est a verin et a recu une armature",
            file=sys.stderr)
      return 1

  user.mkdir(parents=True, exist_ok=True)
  out_xml = user / "RHPS1main_real_armature.xml"
  out_xml.write_text(xml)

  # mc_mujoco reads the FIRST rhps1.yaml it finds, it does not merge. So start
  # from the installed content and rewrite only the top-level xmlModelPath,
  # preserving the other entries (RHPS1_sake2 and RHPS1_leap variants), which
  # would otherwise silently stop finding their model.
  cfg = (share / "rhps1.yaml").read_text()
  cfg, n = re.subn(r'^xmlModelPath:.*$', f'xmlModelPath: "{out_xml}"', cfg,
                   count=1, flags=re.M)
  if n != 1:
    print("rhps1_real_armature: top-level xmlModelPath not found in "
          f"{share / 'rhps1.yaml'}", file=sys.stderr)
    return 1

  # RHPS1main's gains file is misaligned by one from line 24 on. `500 5` is
  # L_HAND's gripper entry -- the leap and sake2 variants carry the same value at
  # the same line, and their joint order does include a hand. RHPS1main's does
  # not, so loadGain lands it on R_SHOULDER_P: kp 500 instead of 15000, 30x
  # softer than its own mirror, and R_WRIST_Y then falls off the end unserved.
  # Measured in a controller log, that joint sits 9 mrad under its q0 while the
  # other 29 track theirs to 0.4-3 mrad. Training gives both shoulders 15000/240.
  #
  # Fixed here rather than in rhps1_mj_description so the two machines agree
  # without waiting on a PR to a shared repo.
  gains = pdgains.read_text().splitlines()
  if len(gains) == 30 and gains[23].split() == ["500", "5"]:
    gains[23:25] = ["15000 240", "14000 240"]
    out_gains = user / "PDgains_sim_realigned.dat"
    out_gains.write_text("\n".join(gains) + "\n")
    cfg, n = re.subn(r'^pdGainsPath:.*$', f'pdGainsPath: "{out_gains}"', cfg,
                     count=1, flags=re.M)
    if n != 1:
      print("rhps1_real_armature: top-level pdGainsPath not found", file=sys.stderr)
      return 1
    print("mc_mujoco: gains RHPS1main realignes (R_SHOULDER_P 500 -> 15000)",
          file=sys.stderr)
  (user / "rhps1.yaml").write_text(
    "# Generated on every launch by the mc_mujoco shim. Do not edit.\n"
    "# Copy of the installed version, with only the main xmlModelPath\n"
    "# redirige vers le modele a armatures reelles.\n" + cfg)
  print(f"mc_mujoco: armatures reelles sur {len(applied)}/{len(ARMATURE)} "
        f"articulations, {len(CYLINDER)} a verins laissees a 1.0")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
