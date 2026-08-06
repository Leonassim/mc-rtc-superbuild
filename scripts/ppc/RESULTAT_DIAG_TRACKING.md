# Resultat : ou part l'erreur de suivi (run du 2026-08-06 18:57)

> **Cette version corrige la precedente, qui etait fausse.** `diag_tracking.py`
> etiquetait les joints avec le `ref_joint_order` de la politique alors que
> `RL_q_tracking_error` est indexe en `refJointOrder` du module. Chaque nom
> etait donc decale, et la conclusion "asymetrie jambe droite / jambe gauche"
> qui en decoulait n'existait pas. Le script est corrige dans le meme commit.
>
> Preuve de l'ordre : `RL_qZero` reproduit le `q0` du yaml a l'erreur 0.000000
> pres en `refJointOrder`, contre 8.36 en ordre politique. `RL_qZero_3` vaut
> 0.622021 (genou) et `RL_qZero_19` vaut -0.523599 (coude gauche).
> Origine : `NewRLQPController.cpp:146`, `jointNames = robot().refJointOrder()`.

`diag_tracking.py` sur `/tmp/mc-control-NewRLQPController-2026-08-06-18-57-28.bin`
(204343 echantillons, 1022 s, dt 5.000 ms). Lecture seule.

## Decrochages de la boucle

| seuil | occurrences | frequence |
|---|---|---|
| > 6 ms | 195 | 0.19 / s |
| > 10 ms | 193 | 0.19 / s |
| > 25 ms | 190 | 0.19 / s |
| pire | 85.0 ms | |

Les trois comptes sont quasi identiques : presque tous les decrochages
depassent 25 ms, ce ne sont pas des depassements marginaux. Un toutes les
5 secondes. Sous le critere du script ("plusieurs par seconde"), donc
probablement pas la cause dominante. `perf_Log` culminait a 81.5 ms sur ce
run : `LogPolicy: threaded` reste a essayer.

## L'erreur est un biais, pas une dynamique

**92 % de l'erreur est un biais constant.** Le pic a 1.9 Hz est la cadence de
pas, pas une oscillation parasite.

## L'hypothese "saturation de couple" ne tient toujours pas

| | biais moyen |
|---|---|
| articulations chargees par la gravite | 14.80 deg |
| toutes les autres | 10.58 deg |

Rapport **1.4x** : eleve, mais pas concentre sur les jambes. Le critere du
script demande les deux.

## Ce que montre le tableau correctement etiquete

| | bras | jambe |
|---|---|---|
| **gauche** | **2.22 deg** | 16.45 deg |
| **droite** | **18.36 deg** | 15.19 deg |

**Les deux jambes se comportent pareil** (16.45 vs 15.19 deg) : il n'y a pas
d'asymetrie de jambe. Le bras gauche suit tres bien (2.22 deg). **Le bras
droit est aussi mauvais que les jambes** (18.36 deg) alors qu'il ne porte
aucune charge gravitaire.

Les cinq plus gros biais :

| joint | biais | dynamique |
|---|---|---|
| R_ELBOW_P | **-37.29 deg** | 0.77 |
| L_CROTCH_Y | -28.28 deg | 6.70 |
| R_SHOULDER_Y | 22.85 deg | 1.61 |
| R_ELBOW_Y | 22.61 deg | 1.69 |
| L_ANKLE_R | -21.37 deg | 5.00 |

Le bras droit a des **dynamiques tres faibles** (0.77 a 2.44) : ce sont des
decalages fixes, l'articulation ne bouge quasiment pas autour de son ecart.
Les jambes ont des dynamiques plus elevees (2.63 a 13.63), elles travaillent.

Temps passe au-dela de 90 % de l'erreur max :

| joint | % du temps |
|---|---|
| R_ELBOW_P | **100.0 %** |
| R_SHOULDER_Y | 94.8 % |
| R_SHOULDER_P | 94.8 % |
| R_ANKLE_R | 94.7 % |
| R_CROTCH_Y | 94.7 % |

Quatre sur cinq a droite, trois au bras droit. `R_ELBOW_P` reste en
permanence a son ecart maximal.

## Ce que les chiffres ne disent pas

Ils excluent la saturation de couple comme explication principale : les jambes
sont symetriques et le bras droit, non charge, est autant en defaut.

