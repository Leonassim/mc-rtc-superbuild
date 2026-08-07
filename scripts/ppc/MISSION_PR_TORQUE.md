# Mission : ouvrir la PR "state.torque depuis 0x6077" sur isri-aist/rhps1-iob

Brief écrit le 2026-08-07 depuis le PC du robot (`rhps1c`). Tout le travail
d'analyse et le patch sont faits ; il ne reste que le fork, le push et la PR,
qui doivent partir du compte de Léo et ne pouvaient donc pas être faits depuis
le PC du robot.

## Règles de travail, non négociables

- **Ne jamais pousser ailleurs que sur les dépôts de Léo** (`Leonassim/...`).
  Ici cela veut dire : pousser sur le **fork**, jamais sur `isri-aist`.
- **Commits signés `lmoussafir <leonassim@hotmail.fr>`**, messages **en anglais**.
  Vérifier avant le premier commit :
  ```
  git config user.name  "lmoussafir"
  git config user.email "leonassim@hotmail.fr"
  ```
  Sur le PC du robot l'identité git globale est celle d'un collègue, d'où la
  précaution ; à vérifier aussi sur le poste perso.
- **Jamais de `Co-Authored-By: Claude`.**
- Prose brève, orientée commande.

## Pourquoi cette PR

`TransListenerEx::motors2joints()`, dans le plugin RHPS1 de l'IOB, surcharge la
version de la classe de base. La version de base remplit `angle`, `speed` et
`torque` ; la surcharge ne remplissait que les angles. Résultat : `state.torque`
gardait les zéros écrits par `alloc_iob` au démarrage, et tout l'aval lisait
zéro — `read_actual_torques`, le port `tau` de `RobotHardware`, et côté mc_rtc
`robot.jointTorques()`.

Conséquence visible : `bodystat` affichait `torque 0.000` sur tous les joints
depuis toujours. Ce n'était **pas** un problème de PDO EtherCAT, contrairement à
ce qu'on a cru longtemps.

### Ce qui a été écarté en chemin, et pourquoi ça compte pour la revue

- `GetCurrent()` lit le PDO **0x6078** (Current actual value), qui vaut un zéro
  constant sur ces drives, servo armé et en charge — vérifié drive par drive
  avec `elmostat`. C'est ce qu'utilise la classe de base : même si elle avait
  tourné, elle aurait produit des zéros.
- `GetTorque()` multiplie par le `torqueConstant_` **interne au device**, qui est
  une variable distincte de `param.torqueConst` en mémoire partagée. Le produit
  mesurait exactement 0.
- D'où la lecture directe de **0x6077** (Torque actual value), le seul canal de
  couple réellement alimenté.

### Vérification matérielle

Servo armé, `state.torque` correspond à `ratedCurrent * 0x6077/1000` **à la
neuvième décimale**, joint par joint, chacun comparé à son propre drive :

| joint | state.torque | 0x6077 brut | attendu |
|---|---|---|---|
| L_KNEE_P | -0.410970001 | -399 | -0.410970000 |
| R_KNEE_P | -0.749839966 | -728 | -0.749840000 |

### Le piège des unités, assumé dans le commit

Le VRML de RHPS1 déclare `gearRatio 1` et `torqueConst 1` sur les 62 joints.
Ce que la PR publie est donc un **courant en ampères**, pas un couple. Le couple
articulaire vaut `I * N * Kt`, soit 21,21 N·m/A pour les genoux.

C'est documenté tel quel dans le message de commit, sans prétendre trancher :
où doit vivre cette mise à l'échelle est une question de conception qui regarde
le labo, et publier la mesure est un prérequis dans tous les cas.

## Ce qui est volontairement HORS de cette PR

`state.speed` souffre exactement du même manque, et un correctif existe sur le
PC du robot — mais il n'est **pas** proposé, pour deux raisons :

