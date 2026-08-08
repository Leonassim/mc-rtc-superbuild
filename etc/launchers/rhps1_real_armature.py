#!/usr/bin/env python3
"""Donne a mc_mujoco les armatures reelles du RHPS1, sans toucher au modele.

Le XML de `rhps1_mj_description` declare `armature="1"` dans son bloc `<default>`,
donc sur les 30 articulations pilotees. Le vrai genou vaut 0.10672 : un facteur
dix sur l'inertie rotor, dans le sens qui trompe, puisqu'une armature trop grande
amortit et stabilise. mc_mujoco simule donc un robot nettement plus indulgent que
le vrai, et plus indulgent aussi que le modele sur lequel la politique s'entraine
depuis le 2026-08-07.

Ce script ne modifie ni le depot de description ni l'arbre d'installation. Il
ecrit deux fichiers derives dans le dossier de configuration utilisateur de
mc_mujoco, que `MjSimImpl` consulte AVANT la version installee
(`mj_sim.cpp`, get_robot_cfg_path) :

  <user>/RHPS1main_real_armature.xml   le modele, armature par articulation
  <user>/rhps1.yaml                    pointe xmlModelPath dessus

`meshdir` est reecrit en chemin absolu, sinon le XML derive ne retrouverait pas
les maillages depuis son nouveau dossier.

Regenere a chaque lancement par le shim mc_mujoco, donc jamais perime.

Valeurs : document de calibration RHPS1_gains, armature = n_channels * JM * N^2,
JM verifie contre la fiche SANMOTION. Les huit articulations a verins (hanche et
cheville, roulis et tangage) gardent 1.0 -- convertir leur effort cote verin en
inertie cote articulation demande la geometrie des points d'attache, absente des
depots. Meme decoupage que cote entrainement.
"""

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


def main() -> int:
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
    print("rhps1_real_armature: meshdir introuvable dans le XML", file=sys.stderr)
    return 1

  # Une armature par articulation. Le `armature="1"` du bloc <default> reste et
  # continue de servir a tout le reste : verins, mains, doigts.
  missing = []
  for joint, value in ARMATURE.items():
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
  (user / "rhps1.yaml").write_text(
    "# Genere a chaque lancement par le shim mc_mujoco. Ne pas editer.\n"
    "# Masque la version installee (mj_sim.cpp, get_robot_cfg_path).\n"
    f'xmlModelPath: "{out_xml}"\n'
    f'pdGainsPath: "{pdgains}"\n')
  print(f"mc_mujoco: armatures reelles sur {len(ARMATURE)} articulations, "
        f"{len(CYLINDER)} a verins laissees a 1.0")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
