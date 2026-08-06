# Mission : diagnostiquer la vibration du RHPS1 sur le robot reel

Demande envoyee depuis le PC de developpement le 2026-08-06. Tu tournes sur le PC
qui a fait tourner le controleur pendant l'essai. On a besoin de mesures, pas
d'hypotheses : tout ce qui suit est en **lecture seule**.

## Regles, non negociables

- **Vrai materiel.** Rien qui bouge le robot. Aucune commande qui ecrit sur la
  machine sans accord explicite de Leo.
- **Ne jamais tuer un processus sans accord explicite.** Une demande de
  verification est une demande de lecture, point.
- Pas de `Co-Authored-By: Claude` dans les commits.
- Si une commande te parait utile mais ecrit quelque part, propose-la, ne
  l'execute pas.

## Ce qui s'est passe

Le controleur `NewRLQPController` a tourne sur le robot avec la **politique index
0** (observation V3, 126 dims, `use_QP: true`). Verdict de Leo : ca a marche, la
politique est conservative, **mais le robot vibrait pas mal et avait un
comportement saccade**.

Quatre causes candidates, aucune mesuree :

1. **La frequence de controle.** Le pas de politique est a 200 Hz partout, mais la
   boucle de controle mc_rtc est passee de 1 kHz (mc_mujoco) a 200 Hz sur le
   robot. Donc **une seule resolution du QP par pas de politique au lieu de
   cinq**. C'est la difference structurelle entre l'endroit ou ca semblait propre
   et celui ou ca vibre.
2. **Le QP lui-meme.** Cette politique s'est entrainee contre un PD nu, sans QP.
   En `use_QP: true` la cible devient une `PostureTask` integree en `OpenLoop`,
   qui insere sa propre dynamique de convergence -- et n'a qu'une iteration pour
   converger.
3. **Les observateurs.** `base_lin_vel` sort de l'observateur de base flottante ;
   en entrainement c'etait la verite MuJoCo plus un bruit blanc calibre.
4. **La politique elle-meme**, qui chatterirait.

## Ce qu'on sait deja, et qui oriente tout

`RHPS1.conf` de l'IOB declare **`period 0.001`** : l'entree/sortie materielle
cycle a 1 kHz. Les 200 Hz viennent du **`rate 200`** de `RobotHardware.conf`, qui
est un choix de contexte d'execution RTC, pas une limite de la machine.

**Donc remonter la frequence de controle est peut-etre un simple changement de
configuration.** C'est de loin le chemin le moins cher : il restaure exactement le
regime valide en simulation, sans toucher a la politique ni au QP. `mc_openrtm`
verifie durement l'accord entre le `Timestep` de mc_rtc et le `rate` de
RobotHardware, donc les deux doivent bouger ensemble.

La question qui decide : **est-ce que le CPU tient ?**

## Ce qu'on te demande

### A. Confirmer les deux valeurs de configuration

Trouve et rapporte, sans les modifier, le `rate` et le `dt` de
`RobotHardware.conf` et le `period` de `RHPS1.conf`. Rapporte aussi le CPU de la
machine et si un noyau PREEMPT_RT est actif.

### B. Faire tourner le diagnostic sur le log de l'essai

Le log est un `.bin` dans `/tmp`, du genre
`/tmp/mc-control-NewRLQPController-*.bin`. Prends **celui de l'essai qui a
vibre**, pas forcement le `latest`.

Sauvegarde le script en fin de fichier sous `diag_vibration.py` et lance-le avec
le chemin du log en argument. Il lui faut `mc_log_ui`, qui vient avec mc_rtc :
lance-le dans un shell ou `setup_mc_rtc.sh` a ete source.

### C. Le controle qui prouve la cause sans toucher au robot

C'est l'experience la plus utile de la liste. Depuis le dernier commit du
superbuild, **`mc_rtc_ticker` tourne exactement dans le regime du robot reel** :
`MainRobot: RHPS1`, `Timestep 0.005`, donc un tick de QP par pas de politique. Et
`mc_mujoco` tourne a 1 kHz via une surcouche appliquee automatiquement.

Si tu peux lancer les deux, avec la meme politique index 0 :

- **ticker a 0.005** : si ca vibre aussi, la cause est la frequence de controle
  et/ou le QP, **demontre sans materiel**
- **mc_mujoco a 0.001** : la reference qui ne vibrait pas

Passe les deux logs dans le meme script et compare. C'est ce qui separe proprement
les pistes 1 et 2 des pistes 3 et 4.

