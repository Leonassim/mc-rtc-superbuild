# Contexte pour la session Claude sur le PC du robot RHPS1

Brief de passation, écrit le 2026-08-06 depuis le PC de développement
(`~/mc-rtc-superbuild`, branche `real-robot-safe`, HEAD `e1f2791`). Tout ce qui
suit vient d'une session de travail sur ce même projet mais **sur une autre
machine** : vérifie l'état réel du PC robot avant d'affirmer quoi que ce soit,
les chemins et les commits peuvent différer.

## Règles de travail (non négociables)

- **On est sur du vrai matériel.** Aucune action brusque, rien qui bouge le
  robot sans validation explicite de Léo.
- **Ne jamais tuer un processus sans accord explicite.** Une demande de
  vérification est une demande de lecture seule, point.
- **Jamais de `Co-Authored-By: Claude`** dans les commits.
- Le robot est **piloté en position** : on ne peut pas baisser les `kp` pour
  adoucir quoi que ce soit côté matériel.
- Prose de README / commits : brève, orientée commande, pas de sur-explication.

## 1. Ce qui tourne sur ce PC

Le contrôleur mc_rtc tourne sur le PC embarqué du robot ; Léo s'y connecte en
ssh depuis son poste. Dernier essai en date : contrôleur lancé, tâche CoM
active.

**Pose relevée sur le robot réel** (référence pour tous les calculs ci-dessous) :

| grandeur | valeur |
|---|---|
| CoM x | −0,0121442 m |
| CoM y | −7,1·10⁻⁵ m |
| CoM z | 0,901023 m |
| KNEE_P | 1,00469 rad |
| ANKLE_P | −0,614383 rad |
| CROTCH_P | −0,2206 rad |
| bras droit | levé un peu vers l'avant |

## 2. RViz depuis le poste distant — résolu

Le problème n'était **pas** la configuration RViz ni le ROS_DOMAIN_ID : c'était
le **port**. Retenir la topologie, elle prête à confusion :

- Le plugin ROS de mc_rtc publie sur `/control/<robot>/robot_description`
  (QoS `transient_local`), `/joint_states`, `/imu`, `/odom`,
  `/force/<capteur>`, et les TF sous le même préfixe. C'est ça que RViz
  consomme (`RobotModel` avec le topic de description, `Fixed Frame` sur la
  racine TF publiée).
- La **GUI mc_rtc n'est pas du DDS** : c'est du TCP sur les ports **4242 /
  4343**. Rien à voir avec RViz. Si on tunnelise en ssh, ce sont ces deux
  ports-là qu'il faut forwarder pour la GUI, et le DDS/`ROS_DOMAIN_ID` pour
  RViz — deux canaux distincts.

## 3. Couples genoux — le point chaud

Calcul statique fait à la main (pas via les PD, pas via MuJoCo) :
`τ_genou = (m_au-dessus / 2)·g·|x_CoM_au-dessus − x_genou|`. Seul le décalage
**horizontal** compte, la GRF étant verticale. La masse sous le genou est
retirée.

| pose | couple par genou |
|---|---|
| pose d'init d'entraînement (KNEE_P = 0,40 rad) | **23,1 N·m** |
| pose réelle relevée ci-dessus (avec CROTCH_P = −0,2206 et un bassin penché de −9,70°) | **41,0 N·m** |

Les deux ne sont pas comparables directement : familles de poses différentes
(inclinaison du bassin, bras). Une réponse à la question « quel q_init pour
40 N·m » avait donné ≈ 59,6° de flexion dans la famille d'entraînement à sole
plate — cette valeur-là **n'est pas cohérente** avec les 41 N·m à 57,6° de la
pose réelle, justement parce que la famille de poses n'est pas la même. Ne pas
mélanger les deux ; si le chiffre est décisif, refaire le calcul dans la pose
exacte visée.

