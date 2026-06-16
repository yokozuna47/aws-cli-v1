# TD Jour 1 — Sécuriser un réseau AWS (VPC, EC2, Security Groups & NACL)

Mastère Cybersécurité · BC Design Systems / IPSSI — Formateur : Boris Rose

Lab de **défense en profondeur** : un **bastion** (avec IP publique) et une **cible**
(sans IP publique) dans le VPC par défaut, protégés par un Security Group (niveau
instance, *stateful*) **et** une NACL (niveau sous-réseau, *stateless*).

> **Région.** L'énoncé prévoit `eu-west-3`, mais le quota de vCPU du compte partagé
> y était saturé (`VcpuLimitExceeded`). Sur consigne du formateur, le TD a été réalisé
> en **`us-east-1` (Virginie du Nord)**. Toutes les ressources créées y ont ensuite été
> supprimées (Partie 7).

## Ressources créées (toutes supprimées au nettoyage)

| Ressource              | Identifiant                | Détail                          |
|------------------------|----------------------------|---------------------------------|
| VPC par défaut         | `vpc-0f7cd0ee42bee14a1`    | 172.31.0.0/16 (non modifié)     |
| Sous-réseau dédié      | `subnet-0d834d3c232ffbf3e` | 172.31.211.0/24, us-east-1a     |
| Paire de clés          | `cle-td-yokozuna`          | fichier `cle-td-yokozuna-nv.pem`|
| Instance **bastion**   | `i-012d5366d969884ef`      | priv 172.31.211.127 / pub 44.192.111.115 |
| Instance **cible**     | `i-05ff08457f42ed9be`      | priv 172.31.211.40 / pas d'IP publique |
| SG bastion             | `sg-0e9638fb0e2013975`     | `td-bastion-yokozuna`           |
| SG cible               | `sg-09361bbfdb1a9249e`     | `td-cible-yokozuna`             |
| NACL personnalisée     | `acl-04a67115a28bc3537`    | `td-nacl-yokozuna`              |
| NACL par défaut        | `acl-029b01c2ab02ecb0d`    | réassociée à la fin (non supprimée) |

