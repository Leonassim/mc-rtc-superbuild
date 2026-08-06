# Resultat : ou part l'erreur de suivi (run du 2026-08-06 18:57)

`diag_tracking.py` sur `/tmp/mc-control-NewRLQPController-2026-08-06-18-57-28.bin`
(204343 echantillons, 1022 s, dt 5.000 ms). Lecture seule.

## Decrochages de la boucle

| seuil | occurrences | frequence |
|---|---|---|
| > 6 ms (1.2x) | 195 | 0.19 / s |
| > 10 ms (2.0x) | 193 | 0.19 / s |
| > 25 ms (5.0x) | 190 | 0.19 / s |
| pire | 85.0 ms | |

Les trois comptes sont quasi identiques : **presque tous les decrochages
depassent 25 ms**, ce ne sont pas des depassements marginaux mais de vrais
blocages. Un toutes les 5 secondes environ. Le critere du script
("plusieurs par seconde") n'est pas atteint, donc ce n'est probablement pas
la cause dominante -- mais 190 blocages de plus de 25 ms sur 17 minutes ne
sont pas anodins. `LogPolicy: threaded` reste a essayer : `perf_Log`
culminait a 81.5 ms sur ce meme run.

## L'erreur est un biais, pas une dynamique

**92 % de l'erreur est un biais constant.** Le pic a 1.9 Hz est la cadence de
pas. Ce n'est pas un tremblement.

## Mais l'hypothese "saturation de couple" ne tient pas

Le critere du script demande un biais **eleve ET concentre sur les jambes**.
Le rapport mesure est de **1.4x** seulement :

| | biais moyen |
|---|---|
| articulations chargees par la gravite | 14.45 deg |
| toutes les autres | 10.67 deg |

Trois faits contredisent la saturation :

**1. Asymetrie gauche/droite massive.** La jambe gauche suit presque
parfaitement, la droite est tres decalee :

| droite | biais | gauche | biais |
|---|---|---|---|
| R_CROTCH_P | **-37.29 deg** | L_CROTCH_P | +1.59 deg |
| R_KNEE_P | **+22.61 deg** | L_KNEE_P | -1.65 deg |
| R_CROTCH_R | **+22.85 deg** | L_CROTCH_R | -5.03 deg |
| R_CROTCH_Y | **-18.74 deg** | L_CROTCH_Y | +2.28 deg |

Une saturation de couple serait symetrique : les deux genoux portent une
charge comparable. Un genou a 22.61 deg de biais et l'autre a 1.65 deg ne
s'explique pas par une limite d'actionneur commune.

**2. Les bras sont autant touches que les jambes**, alors qu'ils ne portent
quasiment aucune charge gravitaire : L_SHOULDER_P -21.37, L_ELBOW_Y -20.87,
L_SHOULDER_R +20.22, R_SHOULDER_Y +18.11 deg. Et CHEST_Y a -28.28 deg.

**3. Signature de butee, pas d'affaissement.** Temps passe au-dela de 90 % de
l'erreur max :

| joint | % du temps |
|---|---|
| R_CROTCH_P | **100.0 %** |
| R_CROTCH_R | 94.8 % |
| L_ANKLE_P | 94.8 % |
| R_SHOULDER_R | 94.7 % |
| L_ELBOW_Y | 94.7 % |

`R_CROTCH_P` reste en permanence a son ecart maximal : l'articulation
n'approche jamais sa cible. C'est le comportement d'un ecretage ou d'une
contrainte active, pas d'un actionneur qui flechit sous une charge variable.

## Ce que les chiffres ne disent pas

Rien ici n'identifie la cause. Ils excluent seulement la saturation de couple
comme explication principale, et orientent vers quelque chose de **specifique
au cote droit** et actif aussi sur le haut du corps.

Pistes non testees, par ordre de cout :

- contraintes de limites articulaires du QP qui saturent (le script signale
  des joints bloques a leur ecart max)
- poids de la `PostureTask` face aux autres taches
- decalage de calibration ou d'offset sur les articulations de la jambe droite
- coherence entre le `refJointOrder` de la politique et celui du robot, cote
  droit

La section C de la mission (ticker a 0.005 contre mc_mujoco a 1 kHz) reste la
comparaison qui separerait proprement "le QP ne suit pas" de "les capteurs".

## Sortie complete

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
R_CROTCH_P           -37.29       0.77      37.71  <-- gravite
CHEST_Y              -28.28       6.70      30.33
R_CROTCH_R            22.85       1.61      23.72
R_KNEE_P              22.61       1.69      31.27  <-- gravite
L_SHOULDER_P         -21.37       5.00      23.47
L_ELBOW_Y            -20.87       4.93      23.29
L_ANKLE_P             20.50       1.24      22.23  <-- gravite
L_SHOULDER_R          20.22       4.97      25.58
R_CROTCH_Y           -18.74       2.44      31.51
R_SHOULDER_Y          18.11       5.06      20.29
HEAD_P                15.42      13.63      28.26
R_SHOULDER_R         -14.28       3.35      15.59
R_SHOULDER_P          13.43      12.44      19.25
L_WRIST_R             13.10       3.53      19.15
L_WRIST_Y            -11.34       3.08      18.31
HEAD_Y               -10.25       2.63      12.33
L_CROTCH_R            -5.03       1.20       5.49
L_SHOULDER_Y           3.63       0.87       4.60
R_ANKLE_R              3.50       0.81       4.24
CHEST_P                3.17       1.47       7.69
R_ANKLE_P             -3.06       0.90       6.62  <-- gravite
R_WRIST_R             -3.03       0.75       4.02
L_ELBOW_P              2.35       2.50      15.71
L_CROTCH_Y             2.28       0.78       3.03
R_ELBOW_Y              2.17       0.55       6.31
L_KNEE_P              -1.65       0.55       3.90  <-- gravite
L_CROTCH_P             1.59       0.57       3.06  <-- gravite
L_ANKLE_R              1.57       0.84       4.32
R_ELBOW_P             -0.64       0.18       1.27
R_WRIST_Y             -0.41       0.47       6.72

====================================================================
VERDICT
====================================================================
biais moyen, articulations chargees par la gravite :  14.45 deg
biais moyen, toutes les autres                     :  10.67 deg
rapport : 1.4x

part de l'erreur qui est un biais constant : 92 %
  eleve + concentre sur les jambes -> saturation de couple, le genou
    s'affaisse. Cadre avec les 41 N.m calcules contre 21.4 N.m continus.
  reparti, ou surtout dynamique -> le QP ne suit pas ; regarder les
    poids de taches et les contraintes qui saturent.

Temps passe a plus de 90 % de l'erreur max (signe d'une butee) :
  R_CROTCH_P      100.0 %
  R_CROTCH_R       94.8 %
  L_ANKLE_P        94.8 %
  R_SHOULDER_R     94.7 %
  L_ELBOW_Y        94.7 %
```