**Limites réelles de l'actionneur genou** (valeurs corrigées par Léo :
Cl = 1,01 A, Pl = 2,01 A ; le document de calibration dit encore 1,03/2,03 —
il est faux, à corriger) :

- `N` = 210, `Kt` = 0,101 N·m/A
- τ continu = 210 × 0,101 × 1,01 = **21,4 N·m**
- τ pic = 210 × 0,101 × 2,01 = **42,6 N·m**, autorisé pendant `PL[2]` = **23,5 s**

Donc **la pose réelle à 41 N·m est à 1,9× le continu**, juste sous le pic. Elle
ne tient que dans la fenêtre de 23,5 s du régime pic. Si le robot a tenu cette
pose **plus longtemps que 23,5 s**, c'est que quelque chose aide : la
rétro-entraînabilité (backdrivability) du réducteur.

Modèle : `η_b = 2 − 1/η_f`, courant requis `i = τ_charge·η_b/(N·Kt)`,
auto-blocage à `η_f ≤ 0,5`. Un maintien avéré au-delà de 23,5 s à 41 N·m borne
`η_f ≤ 0,677`. **Ce n'est pas mesurable sans le courant**, et Léo n'a pas accès
au courant. Le protocole proposé, non exécuté : chronométrer un maintien
soutenu au-delà de 23,5 s à des poses de plus en plus fléchies, et voir où ça
lâche. **À ne tenter qu'avec l'accord de Léo, robot sécurisé.**

## 4. Le contrôleur `rl_controller` / `NewRLQPController`

