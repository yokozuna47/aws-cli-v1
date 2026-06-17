# Compte rendu — TD2 : Filtrage réseau & IDS en Terraform

**Étudiant :** jilani (n° 22) · Mastère Cybersécurité — BC Design Systems / IPSSI
**Objet :** déployer en **Terraform** un bastion (filtrage entrant), une instance privée sortant via **NAT Gateway** (filtrage sortant), et une sonde **Suricata** (détection d'intrusion).
**Région :** `us-east-1` (bascule depuis `eu-west-3` — quota vCPU saturé, même problème qu'au TD1) · **VPC par défaut** lu en data source (jamais modifié).

---

## 1. Architecture déployée

```
            Internet
               │ SSH (22) depuis MON IP 82.96.161.255/32
               ▼
   ┌──────────────────────────────────────────────────────────┐
   │ VPC par defaut 172.31.0.0/16 (data source)                 │
   │                                                            │
   │  Subnet PUBLIC 172.31.192.0/20            Subnet PRIVE     │
   │  ┌──────────┐   ┌──────────┐              172.31.147.0/24  │
   │  │ BASTION  │   │  SONDE    │             ┌──────────┐      │
   │  │ IP pub   │   │ Suricata  │   ping       │ PRIVEE   │      │
   │  │ [sg-bas] │   │ [sg-sonde]│◄─────────── │ pas d'IP │      │
   │  └────┬─────┘   └──────────┘   (ICMP)     │ publique │      │
   │       │ SSH+ICMP depuis bastion           └────┬─────┘      │
   │       └──────────────────────────────► (rebond)│           │
   │                                                 │ 0.0.0.0/0 │
   │   NAT Gateway (EIP 35.181.110.247) ◄────────────┘ via route │
   │        │ sortie Internet                                    │
   └────────┼───────────────────────────────────────────────────┘
            ▼ Internet
```

## 2. Fichiers Terraform (livrable)

- **provider.tf** — provider AWS (~> 5.0), région `var.aws_region`.
- **variables.tf** — `aws_region`, `student_id` (47), `key_name`, `my_ip`.
- **data.tf** — VPC par défaut + sous-réseau public en **data source** (lecture seule).
- **bastion.tf** — AMI Ubuntu 22.04 (data source) + SG bastion (SSH depuis mon IP) + instance bastion (IP publique).
- **egress.tf** — sous-réseau privé, Elastic IP, **NAT Gateway** (dans le public), route table privée `0.0.0.0/0 → NAT`, SG privé (SSH depuis bastion), instance privée (sans IP publique).
- **suricata.tf** — SG sonde (SSH + ICMP depuis bastion) + instance sonde avec **`user_data`** installant Suricata et la règle d'alerte ICMP.

## 3. Preuves de fonctionnement (sorties terminal)

**Déploiement Terraform** (`terraform apply`) — outputs obtenus :

```
Apply complete! Resources: 13 added, 0 changed, 0 destroyed.
Outputs:
bastion_public_ip = "13.220.141.192"
private_ip        = "172.31.122.93"
sonde_private_ip  = "172.31.80.196"
```

**Filtrage sortant (NAT)** — depuis l'instance privée (`172.31.147.75`, sans IP publique) :

```
ubuntu@ip-172-31-122-93:~$ curl https://checkip.amazonaws.com
50.17.113.129
```

→ `50.17.113.129` = l'**EIP de la NAT Gateway** (confirmé par `aws ec2 describe-addresses`). La privée sort vers Internet via la NAT, sans être joignable de l'extérieur.

**Détection Suricata (IDS)** — `ping` depuis le bastion vers la sonde, puis lecture de `/var/log/suricata/fast.log` :

```
ubuntu@ip-172-31-80-196:~$ sudo cloud-init status
status: done
ubuntu@ip-172-31-80-196:~$ sudo systemctl is-active suricata
active
ubuntu@ip-172-31-80-196:~$ sudo grep "TD2 ICMP" /var/log/suricata/fast.log
06/17/2026-15:17:56.145569 [**] [1:1000001:1] TD2 ICMP detecte [**] [Classification: (null)] [Priority: 3] {ICMP} 172.31.80.130:8 -> 172.31.80.196:0
06/17/2026-15:17:56.145644 [**] [1:1000001:1] TD2 ICMP detecte [**] [Classification: (null)] [Priority: 3] {ICMP} 172.31.80.196:0 -> 172.31.80.130:0
```

La règle (sid 1000001) ajoutée via `user_data` est chargée et lève une alerte sur chaque ping (echo request du bastion + echo reply).

**Nettoyage** (`terraform destroy`) — Partie 5 obligatoire :

```
Destroy complete! Resources: 11 destroyed.
```

## 4. Réponses aux questions

**Partie 1 — Socle**
1. Une **resource** est créée et gérée par Terraform (donc destructible) ; une **data source** se contente de **lire** un objet existant. Le VPC par défaut est en data source pour s'y rattacher **sans pouvoir le modifier ni le supprimer**.
2. Le **`terraform.tfstate`** mémorise les ressources gérées ; il permet à `plan`/`apply` de calculer les changements et à `destroy` de ne supprimer **que** ce que j'ai créé.

**Partie 2 — Filtrage entrant**
1. Je n'ai pas eu à préciser l'ordre car Terraform construit un **graphe de dépendances** : l'instance référence `aws_security_group.bastion.id`, donc le SG est créé **avant**, automatiquement.
2. Remplacer `[var.my_ip]` par `["0.0.0.0/0"]` ouvrirait le **SSH (22) au monde entier** → cible immédiate des scans et attaques par force brute. À proscrire.

**Partie 3 — Filtrage sortant**
1. `curl checkip` depuis l'instance privée renvoie l'**IP publique de la NAT Gateway** (l'EIP) : tout le trafic sortant du privé est traduit derrière cette adresse partagée.
2. La NAT doit être dans le **sous-réseau public** car elle a elle-même besoin d'une route vers l'**Internet Gateway** pour sortir ; seul un subnet public en dispose. Dans le privé, elle n'aurait aucune issue.

**Partie 4 — Suricata**
1. Passer l'install en **`user_data`** apporte la **reproductibilité** : toute instance lancée avec ce code est configurée à l'identique, sans intervention manuelle (infrastructure as code).
2. Suricata ici **détecte et alerte seulement** (mode **IDS**). Un **IPS**, placé en coupure sur le chemin du trafic, pourrait en plus **bloquer** le flux en temps réel.

## 5. Conclusion — point clé

Déclarer le **VPC par défaut en data source** garantit qu'on ne le supprimera **jamais** : Terraform ne le gère pas (il n'est pas dans le state comme ressource gérée), donc `terraform destroy` n'y touche pas — il ne supprime que mes propres ressources (bastion, privée, sonde, NAT, subnet privé, SG…). C'est la bonne pratique pour travailler dans un VPC partagé sans risque pour les autres.

**Bonnes pratiques retenues :** moindre privilège (SSH depuis ma seule IP, jamais `0.0.0.0/0`), source = Security Group plutôt qu'une IP, instances sensibles sans IP publique (sortie via NAT), IaC reproductible via `user_data`, et **destroy** systématique (la NAT Gateway est facturée à l'heure).
