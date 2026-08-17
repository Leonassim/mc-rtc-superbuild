#!/usr/bin/env python3
"""Joint torques from an mc_rtc log, for single-motor joints.

What the log actually holds
---------------------------
`tauIn_*` is what RobotHardware publishes from the IOB's `state.torque`. On
RHPS1 this is NOT a torque: the VRML gives gearRatio = 1 and torqueConst = 1 on
all 62 joints, so the value is

    ratedCurrent * (0x6077 / 1000)   =   a CURRENT in amperes.

This converts it to N.m with tau = I * N * Kt.

What is converted, and what is not
----------------------------------
Only the six `solo` joints (one motor, direct drive) have a per-joint N and Kt,
taken from joint_torque_limits_rotate.csv. The differential pairs (shoulder R/Y,
elbow P/Y, wrist P/Y, chest, head) have an N but no per-joint Kt, and the
cylinder-driven joints (crotch P/R, ankle P/R) are absent entirely -- their lever
arm depends on the angle and the conversion needs CylinderToAngle. Both are
skipped here.

Usage:  python3 torques_from_log.py /path/to/mc-control-...bin
Read only.
"""

import sys

import numpy as np

try:
  from mc_log_ui import read_log
except ImportError:
  sys.exit("mc_log_ui not found. Run in a shell where setup_mc_rtc.sh is sourced.")

# RHPS1 module refJointOrder (non-mujoco branch), which is also the order of
# tauIn. Both hands are in it: they shift everything that follows.
RJO = [
  "L_CROTCH_Y", "L_CROTCH_R", "L_CROTCH_P", "L_KNEE_P", "L_ANKLE_R", "L_ANKLE_P",
  "CHEST_Y", "CHEST_P",
  "R_CROTCH_Y", "R_CROTCH_R", "R_CROTCH_P", "R_KNEE_P", "R_ANKLE_R", "R_ANKLE_P",
  "HEAD_Y", "HEAD_P",
  "L_SHOULDER_P", "L_SHOULDER_R", "L_SHOULDER_Y", "L_ELBOW_P", "L_ELBOW_Y",
  "L_WRIST_R", "L_WRIST_Y", "L_HAND",
  "R_SHOULDER_P", "R_SHOULDER_R", "R_SHOULDER_Y", "R_ELBOW_P", "R_ELBOW_Y",
  "R_WRIST_R", "R_WRIST_Y", "R_HAND",
]

# joint -> (N, Kt, courant continu A, courant pic A, duree pic s)
# joint_torque_limits_rotate.csv, lignes type=solo. Valeurs remappees le
# 2026-08-03 apres correction du bug d'association Drive<->joint.
SOLO = {
  "L_CROTCH_Y":   (159.0907, 0.0582, 0.71, 2.05, 12.91),
  "R_CROTCH_Y":   (159.0907, 0.0582, 0.71, 2.05, 12.91),
  "L_KNEE_P":     (210.0,    0.1010, 1.03, 2.03, 23.53),
  "R_KNEE_P":     (210.0,    0.1010, 1.03, 2.03, 23.53),
  "L_SHOULDER_P": (200.0,    0.0470, 0.88, 1.68, 24.63),
  "R_SHOULDER_P": (200.0,    0.0470, 0.88, 1.68, 24.63),
}


def main():
  if len(sys.argv) != 2:
    sys.exit(f"usage: {sys.argv[0]} <log.bin>")
  log = read_log(sys.argv[1])

  # Depuis 466caa3 le controleur retire l'entree "tauIn" de mc_rtc, dont le nom
  # ment (c'est un courant), et republie la meme donnee sous joint_current_A.
  # Les deux n'ont PAS la meme indexation : joint_current_A suit le
  # refJointOrder filtre (30 joints, sans les mains), tauIn le refJointOrder
  # complet (42, mains comprises).
  if "NewRLQPController_joint_current_A_0" in log:
    prefix, order = "NewRLQPController_joint_current_A", [j for j in RJO if not j.endswith("_HAND")]
  elif "tauIn_0" in log:
    prefix, order = "tauIn", RJO
  else:
    sys.exit("neither joint_current_A nor tauIn in this log: RobotHardware was not\n"
             "connecte, ou le log date d'avant le calcul de state.torque.")

  n = len(log["t"])
  print(f"log : {sys.argv[1]}")
  print(f"{n} echantillons\n")

  print(f"{'joint':14s} {'I moy':>8s} {'I max':>8s} {'tau moy':>9s} {'tau max':>9s} "
        f"{'% continu':>10s} {'% pic':>8s}")
  print("-" * 72)

  any_signal = False
  for name, (N, Kt, cl, pl, _) in SOLO.items():
    i = order.index(name)
    cur = np.asarray(log[f"{prefix}_{i}"], dtype=float)
    if np.allclose(cur, 0.0):
      print(f"{name:14s} {'--':>8s} {'--':>8s} {'--':>9s} {'--':>9s} "
            f"{'--':>10s} {'--':>8s}   (identiquement nul)")
      continue
    any_signal = True
    a = cur * N * Kt
    imax = np.max(np.abs(cur))
    print(f"{name:14s} {np.mean(np.abs(cur)):8.3f} {imax:8.3f} "
          f"{np.mean(np.abs(a)):9.2f} {np.max(np.abs(a)):9.2f} "
          f"{100*imax/cl:9.0f}% {100*imax/pl:7.0f}%")

  print("-" * 72)
  print("I en amperes, tau en N.m. Les pourcentages comparent le courant CRETE")
  print("du run aux limites du drive : continu (CL) et pic (PL).")
  if not any_signal:
    print("\nTout est nul : ce log est anterieur au calcul de state.torque, ou le")
    print("servo n'a jamais ete arme pendant l'enregistrement.")
  print("\nNon traites : paires differentielles (pas de Kt par joint) et")
  print("articulations a verins (bras de levier variable, voir CylinderToAngle).")


if __name__ == "__main__":
  main()
