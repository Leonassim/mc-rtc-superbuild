# Resultat : diagnostic de la vibration, run du 2026-08-06 18:57

Log analyse : `/tmp/mc-control-NewRLQPController-2026-08-06-18-57-28.bin`
(1.95 Go, 204343 echantillons, 1021.7 s, dt median 5.000 ms -> 200 Hz).
C'est le run ou la politique a tourne et vibre. Lecture seule, rien touche.

## 1. Valeurs de configuration (section A)

| | |
|---|---|
| `RobotHardware.conf` | `exec_cxt.periodic.rate: 200`, `dt: 0.005` |
| `RHPS1.conf` | `period 0.001` (1 kHz materiel) |
| CPU | Intel i7-8559U, 4 coeurs / 8 threads, 2.70 GHz |
| Noyau | 6.17.5-rt7 **PREEMPT_RT actif** (`/sys/kernel/realtime` = 1) |

## 2. Budget temps : marge pour monter en frequence ?

`perf_GlobalRun` : **moyenne 0.978 ms, p99 1.644 ms**, max 82.330 ms.
Budget par tick a 200 Hz : 5.000 ms -> occupation moyenne **19.6 %**.

**Verdict 500 Hz : faisable.** Budget 2.000 ms ; moyenne a 49 %, p99 a 82 %
du budget. La marge existe mais n'est pas confortable.

**Verdict 1 kHz : non.** Budget 1.000 ms ; la moyenne seule est a 97.8 %, et
surtout **le p99 (1.644 ms) depasse deja le budget**. Ce n'est pas tenable.

**Le max de 82.3 ms n'est pas le QP.** `perf_Log` culmine a 81.490 ms sur le
meme run, et `perf_SolverBuildAndSolve` ne depasse jamais 1.831 ms. Les pics
extremes viennent de l'ecriture du log. `LogPolicy: threaded` (recommande par
mc_rtc sur systeme temps reel) est a essayer avant d'incriminer le controle.

## 3. La commande oscille-t-elle ? Non.

Part de puissance au-dessus de 20 Hz, **mediane 0.000** sur les 30 joints pour
l'action brute du reseau. Idem pour la cible `q_rl` (0.000) et pour l'erreur de
suivi (0.000). Seuil du script : `< 0.05` -> action lisse, chercher en aval.

**La politique est hors de cause.** Le probleme est en aval, ou dans ses entrees.

## 4. Les entrees du reseau

Observation **V3, 126 dims** -> politique index 0, conforme.

`joint_vel` (obs[51:81]), part HF **mediane 0.055**, avec des pointes :

| joint | part HF | pic Hz |
|---|---|---|
| HEAD_P | **0.480** | 4.5 |
| HEAD_Y | **0.350** | 1.9 |
| R_SHOULDER_P | 0.128 | 1.9 |
| L_ANKLE_R | 0.127 | 1.9 |

`base_lin_vel` : part HF x 0.001, y 0.000, z 0.005 ; ecart-type x 0.0186,
y 0.0142, z 0.0101 m/s. Ce canal-la est propre.

## 5. Frequence du pic dominant

Erreur de suivi, tous joints : **1.9 Hz**. C'est lent, pas du chatter haute
frequence. Rappel : echantillonnage a 200 Hz, Nyquist 100 Hz, tout contenu
au-dessus est replie.

## 6. Section C : PAS FAITE

Ni le ticker a 0.005 ni mc_mujoco a 1 kHz n'ont ete relances. La comparaison
rigoureuse reste a faire.

## Fait annexe, decouvert en analysant le canal joint_vel

`mc_rtc` ne recoit **aucune vitesse articulaire** sur ce robot. Verifie de bout
en bout :

- les drives la mesurent (PDO 0x6069 ; `elmostat` montre des `SPEED` non nuls)
- l'IOB la stocke dans `state.speed[]`
- `RobotHardware` la publie sur son port `dq` (`RobotHardware.cpp:84`, alimente
  par `readJointVelocities` ligne 288)
- `mc_openrtm` sait la consommer : port `alphaIn` -> `setEncoderVelocities`
  (`MCControl.cpp:594`)
- **`nocnoid.py` ne connecte jamais `dq`** : zero occurrence de `dq`,
  `alphaIn` ou `velocit` dans tout le fichier

Consequence : `joint_vel` vient d'une derivation numerique des encodeurs
(`encoderFiniteDifferences`), ce qui explique sa part HF. **Ce n'est pas une
regression** : c'est le defaut de `EncoderObserver` dans mc_rtc, donc le regime
normal de ce robot depuis toujours. Ce qui est nouveau, c'est qu'une politique
prenant `joint_vel` en entree y est bien plus sensible qu'un PD ou un QP.

La ligne manquante, a cote des `taucIn` / `accIn` / `rateIn` deja presentes :

```python
connectPorts(rh.port("dq"), mc.port("alphaIn"))
```

