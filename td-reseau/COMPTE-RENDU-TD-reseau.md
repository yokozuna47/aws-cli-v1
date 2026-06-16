# Compte rendu — TD Sécurité réseau AWS (Jour 1)

**Étudiant :** Issiakha · Mastère Cybersécurité — BC Design Systems / IPSSI
**Objet :** VPC par défaut, bastion + cible, Security Groups (stateful) & NACL (stateless), défense en profondeur.
**Région :** `us-east-1` (j'ai basculé depuis `eu-west-3` sur consigne du formateur — quota vCPU saturé).

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

## 2. Règles que j'ai appliquées

**Security Group `sg-bastion`** — entrée : TCP 22 depuis `82.96.161.255/32`.
**Security Group `sg-cible`** — entrée : TCP 22 + ICMP, source = `sg-bastion`.

**NACL `td-nacl`** (sur mon sous-réseau dédié) :

| N°  | Sens    | Protocole | Ports        | Source/Dest        | Action |
|-----|---------|-----------|--------------|--------------------|--------|
| 90  | entrant | TCP       | 22           | 82.96.161.255/32   | DENY *(test §défense, puis retirée)* |
| 100 | entrant | TCP       | 22           | 82.96.161.255/32   | ALLOW  |
| 100 | sortant | TCP       | 1024–65535   | 0.0.0.0/0          | ALLOW *(trafic retour)* |

**Preuve SG** (sortie CLI obtenue lors de la création des règles) :

```json
// sg-bastion : SSH 22 depuis mon IP
{ "GroupId": "sg-0e9638fb0e2013975", "IpProtocol": "tcp",
  "FromPort": 22, "ToPort": 22, "CidrIpv4": "82.96.161.255/32" }

// sg-cible : SSH 22 + ICMP dont la source est le SG bastion
{ "GroupId": "sg-09361bbfdb1a9249e", "IpProtocol": "tcp",
  "FromPort": 22, "ToPort": 22,
  "ReferencedGroupInfo": { "GroupId": "sg-0e9638fb0e2013975" } }
{ "GroupId": "sg-09361bbfdb1a9249e", "IpProtocol": "icmp",
  "FromPort": -1, "ToPort": -1,
  "ReferencedGroupInfo": { "GroupId": "sg-0e9638fb0e2013975" } }
```


## 3. Mes réponses aux questions

**Instances** — Seul mon **bastion** est joignable depuis Internet (IP publique + route via l'IGW) ; ma cible, sans IP publique, n'est atteignable que **par rebond depuis le bastion** sur son IP privée.

**Security Groups** — Je prends `sg-bastion` comme source plutôt qu'une IP car la règle **suit les instances** du groupe (IP changeantes, plusieurs bastions possibles). La réponse repart sans règle de sortie car le SG est **stateful** : il autorise automatiquement le trafic retour.

**NACL** — Le retour part sur un **port éphémère (1024–65535)** côté client, pas sur le 22 ; comme la NACL est **stateless**, je dois autoriser ce retour explicitement en sortie. Différence clé : *SG = stateful, niveau instance ; NACL = stateless (aller ET retour), niveau sous-réseau, avec règles deny possibles.*

**Défense en profondeur** — Si le SG autorise mais que la NACL refuse, **le trafic ne passe pas** : la NACL est évaluée avant le SG, le plus restrictif l'emporte. Intérêt de deux couches : une erreur ou un contournement sur l'une est encore rattrapé par l'autre.

## 4. Limites et failles de mon montage

Mon archi remplit l'objectif, mais je relève plusieurs points faibles :

- **Agent forwarding (`ssh -A`)** que j'ai utilisé pour rebondir : il expose mon agent SSH sur le bastion. Si le bastion est compromis, root pourrait détourner mes clés. Mieux : **ProxyJump** (`ssh -J bastion cible`), qui n'expose jamais l'agent.
- **NACL sortante large** (`1024-65535 → 0.0.0.0/0`) : nécessaire en stateless, mais à restreindre côté destination en production.
- **Aucune couche de détection** : que du préventif (SG/NACL), pas de **VPC Flow Logs** ni de surveillance CloudTrail.
- **SSH public** : même limité à mon IP, le port 22 reste ouvert sur Internet.
- **Évolution idéale : supprimer le bastion** au profit de **SSM Session Manager** (zéro port ouvert, zéro clé, accès audité).

## 5. Conclusion — bonnes pratiques retenues

- **Moindre privilège** : n'ouvrir que le strict nécessaire ; jamais SSH en `0.0.0.0/0`.
- **Architecture bastion** : une seule porte d'entrée, cible isolée sans IP publique.
- **Source = Security Group** plutôt qu'une plage d'IP (règles qui suivent les instances).
- **Défense en profondeur** : NACL (sous-réseau) + SG (instance), deux couches indépendantes.
- Avec une NACL (stateless), **toujours penser au trafic retour** (ports éphémères).
- **Nettoyer** les ressources après usage (coût et surface d'attaque).
