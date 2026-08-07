#!/usr/bin/env python3
"""Couples articulaires a partir d'un log mc_rtc, pour les joints a moteur unique.

Ce que contient reellement le log
---------------------------------
`tauIn_*` est ce que RobotHardware publie depuis `state.torque` de l'IOB. Sur
RHPS1 ce n'est PAS un couple : le VRML donne gearRatio = 1 et torqueConst = 1
sur les 62 joints, donc la valeur vaut

    ratedCurrent * (0x6077 / 1000)   =   un COURANT en amperes.

Ce script le convertit en N.m avec tau = I * N * Kt.

Ce qui est converti, et ce qui ne l'est pas
-------------------------------------------
Seuls les six joints `solo` (un moteur, entrainement direct) ont un N et un Kt
par articulation, tires de joint_torque_limits_rotate.csv. Les paires
differentielles (epaule R/Y, coude P/Y, poignet P/Y, chest, head) ont bien un N
mais aucun Kt par joint, et les articulations a verins (crotch P/R, ankle P/R)
n'y figurent pas du tout : leur bras de levier depend de l'angle, la conversion
demande CylinderToAngle. Les unes comme les autres sont ignorees ici.

Usage :  python3 torques_from_log.py /chemin/vers/mc-control-...bin
Lecture seule.
"""

import sys

import numpy as np

try:
  from mc_log_ui import read_log
except ImportError:
  sys.exit("mc_log_ui introuvable. Lancer dans un shell ou setup_mc_rtc.sh est source.")

# refJointOrder du module RHPS1 (branche non-mujoco), qui est aussi l'ordre de
# tauIn. Les deux mains sont dedans : elles decalent tout ce qui suit.
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
    sys.exit("ni joint_current_A ni tauIn dans ce log : RobotHardware n'etait pas\n"
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