**Non teste, et non applique.** `nocnoid.py` est installe depuis
`hrpcnoid_rhps1`, donc une modif directe serait perdue au prochain build de ce
projet. La coherence des unites entre `readJointVelocities` et ce qu'attend
`setEncoderVelocities` n'a pas ete verifiee non plus.

## Sortie complete du script

```
log        : /tmp/mc-control-NewRLQPController-2026-08-06-18-57-28.bin
echantillons: 204343   duree 1021.7 s
dt median  : 5.000 ms   ->  200 Hz de controle
Nyquist    : 100 Hz  (rien au-dessus n'est visible, ca se replie)

========================================================================
1. BUDGET TEMPS  --  peut-on remonter la frequence de controle ?
========================================================================
entree                               moyenne       p99       max   (ms)
perf_FrameworkCost                    40.651    55.148   100.000
perf_LoopDt                            5.047     5.309    85.035
perf_GlobalRun                         0.978     1.644    82.330
perf_ControllerRun                     0.555     0.978     3.159
perf_SolverBuildAndSolve               0.395     0.681     1.831
perf_SolverSolve                       0.395     0.681     1.831
perf_Log                               0.205     0.316    81.490
perf_ObserversRun                      0.129     0.281     0.959
perf_Executor_Main                     0.092     0.243     1.140
perf_Executor_Main_run                 0.092     0.243     1.140
perf_Plugins_ROS_after                 0.025     0.089     0.319
perf_Gui                               0.010     0.113     0.408
perf_UpdateContacts                    0.000     0.001     0.033
perf_Executor_Main_create              0.000     0.000     0.958
perf_Executor_Main_teardown            0.000     0.000     0.000

perf_GlobalRun est le cout par tick de la boucle de controle : c'est LUI
le budget. perf_FrameworkCost n'est pas un cout par tick, ne pas le lire ici.

budget par tick a 200 Hz : 5.000 ms
occupation moyenne          : 19.6 %
  a 500 Hz -> budget 2.000 ms, occupation 48.9 %  : possible
  a 1000 Hz -> budget 1.000 ms, occupation 97.8 %  : trop juste

========================================================================
2. LA COMMANDE OSCILLE-T-ELLE ?  --  action / cible / erreur de suivi
========================================================================
Part de puissance au-dessus de 20 Hz, 8 pires joints (action brute du reseau) :
joint              part HF    pic Hz  ecart-type
HEAD_Y               0.000       1.9      1.4487
L_SHOULDER_R         0.000       1.9      4.0775
L_ANKLE_R            0.000       1.9      0.8269
R_KNEE_P             0.000       1.9      4.8021
L_SHOULDER_P         0.000       1.9      2.0232
R_WRIST_Y            0.000       1.9      6.8776
R_CROTCH_R           0.000       1.0      4.5269
R_CROTCH_P           0.000       1.9      1.7936

mediane de la part HF sur les 30 joints : 0.000
  < 0.05  -> l'action est lisse, le probleme est en AVAL (QP, PD, meca)
  > 0.20  -> l'action elle-meme chatterit : politique ou ses entrees

cible q_rl         part HF mediane 0.000 | pire R_ELBOW_P 0.000 a 1.9 Hz | RMS 0.3181

erreur de suivi    part HF mediane 0.000 | pire R_ELBOW_P 0.000 a 1.9 Hz | RMS 0.2724

========================================================================
3. LES ENTREES DU RESEAU  --  observation reellement fournie
========================================================================
dimension 126 -> observation V3

joint_vel (obs[51:81]), part de puissance > 20 Hz :
joint              part HF    pic Hz  ecart-type
HEAD_P               0.480       4.5      0.0319
HEAD_Y               0.350       1.9      0.0125
R_SHOULDER_P         0.128       1.9      0.0292
L_ANKLE_R            0.127       1.9      0.0243
L_SHOULDER_P         0.122       1.9      0.0194
L_CROTCH_R           0.110       1.2      0.0197
L_WRIST_R            0.107       1.9      0.0113
R_CROTCH_R           0.102       1.6      0.0190

mediane de la part HF sur joint_vel : 0.055
  en entrainement ce canal est la verite MuJoCo plus un bruit blanc ;
  sur le robot c'est une derivation d'encodeurs. Une part HF elevee ici
  suffit a faire chatterir une politique parfaitement saine.

base_lin_vel (pas courant, obs[12:15]) part HF par axe : x 0.001  y 0.000  z 0.005
  ecart-type : x 0.0186  y 0.0142  z 0.0101  (m/s)
  c'est la sortie de l'observateur de base flottante, la ou le
  sim-to-real est le plus fragile.

========================================================================
4. A QUELLE FREQUENCE CA VIBRE ?
========================================================================
pic dominant de l'erreur de suivi (tous joints) : 1.9 Hz

rappel : echantillonne a 200 Hz, tout ce qui depasse 100 Hz est replie et apparait a une fausse frequence.

use_QP : actif (100 % du run)
```