## Points de comparaison deja mesures

Un run mc_mujoco a **1 kHz** sur le PC de developpement. Attention, c'est la
politique index 2 (V4), pas la 0 : indicatif seulement.

| grandeur | valeur |
|---|---|
| `perf_GlobalRun` moyen | 0,602 ms (60 % du budget a 1 kHz) |
| `perf_ControllerRun` moyen | 0,351 ms |
| `perf_SolverBuildAndSolve` moyen | 0,286 ms |
| part HF (>20 Hz) de l'action, mediane | **0,000** |
| part HF de `joint_vel`, mediane | 0,054 |
| part HF de l'erreur de suivi, mediane | 0,019 |

L'action y est parfaitement lisse. Si sur le robot la part HF de l'action reste
proche de zero, **la politique est hors de cause** et il faut chercher en aval.

**Attention en comparant** : le robot echantillonne a 200 Hz, ce log a 1 kHz. Les
frequences de Nyquist different (100 Hz contre 500 Hz), donc tout contenu au-dessus
de 100 Hz se replie dans la bande visible sur le robot et **gonfle artificiellement**
les parts HF. La comparaison reste indicative. Le run ticker a 0.005 demande en C
est la seule comparaison rigoureuse, parce qu'il echantillonne au meme rythme.

## Ce qu'on veut en retour

Colle la sortie complete du script, plus :

1. Les valeurs de A : `rate`, `dt`, `period`, CPU, noyau.
2. **`perf_GlobalRun` moyen et p99 sur le robot**, et ton verdict : y a-t-il la
   marge pour 500 Hz ? pour 1 kHz ?
3. La part HF mediane de l'action : lisse ou pas.
4. La part HF de `joint_vel` et l'ecart-type de `base_lin_vel`.
5. La frequence du pic dominant de l'erreur de suivi.
6. Si tu as pu faire C : la meme chose pour le ticker et pour mc_mujoco.

Ne conclus pas au-dela des chiffres. Si une mesure manque, dis qu'elle manque.

## Le script

Sauvegarde ce bloc dans `diag_vibration.py`.