1. il n'a pas encore tourné en conditions réelles ;
2. la vitesse publiée serait côté **actionneur**, avec un facteur `N/2` mesuré
   par régression sur les six joints à moteur unique (pente/N = 0,499, R² ≥ 0,98).
   Ce facteur 2 vient de `count2angle_` dans `hrp5p-iob`, qui calcule
   `2π/2^numBits` avec `numBits = 17` (SDO `0x3034:59`) alors que l'encodeur
   délivre 65 536 comptes/tour. Ça appartient à `hrp5p-iob`, partagé avec HRP5P
   et HRP4CR qu'on ne peut pas tester — à signaler en *issue*, pas à corriger
   unilatéralement.

**Ne pas ajouter la partie vitesse à cette PR.**

## Le patch, à appliquer tel quel

Enregistrer le bloc ci-dessous dans `0001-torque.patch`. Attention en le
recopiant : garder la ligne `-- ` avec son espace final, et ne pas laisser
l'éditeur ajouter d'espaces en fin de ligne, sinon `git am` refuse.

```
From d48351ef17ffd9cb2e57a082a4c75f97723a64d6 Mon Sep 17 00:00:00 2001
From: lmoussafir <leonassim@hotmail.fr>
Date: Fri, 7 Aug 2026 19:45:35 +0900
Subject: [PATCH] TransListenerEx: fill state.torque from 0x6077

motors2joints() overrides the base implementation, which fills angle, speed
and torque. This override only filled the angles, so state.torque kept the
zeros alloc_iob writes at startup. Everything downstream saw them:
read_actual_torques, RobotHardware's tau port, and on the mc_rtc side
robot.jointTorques(). bodystat has reported torque 0.000 on every joint for
as long as this override has existed.

Torque is read from 0x6077 (Torque actual value). Two alternatives do not
work on these drives:

  - GetCurrent() reads 0x6078 (Current actual value), which is a constant 0
    servo-on and loaded, verified per drive against elmostat. That is what
    the base implementation uses, so it would have produced zeros here too.
  - GetTorque() scales by the device's internal torqueConstant_, a different
    variable from param.torqueConst; the product measured exactly 0.

Verified on hardware: state.torque matches ratedCurrent * 0x6077/1000 to nine
decimals, per joint, each against its own drive.

Units: RHPS1's VRML declares gearRatio 1 and torqueConst 1 on all 62 joints,
so this publishes a current in amperes rather than a torque. Joint torque is
I * N * Kt, 21.21 N.m/A for the knees. Scaling is deliberately left out of
the IOB: where it belongs is a separate design question, and publishing the
measurement is a prerequisite either way.
---
 TransListenerEx.hpp | 24 ++++++++++++++++++++++++
 1 file changed, 24 insertions(+)

diff --git a/TransListenerEx.hpp b/TransListenerEx.hpp
index 505e5f4..29c8a01 100644
--- a/TransListenerEx.hpp
+++ b/TransListenerEx.hpp
@@ -1,4 +1,5 @@
 #include "TransListenerImpl.hpp"
+#include <DeviceMotorImpl.hpp>
 #include "khi/ElmoWrap.h"
 #define ROBOT 10 //RHPS1_ID
 #include "khi/rhp_joint_settings.h"
@@ -243,5 +244,28 @@ public:
         m_iob->state.angle[i] = m_iob->state.auxAngle[i] = a;
       }
     }
+
+    // This override left state.torque at the zeros alloc_iob wrote, so
+    // read_actual_torques, RobotHardware's tau port and mc_rtc's jointTorques()
+    // all read 0. Fill it from 0x6077 (Torque actual value): 0x6078, used by
+    // GetCurrent() and hence by the base implementation, is a constant 0 on
+    // these drives, and GetTorque() scales by the device's torqueConstant_
+    // rather than by param.torqueConst.
+    //
+    // gearRatio and torqueConst are both 1 in RHPS1's VRML, so this publishes
+    // a current in amperes; joint torque is I * N * Kt.
+    for (unsigned int j=0; j<m_joints.size(); j++){
+      const int id = m_joints[j].id;
+      const std::vector<BodySignal::DeviceMotor *>& drv = m_joints[j].drivers;
+      double t = 0;
+      for (unsigned int k=0; k<drv.size(); k++){
+        BodySignal::DeviceMotorImpl *dev =
+            dynamic_cast<BodySignal::DeviceMotorImpl *>(drv[k]);
+        if (!dev) continue;
+        t += dev->GetRatedCurrent() * dev->GetMotorProcDataIn().Torque_RData_ / 1e3;
+      }
+      joint_param &param = m_iob->param[id];
+      m_iob->state.torque[id] = param.gearRatio * param.torqueConst * t;
+    }
   }
 };
-- 
2.43.0

```

