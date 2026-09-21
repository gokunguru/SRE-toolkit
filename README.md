# SRE Toolkit

Automatisation d'une stack applicative complète avec provisioning infra as code, configuration management, observabilité et alerting — pensé comme un exercice pratique des pratiques SRE (Site Reliability Engineering).

## Architecture

```
                        ┌─────────────────┐
                        │   Utilisateur    │
                        └────────┬─────────┘
                                 │ HTTP :80
                        ┌────────▼─────────┐
                        │      lb-01       │
                        │  Nginx (reverse  │
                        │      proxy)      │
                        └────────┬─────────┘
                                 │ :5000
                        ┌────────▼─────────┐
                        │      app-01      │
                        │   Flask API      │
                        └──────────────────┘

        ┌──────────────────────────────────────────┐
        │              monitor-01                    │
        │  ┌────────────┐  ┌──────────┐  ┌────────┐ │
        │  │ Prometheus │─▶│Alertmgr  │  │Grafana │ │
        │  │   :9090    │  │  :9093   │  │ :3000  │ │
        │  └─────┬──────┘  └──────────┘  └────┬───┘ │
        └────────┼──────────────────────────────┼────┘
                 │ scrape :9100                  │
                 │ (toutes les instances)         │
                 ▼                                ▼
        node_exporter sur chaque VM      dashboards as code
```

Trois instances AWS EC2 (t3.micro, `eu-west-3`), chacune avec un rôle dédié :

| Instance     | Rôle                          | Security Group   |
|--------------|--------------------------------|-------------------|
| `app-01`     | API Flask (démo)               | `app-sg`          |
| `lb-01`      | Reverse proxy Nginx            | `lb-sg`           |
| `monitor-01` | Prometheus, Grafana, Alertmanager | `monitoring-sg` |

## Stack technique

- **Terraform** — provisioning des instances EC2 et security groups (Infrastructure as Code)
- **Ansible** — configuration management, inventaire dynamique basé sur les tags AWS (`amazon.aws.aws_ec2`)
- **Prometheus** — collecte de métriques (`node_exporter` sur chaque hôte)
- **Grafana** — visualisation, dashboard "Node Exporter Full" provisionné automatiquement
- **Alertmanager** — gestion des alertes (CPU, mémoire, disque, disponibilité)
- **Flask + Nginx** — application de démonstration load-balancée
- **Locust** — tests de charge pour valider le comportement sous stress

## Structure du repo

```
SRE-toolkit/
├── ansible.cfg
├── inventory/
│   ├── aws_ec2.yml            # inventaire dynamique (par tag Role)
│   └── group_vars/all.yml
├── playbooks/
│   └── site.yml               # playbook maître
├── roles/
│   ├── common/                # hardening de base + node_exporter
│   ├── app/                   # déploiement de l'API Flask
│   ├── loadbalancer/          # configuration Nginx
│   └── monitoring/            # Prometheus + Grafana + Alertmanager
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── ec2.tf
│   └── security_groups.tf
├── locust/
│   └── locustfile.py          # scénario de test de charge
└── requirements.yml            # collections Ansible
```

## Prérequis

- Compte AWS avec un utilisateur IAM dédié (accès programmatique, pas le root)
- Terraform >= 1.5
- Ansible >= 2.15 avec la collection `amazon.aws`
- Une key pair EC2 existante
- Python 3 + `boto3`/`botocore` (pour l'inventaire dynamique)

```bash
pip install boto3 botocore --break-system-packages
ansible-galaxy collection install amazon.aws
aws configure   # renseigner Access Key ID / Secret / région eu-west-3
```

## Déploiement

**1. Provisionner l'infrastructure**
```bash
cd terraform
terraform init
terraform apply
```

**2. Vérifier l'inventaire dynamique**
```bash
cd ..
ansible-inventory -i inventory/aws_ec2.yml --graph
```

**3. Déployer la configuration**
```bash
ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml
```

**4. Accéder aux interfaces**

Les ports 3000 (Grafana), 9090 (Prometheus) et 9093 (Alertmanager) sont exposés publiquement sur `monitor-01`. Si ton réseau bloque ces ports, utilise un tunnel SSH :
```bash
ssh -f -N -i ~/.ssh/<ta-clé>.pem \
  -L 9090:localhost:9090 \
  -L 3000:localhost:3000 \
  -L 9093:localhost:9093 \
  ubuntu@<IP_MONITOR_01>
```

| Interface    | URL                        | Identifiants par défaut |
|--------------|-----------------------------|--------------------------|
| Grafana      | http://localhost:3000       | admin / admin (à changer au premier login) |
| Prometheus   | http://localhost:9090       | — |
| Alertmanager | http://localhost:9093       | — |
| App (via LB) | http://\<IP_LB_01\>          | — |

## Fonctionnalités

- **Provisioning reproductible** — `terraform apply` recrée l'infra à l'identique
- **Inventaire dynamique** — Ansible détecte automatiquement les hôtes par tag AWS, aucune IP en dur
- **Dashboard as code** — Grafana provisionné avec datasource et dashboard via fichiers versionnés, zéro clic manuel
- **Alerting fonctionnel** — règles Prometheus déclenchant de vraies alertes (testé et validé sous charge Locust) :
  - `HighCPUUsage` — CPU > 70% pendant 1 min
  - `HighMemoryUsage` — RAM > 85% pendant 2 min
  - `LowDiskSpace` — espace disque < 15% pendant 5 min
  - `InstanceDown` — instance injoignable pendant 30s
- **Tests de charge** — scénario Locust pour générer du trafic réaliste et valider le comportement des alertes

## Limite connue

`monitor-01` héberge Prometheus, Grafana et Alertmanager simultanément sur une instance `t3.micro` (914 MiB RAM). Sous charge normale, l'utilisation mémoire dépasse déjà le seuil d'alerte de 85%, ce qui a été détecté et validé lors des tests (`HighMemoryUsage` déclenchée en conditions réelles). Passer en `t3.small` réglerait ce point ; conservé ici tel quel car cette contrainte illustre un vrai compromis de dimensionnement à documenter plutôt qu'à masquer.

## Pistes d'évolution

- Notification réelle des alertes (Slack/email) plutôt qu'un webhook local
- Playbook de chaos engineering pour valider `InstanceDown`
- Rolling updates / patch management via Ansible
- Runbooks documentés par type d'incident

## Nettoyage

```bash
cd terraform
terraform destroy
```
## Choix de sécurité assumés
- **Egress restreint aux ports 80/443** (HTTP/HTTPS) plutôt qu'entièrement ouvert, mais tfsec flague toujours `0.0.0.0/0` en egress par principe (`aws-ec2-no-public-egress-sgr`), ignoré explicitement et justifié : les instances doivent atteindre des dépôts publics (apt, GitHub releases) dont les IPs varient, donc un CIDR restreint casserait le déploiement sans NAT Gateway/VPC endpoints (hors scope de ce lab).