```python
#!/usr/bin/env python3
"""Diagnostic de la vibration observee sur le robot reel (RHPS1, NewRLQPController).

Repond a quatre questions sur un seul run, a partir du .bin de mc_rtc :

  1. Le QP tient-il le budget temps ? -> peut-on remonter la frequence de controle
  2. Est-ce la COMMANDE qui oscille, ou le robot sur une commande propre ?
  3. Les entrees du reseau (joint_vel, base_lin_vel) sont-elles bruitees ?
  4. A quelle frequence ca vibre, et est-ce visible ou repliee ?

Usage :  python3 diag_vibration.py /chemin/vers/mc-control-...bin
Lecture seule. Ne touche a rien.
"""

import sys

import numpy as np

try:
  from mc_log_ui import read_log
except ImportError:
  sys.exit("mc_log_ui introuvable. Sur un shell ou setup_mc_rtc.sh est source, "
           "PYTHONPATH doit contenir <prefix>/lib/python3.*/site-packages.")

# Prefixe commun a toutes les versions d'observation (V3 126, V4 266, V5 566) :
# base_lin_vel[15] base_ang_vel[3] projected_gravity[3] joint_pos[30] joint_vel[30]
JOINT_VEL = slice(51, 81)
BASE_LIN_VEL_NOW = slice(12, 15)  # historique 5, du plus ancien au plus recent

# refJointOrder du RHPS1, tel que le contrôleur l'utilise pour actions/q_rl.
JOINTS = [
  "CHEST_Y", "CHEST_P", "HEAD_Y", "HEAD_P",
  "L_SHOULDER_P", "L_SHOULDER_R", "L_SHOULDER_Y", "L_ELBOW_P", "L_ELBOW_Y",
  "L_WRIST_R", "L_WRIST_Y",
  "R_SHOULDER_P", "R_SHOULDER_R", "R_SHOULDER_Y", "R_ELBOW_P", "R_ELBOW_Y",
  "R_WRIST_R", "R_WRIST_Y",
  "L_CROTCH_Y", "L_CROTCH_R", "L_CROTCH_P", "L_KNEE_P", "L_ANKLE_R", "L_ANKLE_P",
  "R_CROTCH_Y", "R_CROTCH_R", "R_CROTCH_P", "R_KNEE_P", "R_ANKLE_R", "R_ANKLE_P",
]


def gather(log, prefix, n=None):
  """Recompose un vecteur loggue sous prefix_0, prefix_1, ... en (T, N)."""
  keys = [k for k in log if k.startswith(prefix + "_") and k[len(prefix) + 1:].isdigit()]
  if not keys:
    return None
  keys.sort(key=lambda k: int(k[len(prefix) + 1:]))
  if n is not None:
    keys = keys[:n]
  return np.column_stack([np.asarray(log[k], dtype=float) for k in keys])


def spectrum(x, fs):
  """Densite spectrale mono-laterale d'un signal centre, par colonne."""
  x = x - x.mean(axis=0, keepdims=True)
  win = np.hanning(len(x))[:, None]
  f = np.fft.rfftfreq(len(x), 1.0 / fs)
  p = np.abs(np.fft.rfft(x * win, axis=0)) ** 2
  return f, p


def hf_fraction(f, p, cut):
  """Part de la puissance au-dessus de `cut` Hz. Le DC est deja retire."""
  tot = p.sum(axis=0)
  tot[tot == 0] = 1e-300
  return p[f >= cut].sum(axis=0) / tot


def peak_freq(f, p, fmin=1.0):
  """Frequence du pic, en ignorant la traine basse frequence du mouvement."""
  m = f >= fmin
  return f[m][np.argmax(p[m], axis=0)]


def section(title):
  print("\n" + "=" * 72)
  print(title)
  print("=" * 72)


def main():
  if len(sys.argv) < 2:
    sys.exit(__doc__)
  log = read_log(sys.argv[1])

  t = np.asarray(log["t"], dtype=float)
  dt = float(np.median(np.diff(t)))
  fs = 1.0 / dt
  print(f"log        : {sys.argv[1]}")
  print(f"echantillons: {len(t)}   duree {t[-1] - t[0]:.1f} s")
  print(f"dt median  : {dt * 1000:.3f} ms   ->  {fs:.0f} Hz de controle")
  print(f"Nyquist    : {fs / 2:.0f} Hz  (rien au-dessus n'est visible, ca se replie)")

  # --------------------------------------------------------------- 1. timing
  section("1. BUDGET TEMPS  --  peut-on remonter la frequence de controle ?")
  budget = dt * 1000.0
  rows = []
  for k in sorted(x for x in log if x.startswith("perf_")):
    v = np.asarray(log[k], dtype=float)
    v = v[np.isfinite(v)]
    if v.size:
      rows.append((k, v.mean(), np.percentile(v, 99), v.max()))
  if rows:
    print(f"{'entree':<34}{'moyenne':>10}{'p99':>10}{'max':>10}   (ms)")
    for k, m, p99, mx in sorted(rows, key=lambda r: -r[1]):
      print(f"{k:<34}{m:>10.3f}{p99:>10.3f}{mx:>10.3f}")
    print("\nperf_GlobalRun est le cout par tick de la boucle de controle : c'est LUI")
    print("le budget. perf_FrameworkCost n'est pas un cout par tick, ne pas le lire ici.")
    tot = dict((k, m) for k, m, _, _ in rows).get("perf_GlobalRun")
    if tot:
      print(f"\nbudget par tick a {fs:.0f} Hz : {budget:.3f} ms")
      print(f"occupation moyenne          : {100 * tot / budget:.1f} %")
      for target in (500.0, 1000.0):
        need = 1000.0 / target
        verdict = "possible" if tot < 0.6 * need else "trop juste"
        print(f"  a {target:.0f} Hz -> budget {need:.3f} ms, "
              f"occupation {100 * tot / need:.1f} %  : {verdict}")
  else:
    print("aucune entree perf_* : relancer avec le logging de performance actif.")

  # ------------------------------------------------- 2. commande ou aval ?
  section("2. LA COMMANDE OSCILLE-T-ELLE ?  --  action / cible / erreur de suivi")
  act = gather(log, "NewRLQPController_RL_currentAction")
  qrl = gather(log, "NewRLQPController_RL_q")
  err = gather(log, "NewRLQPController_RL_q_tracking_error")
  cut = 20.0  # au-dela de 20 Hz, ce n'est plus de la locomotion

  if act is None:
    print("pas de currentAction dans ce log.")
  else:
    f, p = spectrum(act, fs)
    hf = hf_fraction(f, p, cut)
    pk = peak_freq(f, p)
    order = np.argsort(-hf)[:8]
    print(f"Part de puissance au-dessus de {cut:.0f} Hz, 8 pires joints "
          f"(action brute du reseau) :")
    print(f"{'joint':<16}{'part HF':>10}{'pic Hz':>10}{'ecart-type':>12}")
    for i in order:
      name = JOINTS[i] if i < len(JOINTS) else f"idx{i}"
      print(f"{name:<16}{hf[i]:>10.3f}{pk[i]:>10.1f}{act[:, i].std():>12.4f}")
    print(f"\nmediane de la part HF sur les 30 joints : {np.median(hf):.3f}")
    print("  < 0.05  -> l'action est lisse, le probleme est en AVAL (QP, PD, meca)")
    print("  > 0.20  -> l'action elle-meme chatterit : politique ou ses entrees")

  for label, arr in (("cible q_rl", qrl), ("erreur de suivi", err)):
    if arr is None:
      continue
    f, p = spectrum(arr, fs)
    hf = hf_fraction(f, p, cut)
    pk = peak_freq(f, p)
    i = int(np.argmax(hf))
    name = JOINTS[i] if i < len(JOINTS) else f"idx{i}"
    print(f"\n{label:<18} part HF mediane {np.median(hf):.3f} | "
          f"pire {name} {hf[i]:.3f} a {pk[i]:.1f} Hz | "
          f"RMS {np.sqrt((arr ** 2).mean()):.4f}")

  # ------------------------------------------------ 3. entrees du reseau
  section("3. LES ENTREES DU RESEAU  --  observation reellement fournie")
  obs = gather(log, "NewRLQPController_RL_currentObservation")
  if obs is None:
    print("pas d'observation loggee.")
  else:
    n = obs.shape[1]
    version = {126: "V3", 266: "V4", 566: "V5"}.get(n, "inconnue")
    print(f"dimension {n} -> observation {version}")
    jv = obs[:, JOINT_VEL]
    f, p = spectrum(jv, fs)
    hf = hf_fraction(f, p, cut)
    pk = peak_freq(f, p)
    order = np.argsort(-hf)[:8]
    print(f"\njoint_vel (obs[51:81]), part de puissance > {cut:.0f} Hz :")
    print(f"{'joint':<16}{'part HF':>10}{'pic Hz':>10}{'ecart-type':>12}")
    for i in order:
      name = JOINTS[i] if i < len(JOINTS) else f"idx{i}"
      print(f"{name:<16}{hf[i]:>10.3f}{pk[i]:>10.1f}{jv[:, i].std():>12.4f}")
    print(f"\nmediane de la part HF sur joint_vel : {np.median(hf):.3f}")
    print("  en entrainement ce canal est la verite MuJoCo plus un bruit blanc ;")
    print("  sur le robot c'est une derivation d'encodeurs. Une part HF elevee ici")
    print("  suffit a faire chatterir une politique parfaitement saine.")

    blv = obs[:, BASE_LIN_VEL_NOW]
    f, p = spectrum(blv, fs)
    hf = hf_fraction(f, p, cut)
    print(f"\nbase_lin_vel (pas courant, obs[12:15]) part HF par axe : "
          f"x {hf[0]:.3f}  y {hf[1]:.3f}  z {hf[2]:.3f}")
    print(f"  ecart-type : x {blv[:, 0].std():.4f}  y {blv[:, 1].std():.4f}  "
          f"z {blv[:, 2].std():.4f}  (m/s)")
    print("  c'est la sortie de l'observateur de base flottante, la ou le")
    print("  sim-to-real est le plus fragile.")

  # ----------------------------------------------------- 4. frequence
  section("4. A QUELLE FREQUENCE CA VIBRE ?")
  if err is not None:
    f, p = spectrum(err, fs)
    tot = p.sum(axis=1)
    m = f >= 1.0
    fpk = f[m][int(np.argmax(tot[m]))]
    print(f"pic dominant de l'erreur de suivi (tous joints) : {fpk:.1f} Hz")
    if fpk > 0.4 * fs / 2:
      print("  proche de Nyquist : instabilite en temps discret de la boucle,")
      print("  ce qui pointe la frequence de controle, pas la politique.")
    print(f"\nrappel : echantillonne a {fs:.0f} Hz, tout ce qui depasse "
          f"{fs / 2:.0f} Hz est replie et apparait a une fausse frequence.")
  else:
    print("pas d'erreur de suivi loggee.")

  uq = log.get("NewRLQPController_useQP")
  if uq is not None:
    v = np.asarray(uq, dtype=float)
    print(f"\nuse_QP : {'actif' if v.mean() > 0.5 else 'contourne'} "
          f"({100 * v.mean():.0f} % du run)")


if __name__ == "__main__":
  main()
```
