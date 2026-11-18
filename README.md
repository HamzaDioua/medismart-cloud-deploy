# 🏥 MediSmart Cloud Deploy — Production-Grade Cloud & DevOps Architecture

> Déploiement automatisé et sécurisé d'une plateforme médicale sur Google Cloud Platform (GCP) à l'aide de **Docker**, **Kubernetes (GKE)**, **Terraform (IaC)** et **GitHub Actions (CI/CD)**.

![GCP](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)

---

## 🏛️ Architecture Globale

```
                         [ Utilisateur Final / Navigateur ]
                                       │
                                       ▼ (Port 80)
                         [ GKE External Load Balancer ]
                                       │
                ┌──────────────────────┴──────────────────────┐
                │                                             │
                ▼ (Proxy /api/*)                              ▼ (Static SPA)
     [ Service: medismart-backend ]               [ Service: medismart-frontend ]
                │                                             │
      ┌─────────┴─────────┐                         ┌─────────┴─────────┐
      │ Pod: Spring Boot  │                         │  Pods: Angular    │
      │ 1 Replica         │                         │  2 Replicas (HA)  │
      │ (Strategy:Recreate│                         │  (RollingUpdate)  │
      └─────────┬─────────┘                         └───────────────────┘
                │
        ┌───────┴────────────────────────┐
        ▼ (GCS FUSE CSI)                 ▼ (VPC Peering Privé 10.10.0.0/20)
 [ Cloud Storage: Files/OCR ]   [ Cloud SQL PostgreSQL 16 (IP Privée) ]
```

---

## 🔒 Principes d'Ingénierie & Sécurité (Decisions Log)

1. **Authentification Zero-Secret (Workload Identity Federation) :**
   - Aucune clé de compte de service (`credentials.json`) n'est stockée dans GitHub Secrets.
   - GitHub Actions génère un jeton OIDC à durée limitée, validé par Google Cloud STS et échangé contre un jeton temporaire d'usurpation (*impersonation*).

2. **Moindre Privilège (Principle of Least Privilege - PoLP) :**
   - Le compte de service CI ne possède que le rôle strict `roles/artifactregistry.writer`.
   - Les nœuds GKE possèdent un compte de service dédié avec uniquement `logging.logWriter` et `monitoring.metricWriter`.

3. **Concurrence & Persistance Applicative :**
   - **Backend Spring Boot** : Déployé avec `replicas: 1` et stratégie `Recreate` pour éviter tout conflit de concurrence sur les tâches `@Scheduled` sans implémentation de verrous distribués (ShedLock).
   - **Frontend Angular/Nginx** : Déployé en haute disponibilité avec `replicas: 2` et stratégie `RollingUpdate` sans interruption de service.

4. **Sondes de Santé Calibrées :**
   - Démarrage Spring Boot mesuré : **41.6 secondes**.
   - Mise en place d'une `startupProbe` (15s initial + 20 périodes de 5s = 115s de tolérance) pour protéger le conteneur contre les redémarrages prématurés par la `livenessProbe`.

5. **Découpage d'Infrastructure Terraform en 2 Couches :**
   - `terraform/foundation/` : Ressources permanentes à cycle de vie long (Artifact Registry, WIF, Secret Manager, GCS State Bucket).
   - `terraform/environment/` : Ressources dynamiques applicatives (VPC, Sous-réseaux, Cloud SQL IP Privée, Cluster GKE).

---

## 📂 Structure du Répertoire

```tree
medismart-cloud-deploy/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml           # Pipeline CI/CD Spring Boot avec WIF
│       └── frontend-ci.yml          # Pipeline CI/CD Angular avec WIF
├── k8s/                             # Manifests Kubernetes pour environnement local (Minikube)
│   ├── 00-postgres.yaml
│   ├── 01-backend-configmap.yaml
│   ├── 02-backend-secret.yaml
│   ├── 03-backend.yaml
│   └── 04-frontend.yaml
├── k8s-prod/                        # Manifests Kubernetes adaptés pour Google Kubernetes Engine (GKE)
│   ├── 00-namespace.yaml
│   ├── 01-backend-configmap.yaml
│   ├── 02-backend-secret.yaml
│   ├── 03-backend.yaml             # Annotations GCS FUSE & Workload Identity
│   └── 04-frontend.yaml
├── terraform/
│   ├── foundation/                  # Socle permanent (AR, IAM, WIF, Secrets)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── versions.tf
│   │   └── outputs.tf
│   └── environment/                 # Socle jetable (VPC, Cloud SQL, Cluster GKE)
│       ├── main.tf
│       ├── variables.tf
│       ├── versions.tf
│       └── outputs.tf
├── docs/
│   └── carnet-de-bord.md           # Récit d'apprentissage, ateliers "Casser/Réparer"
├── design.md                        # Document de conception d'architecture
└── roadmap.md                       # Feuille de route du projet validée
```

---

## 🚀 Guide de Déploiement

### 1. Initialiser le Socle Permanent (Foundation)

```bash
cd terraform/foundation
terraform init
terraform apply
```

### 2. Déployer l'Environnement Applicatif (Environment)

```bash
cd ../environment
terraform init
terraform apply
```

### 3. Connecter Kubectl au Cluster GKE

```bash
gcloud container clusters get-credentials medismart-cluster-prod --zone europe-west1-b --project medismart-cloud-deploy
```

### 4. Appliquer les Manifests de Production

```bash
kubectl apply -f ../../k8s-prod/
```

### 5. Vérifier le Déploiement

```bash
kubectl get pods -n medismart
kubectl get svc -n medismart
```

---

## 👨‍💻 Auteur

- **Hamza Dioua** — *Cloud DevOps Engineer*
- **Projet** : MediSmart Cloud Deploy — Architecture Cloud Native GCP
