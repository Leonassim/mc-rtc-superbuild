"""Push one corrected Kt table into every place that carries it.

The same motor torque constants live in four files, three of them as copies and
one pre-multiplied. Editing them by hand is how they drift apart. Give this a
table and it writes all four, or reports what is inconsistent.

  python3 scripts/ppc/apply_kt.py --show
  python3 scripts/ppc/apply_kt.py --set L_KNEE_P=0.424 R_KNEE_P=0.424
  python3 scripts/ppc/apply_kt.py --from-csv corrected_drive_gains_map.csv

--from-csv reads columns `joint` and one of `torque_constant_Nm_per_Arms` or
`torque_constant_Kt`. Nothing is written unless every named joint is found in
every target, so a typo cannot half-apply.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

SUPERBUILD = Path(__file__).resolve().parents[2]
RL = Path.home() / "src" / "rl_controller"
MJLAB = Path.home() / "mjlab-rhps1"

CSV = SUPERBUILD / "scripts/ppc/joint_torque_limits_rotate.csv"
LOGPY = SUPERBUILD / "scripts/ppc/torques_from_log.py"
YAML = RL / "etc/NewRLQPController.in.yaml"
CONSTS = MJLAB / "src/mjlab/asset_zoo/robots/RHPS1/rhps1_constants.py"


def read_current() -> dict[str, tuple[float, float]]:
  """joint -> (N, Kt) from the csv, the one file that carries both."""
  out = {}
  for r in csv.DictReader(CSV.open()):
    kt = r["torque_constant_Kt"].strip()
    if kt:
      out[r["joint"]] = (float(r["gear_ratio_N"]), float(kt))
  return out


def write_csv(kt: dict[str, float]) -> int:
  rows = list(csv.DictReader(CSV.open()))
  fields = rows[0].keys()
  n = 0
  for r in rows:
    if r["joint"] in kt:
      r["torque_constant_Kt"] = f"{kt[r['joint']]:g}"
      N = float(r["gear_ratio_N"])
      for col, cur in (("tau_max_continuous_Nm_eta1", "current_limit_continuous_A"),
                       ("tau_max_peak_Nm_eta1", "current_limit_peak_A")):
        if r.get(cur):
          r[col] = f"{N * kt[r['joint']] * float(r[cur]):.2f}"
      n += 1
  with CSV.open("w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(fields))
    w.writeheader()
    w.writerows(rows)
  return n


def write_logpy(kt: dict[str, float]) -> int:
  s, n = LOGPY.read_text(), 0
  for j, v in kt.items():
    pat = rf'("{re.escape(j)}":\s*\(\s*[\d.]+,\s*)[\d.]+'
    s, c = re.subn(pat, lambda m: f"{m.group(1)}{v:.4f}", s)
    n += c
  LOGPY.write_text(s)
  return n


def write_yaml(kt: dict[str, float], N: dict[str, float]) -> int:
  """joint_torque_scale holds the product N*Kt, with the factors in a comment.

  Scoped to that block on purpose: kp, kd and q0 further down the same file are
  keyed by the same joint names, and a file-wide substitution rewrites the PD
  gains with torque scales.
  """
  if not YAML.exists():
    return -1
  text = YAML.read_text()
  lines = text.splitlines(keepends=True)
  start = next((i for i, l in enumerate(lines)
                if l.startswith("joint_torque_scale:")), None)
  if start is None:
    return -1
  end = next((i for i in range(start + 1, len(lines))
              if lines[i].strip() and not lines[i].startswith((" ", "\t"))), len(lines))
  block, n = "".join(lines[start:end]), 0
  for j, v in kt.items():
    pat = rf"^(\s+{re.escape(j)}:\s+)[-\d.]+(\s*#.*)?$"
    block, c = re.subn(pat, lambda m: f"{m.group(1)}{N[j] * v:.3f}"
                       f"   # {N[j]:g} * {v:g}", block, flags=re.M)
    n += c
  YAML.write_text("".join(lines[:start]) + block + "".join(lines[end:]))
  return n


def write_consts(kt: dict[str, float]) -> int:
  """ElmoReplicaActuatorCfg blocks are keyed by target_names_expr."""
  if not CONSTS.exists():
    return -1
  s, n = CONSTS.read_text(), 0
  for j, v in kt.items():
    pat = (rf'(target_names_expr=\("{re.escape(j)}",\).*?torque_constant=)'
           r"[\d.]+")
    s, c = re.subn(pat, lambda m: f"{m.group(1)}{v:g}", s, flags=re.S)
    n += c
  CONSTS.write_text(s)
  return n


def main() -> int:
  ap = argparse.ArgumentParser()
  ap.add_argument("--show", action="store_true")
  ap.add_argument("--set", nargs="*", default=[], metavar="JOINT=KT")
  ap.add_argument("--from-csv", type=Path)
  args = ap.parse_args()

  cur = read_current()
  if args.show or (not args.set and not args.from_csv):
    print(f"{'joint':<16}{'N':>12}{'Kt':>10}{'N*Kt':>10}")
    for j, (N, k) in cur.items():
      print(f"{j:<16}{N:>12g}{k:>10g}{N * k:>10.3f}")
    print(f"\ncsv     {CSV}\nlog     {LOGPY}\nyaml    {YAML}\nconsts  {CONSTS}")
    return 0

  kt: dict[str, float] = {}
  if args.from_csv:
    for r in csv.DictReader(args.from_csv.open()):
      v = (r.get("torque_constant_Nm_per_Arms")
           or r.get("torque_constant_Kt") or "").strip()
      if v:
        kt[r["joint"].strip()] = float(v)
  for kv in args.set:
    j, _, v = kv.partition("=")
    kt[j] = float(v)

  unknown = [j for j in kt if j not in cur]
  if unknown:
    print(f"unknown joints, nothing written: {', '.join(unknown)}")
    return 1

  N = {j: n for j, (n, _) in cur.items()}
  print(f"{'joint':<16}{'Kt before':>11}{'Kt after':>10}{'N*Kt after':>12}")
  for j, v in kt.items():
    print(f"{j:<16}{cur[j][1]:>11g}{v:>10g}{N[j] * v:>12.3f}")
  counts = {"csv": write_csv(kt), "log": write_logpy(kt),
            "yaml": write_yaml(kt, N), "consts": write_consts(kt)}
  print("\n" + "  ".join(f"{k} {v}" for k, v in counts.items()) + "  (rows touched)")
  over = [k for k, v in counts.items() if v > len(kt)]
  if over:
    print(f"WARNING: {', '.join(over)} touched more rows than joints given -- "
          f"a selector escaped its block, check the diff before committing.")
    return 1
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