Le bras droit maintenu a un decalage quasi constant est le fait le plus
saillant. La pose relevee sur le robot notait deja "bras droit leve un peu
vers l'avant". Rien ici n'en identifie la cause.

Pistes non testees :

- une tache ou une contrainte qui immobilise le bras droit (le controleur
  ajoute une tache `FSM_body6d_rhps1_BODY` au demarrage)
- butee articulaire atteinte sur R_ELBOW_P
- decalage de calibration cote droit
- le biais de jambe, symetrique, reste inexplique et pourrait avoir une autre
  cause que celui du bras

La section C de la mission (ticker a 0.005 contre mc_mujoco a 1 kHz) reste la
comparaison qui separerait "le QP ne suit pas" de "les capteurs".

## Sortie complete, apres correction

```
log : /tmp/mc-control-NewRLQPController-2026-08-06-18-57-28.bin
204343 echantillons, 1022 s, dt 5.000 ms

====================================================================
DECROCHAGES DE LA BOUCLE
====================================================================
  >    6.0 ms (1.2x nominal) :    195 fois   soit 0.19 par seconde
  >   10.0 ms (2.0x nominal) :    193 fois   soit 0.19 par seconde
  >   25.0 ms (5.0x nominal) :    190 fois   soit 0.19 par seconde
  pire : 85.0 ms

  Quelques decrochages isoles ne se voient pas. Plusieurs par seconde,
  si -> LogPolicy: threaded avant toute autre conclusion.

====================================================================
ERREUR DE SUIVI, ARTICULATION PAR ARTICULATION
====================================================================
joint             biais deg  dynamique  |max| deg   charge
R_ELBOW_P            -37.29       0.77      37.71
L_CROTCH_Y           -28.28       6.70      30.33
R_SHOULDER_Y          22.85       1.61      23.72
R_ELBOW_Y             22.61       1.69      31.27
L_ANKLE_R            -21.37       5.00      23.47
R_CROTCH_Y           -20.87       4.93      23.29
R_SHOULDER_P          20.50       1.24      22.23
L_ANKLE_P             20.22       4.97      25.58  <-- gravite
R_SHOULDER_R         -18.74       2.44      31.51
R_ANKLE_P             18.11       5.06      20.29  <-- gravite
L_KNEE_P              15.42      13.63      28.26  <-- gravite
R_ANKLE_R            -14.28       3.35      15.59
R_KNEE_P              13.43      12.44      19.25  <-- gravite
R_CROTCH_R            13.10       3.53      19.15
R_CROTCH_P           -11.34       3.08      18.31  <-- gravite
L_CROTCH_P           -10.25       2.63      12.33  <-- gravite
L_ELBOW_P             -5.03       1.20       5.49
CHEST_Y                3.63       0.87       4.60
R_WRIST_R              3.50       0.81       4.24
L_CROTCH_R             3.17       1.47       7.69
R_WRIST_Y             -3.06       0.90       6.62
L_SHOULDER_P          -3.03       0.75       4.02
CHEST_P                2.35       2.50      15.71
L_SHOULDER_Y           2.28       0.78       3.03
HEAD_P                 2.17       0.55       6.31
L_WRIST_R             -1.65       0.55       3.90
L_ELBOW_Y              1.59       0.57       3.06
L_WRIST_Y              1.57       0.84       4.32
HEAD_Y                -0.64       0.18       1.27
L_SHOULDER_R          -0.41       0.47       6.72

====================================================================
VERDICT
====================================================================
biais moyen, articulations chargees par la gravite :  14.80 deg
biais moyen, toutes les autres                     :  10.58 deg
rapport : 1.4x

part de l'erreur qui est un biais constant : 92 %
  eleve + concentre sur les jambes -> saturation de couple, le genou
    s'affaisse. Cadre avec les 41 N.m calcules contre 21.4 N.m continus.
  reparti, ou surtout dynamique -> le QP ne suit pas ; regarder les
    poids de taches et les contraintes qui saturent.

Temps passe a plus de 90 % de l'erreur max (signe d'une butee) :
  R_ELBOW_P       100.0 %
  R_SHOULDER_Y     94.8 %
  R_SHOULDER_P     94.8 %
  R_ANKLE_R        94.7 %
  R_CROTCH_Y       94.7 %
```