## Marche à suivre

1. Forker `isri-aist/rhps1-iob` sous `Leonassim` (bouton Fork sur GitHub).
2. Puis :

```bash
git clone git@github.com:Leonassim/rhps1-iob
cd rhps1-iob
git config user.name  "lmoussafir"
git config user.email "leonassim@hotmail.fr"
git remote add upstream git@github.com:isri-aist/rhps1-iob
git fetch upstream

git checkout -b pr/fill-torque-from-0x6077 upstream/topic/upgrade-ecmaster3.2
git am ../0001-torque.patch
git push -u origin pr/fill-torque-from-0x6077
```

Le patch porte déjà le bon auteur et le bon message : `git am` produit le commit
tel quel, rien à re-signer. Si `git am` refuse, `git apply --reject` puis un
commit manuel font le même travail — le message est dans l'en-tête du patch.

3. Ouvrir la PR vers `isri-aist/rhps1-iob`, branche cible
   **`topic/upgrade-ecmaster3.2`** (c'est celle que le robot utilise ; si le labo
   attend les contributions sur `master`, rebaser).

## Texte de la PR

**Titre**

```
TransListenerEx: fill state.torque from 0x6077
```

**Corps**

```markdown
`TransListenerEx::motors2joints()` overrides the base implementation, which
fills angle, speed and torque. This override only filled the angles, so
`state.torque` kept the zeros `alloc_iob` writes at startup. Everything
downstream read them: `read_actual_torques`, RobotHardware's `tau` port, and
on the mc_rtc side `robot.jointTorques()`. `bodystat` has reported
`torque 0.000` on every joint for as long as this override has existed.

Torque is read from `0x6077` (Torque actual value). Two alternatives do not
work on these drives:

- `GetCurrent()` reads `0x6078` (Current actual value), which is a constant 0
  servo-on and loaded, verified per drive against `elmostat`. That is what the
  base implementation uses, so it would have produced zeros here too.
- `GetTorque()` scales by the device's internal `torqueConstant_`, a different
  variable from `param.torqueConst`; the product measured exactly 0.

Verified on hardware: `state.torque` matches `ratedCurrent * 0x6077/1000` to
nine decimals, per joint, each against its own drive.

### Units

RHPS1's VRML declares `gearRatio 1` and `torqueConst 1` on all 62 joints, so
this publishes a **current in amperes** rather than a torque. Joint torque is
`I * N * Kt` (21.21 N.m/A for the knees). Scaling is deliberately left out of
the IOB: where it belongs is a separate design question, and publishing the
measurement is a prerequisite either way.

`state.speed` has the same gap and is not addressed here — the velocity path
needs the same units discussion plus a hardware validation run.
```

## Détail qui peut surprendre

Le patch **ne compilera pas** sur un clone isolé de `rhps1-iob` : il dépend de
`DeviceMotorImpl.hpp`, fourni par `hrp5p-iob` et présent uniquement dans un
arbre superbuild complet. C'est normal et sans incidence sur la PR — mais ne pas
conclure à une erreur en voyant l'include non résolu.