> Un sous-réseau **dédié** a été créé (au lieu d'un sous-réseau par défaut partagé) pour
> que la NACL personnalisée n'impacte que mes propres instances, sans gêner les camarades.

## Déroulé

### 1. Prérequis
```bash
curl https://checkip.amazonaws.com            # -> VOTRE_IP = 82.96.161.255/32
aws configure set region us-east-1            # bascule de région
aws ec2 create-key-pair --key-name cle-td-yokozuna \
  --query "KeyMaterial" --output text > cle-td-yokozuna-nv.pem
chmod 400 cle-td-yokozuna-nv.pem
```

### 2. Explorer le VPC par défaut
```bash
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" --output text
```

### 3. Lancer les deux instances
AMI Amazon Linux 2023 récupérée via `describe-images` (pas de droits SSM sur le compte).
```bash
# sous-réseau dédié
aws ec2 create-subnet --vpc-id vpc-0f7cd0ee42bee14a1 \
  --cidr-block 172.31.211.0/24 --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=td-yokozuna-subnet}]'

# bastion (AVEC IP publique) et cible (SANS IP publique)
aws ec2 run-instances --image-id ami-0521cb2d60cfbb1a6 --instance-type t3.micro \
  --key-name cle-td-yokozuna --subnet-id subnet-0d834d3c232ffbf3e \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=td-bastion}]'

aws ec2 run-instances --image-id ami-0521cb2d60cfbb1a6 --instance-type t3.micro \
  --key-name cle-td-yokozuna --subnet-id subnet-0d834d3c232ffbf3e \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=td-cible}]'
```

### 4. Security Groups (stateful)
```bash
# sg-bastion : SSH depuis MON IP uniquement
aws ec2 authorize-security-group-ingress --group-id sg-0e9638fb0e2013975 \
  --protocol tcp --port 22 --cidr 82.96.161.255/32

# sg-cible : SSH + ICMP dont la SOURCE est sg-bastion (pas une plage d'IP)
aws ec2 authorize-security-group-ingress --group-id sg-09361bbfdb1a9249e \
  --protocol tcp --port 22 --source-group sg-0e9638fb0e2013975
aws ec2 authorize-security-group-ingress --group-id sg-09361bbfdb1a9249e \
  --protocol icmp --port -1 --source-group sg-0e9638fb0e2013975
```
Test (agent forwarding pour rebondir vers la cible) :
```bash
ssh-add cle-td-yokozuna-nv.pem
ssh -A -i cle-td-yokozuna-nv.pem ec2-user@44.192.111.115   # bastion
# depuis le bastion :
ping -c 3 172.31.211.40            # OK (ICMP via sg-bastion)
ssh ec2-user@172.31.211.40         # OK (SSH via sg-bastion) -> réponse auto (stateful)
```

### 5. NACL (stateless)
```bash
# entrée SSH autorisée...
aws ec2 create-network-acl-entry --network-acl-id acl-04a67115a28bc3537 \
  --rule-number 100 --protocol 6 --port-range From=22,To=22 \
  --cidr-block 82.96.161.255/32 --rule-action allow --ingress
# ...mais SSH BLOQUÉ tant que le retour n'est pas autorisé en sortie :
aws ec2 create-network-acl-entry --network-acl-id acl-04a67115a28bc3537 \
  --rule-number 100 --protocol 6 --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0 --rule-action allow --egress   # -> SSH passe
```

### 6. Défense en profondeur
```bash
# règle DENY n°90 (prioritaire sur la 100) -> SSH refusé malgré le SG
aws ec2 create-network-acl-entry --network-acl-id acl-04a67115a28bc3537 \
  --rule-number 90 --protocol 6 --port-range From=22,To=22 \
  --cidr-block 82.96.161.255/32 --rule-action deny --ingress
# suppression -> accès rétabli
aws ec2 delete-network-acl-entry --network-acl-id acl-04a67115a28bc3537 \
  --rule-number 90 --ingress
```

### 7. Nettoyage
```bash
aws ec2 terminate-instances --instance-ids i-012d5366d969884ef i-05ff08457f42ed9be
aws ec2 wait instance-terminated --instance-ids i-012d5366d969884ef i-05ff08457f42ed9be
# rétablir la NACL par défaut puis supprimer la NACL custom
aws ec2 replace-network-acl-association --association-id <ASSOC> \
  --network-acl-id acl-029b01c2ab02ecb0d
aws ec2 delete-network-acl --network-acl-id acl-04a67115a28bc3537
# SG (cible d'abord car elle référence le bastion), puis subnet et clés
aws ec2 delete-security-group --group-id sg-09361bbfdb1a9249e
aws ec2 delete-security-group --group-id sg-0e9638fb0e2013975
aws ec2 delete-subnet --subnet-id subnet-0d834d3c232ffbf3e
aws ec2 delete-key-pair --key-name cle-td-yokozuna
```
VPC par défaut, ses sous-réseaux, son IGW et la NACL par défaut : **intacts**.

## Réponses aux questions

**Partie 2 — Les instances**
1. Seul le **bastion** est joignable depuis Internet : il a une **IP publique** et le
   sous-réseau a une route `0.0.0.0/0` vers l'Internet Gateway. La cible n'a pas d'IP
   publique, donc rien ne peut l'atteindre directement depuis l'extérieur.
2. On atteint la cible **par rebond depuis le bastion** (hôte intermédiaire), en SSH via
   son IP privée `172.31.211.40` — ici avec l'agent forwarding (`ssh -A`).

**Partie 3 — Security Groups**
1. Source = `sg-bastion` plutôt qu'une IP : la règle **suit automatiquement les instances**
   du groupe bastion, quelle que soit leur IP (qui peut changer), et reste valable si on
   ajoute d'autres bastions. Plus robuste et plus lisible qu'une plage d'IP figée.
2. Le Security Group est **stateful** : il mémorise les connexions entrantes autorisées et
   laisse repartir le trafic retour automatiquement, sans règle de sortie explicite.

**Partie 4 — NACL**
1. La connexion arrive sur le port 22 côté serveur, mais la **réponse** part vers le client
   sur un **port éphémère** (1024–65535) choisi par le client. Comme la NACL est stateless,
   il faut autoriser explicitement ce retour en sortie — autoriser le 22 en sortie ne
   servirait à rien.
2. Un **Security Group** est *stateful* et s'applique à l'**instance** (réponse retour
   automatique) ; une **NACL** est *stateless* et s'applique au **sous-réseau** (il faut
   autoriser l'aller ET le retour, et elle gère des règles `deny`).

**Partie 5 — Défense en profondeur**
1. **Non**, le trafic ne passe pas : la NACL est évaluée **avant** le SG. Un refus au
   niveau du sous-réseau bloque le paquet quoi qu'autorise le SG — le plus restrictif gagne.
2. Deux couches indépendantes : si l'une est mal configurée ou contournée (ex. SG trop
   permissif), l'autre peut encore bloquer l'attaque. Une seule faille ne compromet pas
   tout l'accès.

## Bonnes pratiques retenues
- **Moindre privilège** : n'ouvrir que le strict nécessaire (SSH depuis sa seule IP).
- **Jamais SSH (22) ouvert en `0.0.0.0/0`** — cible n°1 des scans.
- **Référencer un Security Group comme source** plutôt qu'une plage d'IP.
- **Architecture bastion** : une seule porte d'entrée, la cible reste sans IP publique.
- **Défense en profondeur** : empiler NACL (sous-réseau) + SG (instance).
- Ne pas oublier le **trafic retour** sur les ports éphémères avec une NACL (stateless).
- **Nettoyer** ses ressources après le lab (coût + surface d'attaque).