Sources dans `~/src/rl_controller` (build `~/build`, install `~/install` — le
`~/mc-rtc-superbuild/build` n'est que de la plomberie CMake).

- La politique est **armée depuis la GUI** (`ARM policy` / `HOLD (disarm)`),
  jamais au chargement. C'est volontaire, c'est la sécurité principale.
- `reset()` refuse de démarrer si aucun observateur de base flottante n'est dans
  le pipeline.
- Deux chemins de commande, sélectionnés par le bouton **`use_QP`** de la GUI :
  - **QP actif** : `q_rl` est la cible d'une `PostureTask` intégrée en
    `FeedbackType::OpenLoop`. Les gains `kp_`/`kd_` du contrôleur ne servent
    à rien sur ce chemin.
  - **QP contourné** : `q_rl` part directement au servo (en simu mc_mujoco les
    gains sont 20000/400, cf. `PDgains_sim.dat`).
- Une **projection de faisabilité en couple** est implémentée en C++ dans
  `NewRLQPController.cpp` : `budget = ratio·effort_limit`,
  `v_term = kd(qd*−q̇)`, puis
  `q* ∈ [q + (−budget−v_term)/kp, q + (budget−v_term)/kp]`.
  Deux points appris à la dure :
  1. La différence finie doit se prendre entre deux cibles **brutes**
     (`qTargetPrev_ = qTarget`, jamais la cible projetée) — sinon emballement.
  2. La projection est **invalide sous QP** (l'identité couple↔position ne tient
     que si le plant aval EST ce PD). Elle est donc désarmée par appel quand
     `useQP_` est vrai, et le choix est refait **à chaque appel** parce que la
     GUI bascule le toggle à chaud.
- **Piège d'installation** : `etc/NewRLQPController.in.yaml` a
  `default_policy_index: 0` dans les sources ; la copie installée
  `~/install/lib/mc_controller/etc/NewRLQPController.yaml` doit être repassée à
  `2` après **chaque** `cmake --install`.

## 5. Superbuild — branche `real-robot-safe`

- `etc/mc_rtc_superbuild.yaml` est installé dans `${prefix}/etc` et exporté via
  `MC_RTC_CONTROLLER_CONFIG` par `setup_mc_rtc.sh`, avec
  **`LoadUserConfiguration: false`**. C'est tout l'intérêt : ça neutralise un
  `~/.config/mc_rtc/mc_rtc.yaml` périmé, qui était la raison pour laquelle le PC
  robot tournait une config différente du poste de dev. Ordre des couches :
  CONF_PATH → `MC_RTC_CONTROLLER_CONFIG` → config utilisateur → `-f`.
- `WITH_RHPS1_HARDWARE=OFF` par défaut ; il gouverne
  `extensions/hardware/rhps1_lowlevel.cmake` : `drcutil-superbuild`,
  `isri-aist/RHPS1` (modèle OpenHRP VRML), `isri-aist/hrpsys-rhps1` branche
  **openrtm2** (les RTC `CylinderToAngle`/`AngleToCylinder`), et
  `ThomasDuvinage/hrpcnoid_rhps1` branche ubuntu2204.
- `mc_state_observation` est épinglé sur `ArnaudDmt/mc_state_observation`
  @ `309a692d816ba2cec4de9df97b4b0c85331929a8` (épinglé le 2026-07-22, était
  `origin/addWaiko`). Le fork de Bastien est **53 commits en avance**, pas en
  retard — un commentaire dans `mc_rtc.cmake` sur `main` dit l'inverse, il est
  faux et pas encore corrigé.
- **Ne pas remettre un `GIT_TAG` sur une branche flottante.** Tout est épinglé
  depuis `b73adc1` / tag `working-rhps1-newrlqp-2026-07-22`, exprès.

### Pièges CMake qui ont chacun coûté des heures

- `cmake --preset X` configure, `cmake --build --preset X` construit. Les `-D`
  sont **silencieusement ignorés** sur le second.
- Cloner un projet est une étape de **build** (`clone-<nom>`), pas de configure.
  Vérifier avec `grep WITH_... CMakeCache.txt`.
- Un arbre superbuild **n'est pas relocatable** : les chemins absolus sont
  gravés dans les caches CMake.
- Un `-L` dans un chemin (`sandbox-Leo`) est avalé comme flag de linker.
- `SUDO_CMD` n'est défini que si le préfixe d'install n'est **pas** accessible
  en écriture — sinon les `${SUDO_CMD} sed -i` de drcutil ne font rien, sans
  erreur.
- `PKG_CONFIG_PATH` vient de l'environnement **ambiant** ; il faut exporter
  `${prefix}/lib/pkgconfig` avant le premier build.
- `hrpcnoid_rhps1` s'installe dans `${HRPSYS_BASE_PREFIX}` / `${OPENHRP_DIR}`,
  résolus par **pkg-config** et non par `CMAKE_INSTALL_PREFIX`. Vérifier que
  `pkg-config --variable=prefix hrpsys-base` et `openhrp3.1` sont d'accord.

## 6. État du PC robot au dernier point (2026-07-31 au soir)

Deux choses en suspens, aucune n'est un problème de build :

1. **Des processus périmés tiennent les ports 2809/2810** : `omniNames`, `rtcd2`
   et deux `sudo -E ./hrpsys_mc_rtc.sh` issus de l'**ancien** arbre. Tant qu'ils
   tournent, `nocnoid.py` s'attache à ce RTCManager-là au lieu d'un neuf — c'est
   une seconde raison, indépendante, pour laquelle `CylinderToAngle` ne se
   chargeait pas. `clear-omninames.sh` (fourni par hrpcnoid_rhps1) nettoie aussi
   `/var/lib/omniorb/omninames*.bak`. **Demander l'accord avant de tuer quoi que
   ce soit.**
2. **L'adresse PCI EtherCAT est fausse dans les scripts** : `r_prepare_ecm.sh`
   détache `0000:00:19.0`, alors que la NIC de la machine est
   `00:1f.6 Intel Ethernet Connection (6) I219-V` — d'où
   `echo: write error: No such device`. `ip link` ne montre que `lo` et le wifi,
   donc la NIC est déjà détachée, ce qui est l'état attendu pour EtherCAT.
   **Confirmer avec le collègue de Léo avant de changer l'adresse** : détacher
   la mauvaise coupe le réseau de la machine. `atemsys` est chargé et
   `/dev/atemsys` existe.

Par ailleurs : `/etc/omniORB.cfg` et le `nocnoid.py` installé disent tous deux
`localhost`, mais l'édition du `nocnoid.py` **installé** est perdue au prochain
build de `hrpcnoid_rhps1` (`rtm.nshost = "rhps1c"` est en dur en amont,
`scripts/nocnoid.py:26`). Le correctif durable — forker `hrpcnoid_rhps1` sous
`leonassim` et ré-épingler — n'est pas fait.

### Lire l'écran du PPC

Son écran n'est accessible qu'en photo, d'où `scripts/ppc/diag.sh` (lecture
seule, ramasse tout d'un coup) et `scripts/ppc/report.sh` (pousse la capture sur
une branche `ppc-reports` via la plomberie git — `hash-object`/`mktree`/
`commit-tree` — pour ne jamais toucher à l'index, au worktree ni à HEAD).
**Le push ne marche pas encore** : la clé SSH du PPC n'est pas celle de Léo et
n'a pas d'accès en écriture. Correctif : une **deploy key** par dépôt avec accès
écriture, plus
`git config core.sshCommand "ssh -i <clé> -o IdentitiesOnly=yes"` scopé à ce
clone — une deploy key évite d'avoir à mettre le compte GitHub de Léo sur la
machine, ce qui était le point bloquant.

## 7. Côté apprentissage (contexte, pas d'action sur ce PC)

L'entraînement tourne sur le poste de dev (`~/mjlab-rhps1`), pas ici. Ce qu'il
faut en savoir pour le déploiement :

- Pipeline : mjlab-rhps1 → ONNX exporté à côté de chaque checkpoint dans
  `logs/rsl_rl/rhps1_velocity/<date>/` → lu par `policy_path` du yaml du
  contrôleur, sans rebuild.
- Le format d'observation courant en C++ (`utils.cpp`, cas 0) est le **V3, 126
  dims**. Le run en cours produit une observation **566 dims** (V5) : le C++
  n'est **pas** encore capable de la consommer. Toujours relire les métadonnées
  de l'ONNX (`onnx.load`) avant de déployer un nouveau checkpoint.
- **Contradiction ouverte à garder en tête** : l'`effort_limit` du genou côté
  entraînement est **70 N·m**, soit 3,3× le continu réel de 21,4 N·m. La
  pénalité de couple s'exprime en ratio `|τ|/effort_limit`, donc « 1,0 » à
  l'entraînement veut dire 70 N·m. Sur le vrai genou, 21,4 N·m correspond à un
  ratio de 0,31 et le pic 42,6 N·m à 0,61. Une politique « à la limite » en simu
  est donc largement au-dessus du réel.
- Le XML mc_mujoco est délibérément **sans `forcerange`** : une politique trop
  gourmande doit exploser visiblement en simu plutôt qu'être écrêtée en silence.
  Ne jamais en ajouter.
- Les `armature` du modèle sont encore des placeholders à `1.0` (le vrai genou
  est 0,10672). Les vraies valeurs sont dans le document de calibration ; à
  appliquer à la main, délibérément, avec un ré-entraînement.

## 8. Pièges déjà payés — ne pas les repayer

- Le module `MainRobot: RHPS1` liste 42 joints, 30 sont pilotés. `computeLimits`
  doit parcourir `jointNames`, pas `refJointOrder`.
- `collisions: []` **ne retire pas** les paires du module : les paires de jambes
  RHPS1 bloquaient le pas latéral sous QP.
- Le q0 du contrôleur doit correspondre au keyframe d'entraînement : depuis le
  2026-07-15 c'est KNEE_P 0,40 (l'ancien était 0,622). Vérifier la compatibilité
  avec le halfsit du robot réel.
