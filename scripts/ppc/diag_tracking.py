#!/usr/bin/env python3
"""Where does the tracking error come from, and does the loop drop frames?

Follows diag_vibration.py, which showed the network action is smooth with no
high frequency, and that tracking error has an RMS of 0.27 rad (15 deg) against
0.013 in simulation. The dominant 1.9 Hz peak is the step cadence, not a
parasitic oscillation -- so this is not a tremor, it is a gait that is not
executed as commanded.

Separates two causes:

  CONSTANT bias on loaded joints (knees, hip pitch)
    -> torque saturation. The knee demands ~41 N.m against a real continuous
       limit of 21.4 N.m and sags under load.
  DISTRIBUTED or dynamic error
    -> the QP is not tracking; look at tasks and constraints.

Also counts loop overruns, which perf_LoopDt's max (85 ms) reports without
saying whether they are isolated or repeated.

Usage:  python3 diag_tracking.py /path/to/mc-control-...bin
Read only.
"""

import sys

import numpy as np

try:
  from mc_log_ui import read_log
except ImportError:
  sys.exit("mc_log_ui not found. Run in a shell where setup_mc_rtc.sh is sourced.")

# ATTENTION : c'est le refJointOrder du module RHPS1 prive de L_HAND/R_HAND,
# NOT the policy's ref_joint_order (the yaml one, which starts with
# CHEST_Y). Les vecteurs par joint du controleur -- q_rl, q_zero,
# q_tracking_error, actionScale, kp, kd are all indexed this way, because
# NewRLQPController.cpp:146 fait `jointNames = robot().refJointOrder()` puis
# filtre. Verifiable sur n'importe quel log : RL_qZero_3 vaut 0.622021, le q0
# du genou, et RL_qZero_19 vaut -0.523599, celui du coude gauche.
#
# Utiliser l'ordre de la politique ici renomme chaque joint et fabrique de
# fausses asymetries (constate le 2026-08-07).
JOINTS = [
  "L_CROTCH_Y", "L_CROTCH_R", "L_CROTCH_P", "L_KNEE_P", "L_ANKLE_R", "L_ANKLE_P",
  "CHEST_Y", "CHEST_P",
  "R_CROTCH_Y", "R_CROTCH_R", "R_CROTCH_P", "R_KNEE_P", "R_ANKLE_R", "R_ANKLE_P",
  "HEAD_Y", "HEAD_P",
  "L_SHOULDER_P", "L_SHOULDER_R", "L_SHOULDER_Y", "L_ELBOW_P", "L_ELBOW_Y",
  "L_WRIST_R", "L_WRIST_Y",
  "R_SHOULDER_P", "R_SHOULDER_R", "R_SHOULDER_Y", "R_ELBOW_P", "R_ELBOW_Y",
  "R_WRIST_R", "R_WRIST_Y",
]

# Joints that gravity loads while standing. These are the ones that
# saturent en premier si le couple manque, et le calcul statique fait a la main
# already gives 41 N.m at the knee against a real 21.4 N.m continuous limit.
GRAVITY_LOADED = {"L_CROTCH_P", "R_CROTCH_P", "L_KNEE_P", "R_KNEE_P",
                  "L_ANKLE_P", "R_ANKLE_P"}


def gather(log, prefix):
  keys = [k for k in log if k.startswith(prefix + "_") and k[len(prefix) + 1:].isdigit()]
  if not keys:
    return None
  keys.sort(key=lambda k: int(k[len(prefix) + 1:]))
  return np.column_stack([np.asarray(log[k], dtype=float) for k in keys])


def main():
  if len(sys.argv) < 2:
    sys.exit(__doc__)
  log = read_log(sys.argv[1])
  t = np.asarray(log["t"], dtype=float)
  dt = float(np.median(np.diff(t)))
  print(f"log : {sys.argv[1]}")
  print(f"{len(t)} echantillons, {t[-1] - t[0]:.0f} s, dt {dt * 1000:.3f} ms\n")

  # ------------------------------------------------- decrochages de boucle
  print("=" * 68)
  print("DECROCHAGES DE LA BOUCLE")
  print("=" * 68)
  loop = log.get("perf_LoopDt")
  if loop is None:
    print("perf_LoopDt absent.")
  else:
    v = np.asarray(loop, dtype=float)
    v = v[np.isfinite(v)]
    nominal = dt * 1000.0
    for factor in (1.2, 2.0, 5.0):
      thr = nominal * factor
      n = int((v > thr).sum())
      print(f"  > {thr:6.1f} ms ({factor:.1f}x nominal) : {n:6d} fois"
            f"   soit {n / (t[-1] - t[0]):.2f} par seconde")
    print(f"  pire : {v.max():.1f} ms")
    print("\n  Quelques decrochages isoles ne se voient pas. Plusieurs par seconde,")
    print("  si -> LogPolicy: threaded avant toute autre conclusion.")

  # --------------------------------------------------- erreur par joint
  print("\n" + "=" * 68)
  print("ERREUR DE SUIVI, ARTICULATION PAR ARTICULATION")
  print("=" * 68)
  err = gather(log, "NewRLQPController_RL_q_tracking_error")
  if err is None:
    print("erreur de suivi absente du log.")
    return

  bias = err.mean(axis=0)          # decalage systematique
  dyn = err.std(axis=0)            # moving part
  amp = np.abs(err).max(axis=0)
  order = np.argsort(-np.abs(bias))

  print(f"{'joint':<16}{'biais deg':>11}{'dynamique':>11}{'|max| deg':>11}   charge")
  for i in order:
    name = JOINTS[i] if i < len(JOINTS) else f"idx{i}"
    flag = "  <-- gravite" if name in GRAVITY_LOADED else ""
    print(f"{name:<16}{np.degrees(bias[i]):>11.2f}{np.degrees(dyn[i]):>11.2f}"
          f"{np.degrees(amp[i]):>11.2f}{flag}")

  # ------------------------------------------------------------ verdict
  print("\n" + "=" * 68)
  print("VERDICT")
  print("=" * 68)
  idx_g = [i for i, n in enumerate(JOINTS) if n in GRAVITY_LOADED and i < err.shape[1]]
  idx_o = [i for i in range(err.shape[1]) if i not in idx_g]
  bg = np.abs(bias[idx_g]).mean()
  bo = np.abs(bias[idx_o]).mean()
  print(f"mean bias, gravity-loaded joints: {np.degrees(bg):6.2f} deg")
  print(f"biais moyen, toutes les autres                     : {np.degrees(bo):6.2f} deg")
  ratio = bg / bo if bo > 1e-9 else float("inf")
  print(f"rapport : {ratio:.1f}x")

  part_bias = (bias ** 2).sum() / max((err ** 2).mean(axis=0).sum(), 1e-12)
  print(f"\nshare of the error that is a constant bias: {100 * part_bias:.0f} %")
  print("  eleve + concentre sur les jambes -> saturation de couple, le genou")
  print("    sagging. Matches the 41 N.m computed against 21.4 N.m continuous.")
  print("  reparti, ou surtout dynamique -> le QP ne suit pas ; regarder les")
  print("    task weights and saturating constraints.")

  # QP limits show up as an error that plateaus instead of oscillating.
  sat = (np.abs(err) > 0.9 * amp[None, :]).mean(axis=0)
  worst = np.argsort(-sat)[:5]
  print("\nTemps passe a plus de 90 % de l'erreur max (signe d'une butee) :")
  for i in worst:
    name = JOINTS[i] if i < len(JOINTS) else f"idx{i}"
    print(f"  {name:<16}{100 * sat[i]:5.1f} %")


if __name__ == "__main__":
  main()
