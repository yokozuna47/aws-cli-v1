# Compte rendu — TD2 : Filtrage réseau et détection d'intrusion en Terraform

**Étudiante :** Aïcha (n° 28) · Mastère Cybersécurité — IPSSI
**Région :** eu-west-3 (Paris) · **VPC par défaut** `172.31.0.0/16` lu en data source (jamais modifié)
**Objet :** déployer en Terraform un bastion (filtrage entrant), une instance privée qui sort par une NAT Gateway (filtrage sortant), et une sonde Suricata (détection d'intrusion).

---

## 1. Ce que j'ai déployé

J'ai monté trois machines dans le VPC partagé, toutes en Ubuntu 22.04 (t3.micro). Le bastion est ma seule porte d'entrée : il accepte le SSH depuis mon IP uniquement (`82.96.161.255/32`), jamais depuis tout Internet. La sonde Suricata et l'instance privée ne sont joignables qu'à travers lui.


## 2. Les fichiers Terraform (livrable)

- **provider.tf** — le provider AWS (~> 5.0), région prise dans `var.aws_region`.
- **variables.tf** — mes variables : `aws_region` (eu-west-3), `student_id` (28), `key_name` (`cle-td2-aicha`), `my_ip`.
- **data.tf** — lecture du VPC par défaut et du subnet public en data source (donc jamais modifiés).
- **bastion.tf** — l'AMI Ubuntu (data source), le SG bastion (SSH depuis mon IP) et l'instance bastion avec IP publique.
- **egress.tf** — le subnet privé, l'Elastic IP, la NAT Gateway (placée dans le public), la route table privée `0.0.0.0/0 → NAT`, le SG privé (SSH depuis le bastion) et l'instance privée sans IP publique.
- **suricata.tf** — le SG sonde (SSH et ICMP depuis le bastion) et l'instance sonde, qui installe Suricata et ma règle d'alerte ICMP via `user_data`.

## 3. Mes preuves

**Le déploiement** (`terraform apply`) :
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

bastion_public_ip = "15.237.101.248"

private_ip        = "172.31.128.211"

sonde_private_ip  = "172.31.192.61"
**Le rebond et la détection.** Depuis le bastion, j'ai pingué la sonde (l'ICMP passe, le SG l'autorise depuis le bastion), puis j'ai rebondi en SSH dessus grâce à l'agent forwarding (ma clé privée n'a jamais été copiée sur le bastion). Le ping a bien été détecté par Suricata, dans `/var/log/suricata/eve.json` :
{"src_ip":"172.31.202.25","dest_ip":"172.31.192.61","proto":"ICMP",

"alert":{"action":"allowed","signature_id":1000001,"signature":"TD2 ICMP detecte"},

"direction":"to_server"}

{"src_ip":"172.31.192.61","dest_ip":"172.31.202.25","proto":"ICMP",

"alert":{"action":"allowed","signature_id":1000001,"signature":"TD2 ICMP detecte"},

"direction":"to_client"}
On voit les deux sens : la demande d'écho (bastion → sonde) puis la réponse. Ma règle (sid 1000001), ajoutée par `user_data`, est bien chargée et lève une alerte à chaque ping. La capture complète est dans `captures/eve-td2-aicha.json`.

**Le nettoyage** (`terraform destroy`, obligatoire car la NAT Gateway est facturée à l'heure) :
On voit les deux sens : la demande d'écho (bastion → sonde) puis la réponse. Ma règle (sid 1000001), ajoutée par `user_data`, est bien chargée et lève une alerte à chaque ping. La capture complète est dans `captures/eve-td2-aicha.json`.

**Le nettoyage** (`terraform destroy`, obligatoire car la NAT Gateway est facturée à l'heure) :
Destroy complete! Resources: 11 destroyed.
## 4. Réponses aux questions

**Partie 1 — Socle**
1. Une *resource* est créée et gérée par Terraform (donc supprimable par lui), alors qu'une *data source* se contente de lire un objet qui existe déjà. J'ai déclaré le VPC par défaut en data source pour m'y rattacher sans jamais pouvoir le modifier ni le détruire.
2. Le `terraform.tfstate` retient la liste des ressources que Terraform gère. C'est lui qui permet à `apply` de calculer les changements et à `destroy` de ne supprimer que ce que j'ai créé, rien d'autre.

**Partie 2 — Filtrage entrant**
1. Je n'ai pas eu à indiquer l'ordre de création, parce que Terraform construit un graphe de dépendances tout seul : mon instance référence l'ID du Security Group, donc Terraform comprend qu'il doit créer le SG d'abord.
2. Si je remplaçais `[var.my_ip]` par `["0.0.0.0/0"]`, j'ouvrirais le SSH au monde entier. C'est à éviter absolument : le port 22 ouvert à tous devient une cible immédiate pour les scans et les attaques par force brute.

**Partie 3 — Filtrage sortant**
1. Depuis l'instance privée, `curl checkip` renvoie l'IP publique de la NAT Gateway (l'Elastic IP). Tout le trafic sortant du privé est traduit derrière cette adresse partagée. L'instance sort donc vers Internet sans avoir d'IP publique à elle.
2. La NAT doit être dans le subnet public car elle a elle-même besoin d'une route vers l'Internet Gateway pour sortir. Seul un subnet public en possède une. Dans le privé, elle n'aurait aucune issue vers l'extérieur.

**Partie 4 — Suricata**
1. Passer l'installation en `user_data` me donne la reproductibilité : n'importe quelle instance lancée avec ce code est configurée pareil, sans que j'aie à me connecter à la main. C'est tout l'intérêt de l'infrastructure as code.
2. Ici Suricata détecte et alerte seulement : c'est un IDS. Je le vois dans mon `eve.json`, où chaque alerte porte `"action":"allowed"` — le paquet passe quand même. Un IPS, lui, serait placé en coupure sur le chemin du trafic et pourrait bloquer le paquet en temps réel.

## 5. Conclusion — le point clé

Déclarer le VPC par défaut en data source garantit que je ne le supprimerai jamais. Terraform ne le gère pas (il n'est pas dans le state comme ressource gérée), donc `terraform destroy` n'y touche pas : il efface seulement mes propres ressources (bastion, privée, sonde, NAT, subnet privé, Security Groups). C'est la bonne façon de travailler dans un VPC partagé sans casser le travail des autres.

Ce que je retiens, côté bonnes pratiques : le moindre privilège (SSH depuis ma seule IP, jamais `0.0.0.0/0`), une source définie par Security Group plutôt que par plage d'IP, des instances sensibles sans IP publique (sortie par la NAT), une installation reproductible via `user_data`, et surtout le `destroy` systématique, parce que la NAT Gateway coûte tant qu'elle tourne.
