# Compte rendu — TD Sécurité réseau AWS (Jour 1)

**Étudiant :** yokozuna · Mastère Cybersécurité — BC Design Systems / IPSSI
**Objet :** VPC par défaut, bastion + cible, Security Groups (stateful) & NACL (stateless), défense en profondeur.
**Région :** `us-east-1` (bascule depuis `eu-west-3` sur consigne formateur — quota vCPU saturé).

---

## 1. Schéma logique

```
                 Internet
                    │  SSH (22) depuis MON IP : 82.96.161.255/32
                    ▼
        ┌───────────────────────────────────────────────┐
        │  VPC par défaut  172.31.0.0/16                  │
        │  Internet Gateway + route 0.0.0.0/0             │
        │                                                 │
        │   Sous-réseau dédié  172.31.211.0/24            │
        │   ── NACL td-nacl (stateless, niveau subnet) ── │
        │                                                 │
        │   ┌────────────────┐        ┌────────────────┐  │
        │   │   BASTION       │  SSH   │    CIBLE       │  │
        │   │ IP publique     │  +ping │ PAS d'IP       │  │
        │   │ 44.192.111.115  │──────► │ publique       │  │
        │   │ priv .211.127   │        │ priv .211.40   │  │
        │   │ [sg-bastion]    │        │ [sg-cible]     │  │
        │   └────────────────┘        └────────────────┘  │
        └───────────────────────────────────────────────┘

 sg-bastion : entrée SSH(22) depuis 82.96.161.255/32
 sg-cible   : entrée SSH(22) + ICMP dont la SOURCE = sg-bastion (pas une IP)
```

## 2. Règles appliquées

**Security Group `sg-bastion`** — entrée : TCP 22 depuis `82.96.161.255/32`.
**Security Group `sg-cible`** — entrée : TCP 22 + ICMP, source = `sg-bastion`.

**NACL `td-nacl`** (sur le sous-réseau dédié) :

| N°  | Sens    | Protocole | Ports        | Source/Dest        | Action |
|-----|---------|-----------|--------------|--------------------|--------|
| 90  | entrant | TCP       | 22           | 82.96.161.255/32   | DENY *(test §défense, puis retirée)* |
| 100 | entrant | TCP       | 22           | 82.96.161.255/32   | ALLOW  |
| 100 | sortant | TCP       | 1024–65535   | 0.0.0.0/0          | ALLOW *(trafic retour)* |

> _Captures d'écran à insérer ici : console SG (règles entrantes) et console NACL (règles entrantes/sortantes)._

## 3. Réponses aux questions

**Instances** — Seul le **bastion** est joignable depuis Internet (IP publique + route via l'IGW) ; la cible, sans IP publique, n'est atteignable que **par rebond depuis le bastion** sur son IP privée.

**Security Groups** — On prend `sg-bastion` comme source plutôt qu'une IP car la règle **suit les instances** du groupe (IP changeantes, plusieurs bastions possibles). La réponse repart sans règle de sortie car le SG est **stateful** : il autorise automatiquement le trafic retour.

**NACL** — Le retour part sur un **port éphémère (1024–65535)** côté client, pas sur le 22 ; comme la NACL est **stateless**, ce retour doit être autorisé explicitement en sortie. Différence clé : *SG = stateful, niveau instance ; NACL = stateless (aller ET retour), niveau sous-réseau, avec règles deny possibles.*

**Défense en profondeur** — Si le SG autorise mais que la NACL refuse, **le trafic ne passe pas** : la NACL est évaluée avant le SG, le plus restrictif l'emporte. Intérêt de deux couches : une erreur ou un contournement sur l'une est encore rattrapé par l'autre.

## 4. Conclusion — bonnes pratiques retenues

- **Moindre privilège** : n'ouvrir que le strict nécessaire ; jamais SSH en `0.0.0.0/0`.
- **Architecture bastion** : une seule porte d'entrée, cible isolée sans IP publique.
- **Source = Security Group** plutôt qu'une plage d'IP (règles qui suivent les instances).
- **Défense en profondeur** : NACL (sous-réseau) + SG (instance), deux couches indépendantes.
- Avec une NACL (stateless), **toujours penser au trafic retour** (ports éphémères).
- **Nettoyer** les ressources après usage (coût et réduction de la surface d'attaque).
