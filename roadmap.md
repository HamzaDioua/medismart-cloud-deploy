# Roadmap — MediSmart Cloud Deploy

> Objectif : implémenter le projet **en comprenant chaque brique**, pour pouvoir le refaire seul et l'expliquer en entretien (ACE).
> Référence : `design_1.md` (toutes les décisions y sont). Durée réaliste : **10 à 14 jours**, sans stress.

---

## La méthode (pour chaque phase)

Dans cet ordre, toujours :

1. **Comprendre** : lire le concept, l'expliquer avec mes mots.
2. **Essayer seul** : écrire le fichier moi-même, avant de demander de l'aide.
3. **Casser** : provoquer une erreur volontaire pour voir comment le système réagit.
4. **Réparer** : lire le message d'erreur en entier, chercher dans la doc officielle.
5. **Expliquer** : répondre à voix haute aux « Je sais expliquer » de la phase.

**Règle de passage :** on ne passe à la phase suivante que si les cases « Je sais expliquer » sont cochées.

### Le carnet de bord (`docs/carnet-de-bord.md`)

À chaque problème rencontré, une entrée :

```
## [date] Titre court
- Ce que je voulais faire :
- Ce qui s'est passé (message d'erreur exact) :
- Ce que j'ai compris :
- Comment j'ai réparé :
```

Ces entrées sont mes meilleures histoires d'entretien.

### Règles d'or

- **Coût :** alerte de budget créée avant la première ressource. `terraform destroy` à la fin de **chaque** session.
- **Secrets :** `.gitignore` dès le premier commit (`*.tfstate`, `.terraform/`, `*.json` de clés, `.env`). Aucun vrai secret dans Git.
- **Une seule chose à la fois :** si ça casse, je sais quelle modification est en cause.
- **Doc officielle d'abord** : les prix, les versions et les commandes changent.

---

## Phase 0 — Préparation (½ jour)

**Objectif :** être prêt à travailler sans friction et sans risque de facture.

**À faire**
- [ ] Alerte de budget GCP à 5 € (seuils 50 %, 90 %, 100 %)
- [ ] Outils installés : Docker, gcloud, kubectl, Terraform, minikube (ou Kubernetes de Docker Desktop)
- [ ] Repo `medismart-cloud-deploy` créé, avec `.gitignore`, README squelette, `docs/carnet-de-bord.md`
- [ ] Guide d'examen ACE officiel ouvert à côté (pour le tableau de la section 10 du design)

**Je sais expliquer**
- [ ] Pourquoi une alerte de budget ne suffit pas à protéger mes crédits
- [ ] Ce que je ne dois jamais pousser sur GitHub, et pourquoi

---

## Phase 1 — Docker en local (1 à 2 jours)

**Objectif :** un Dockerfile par composant qui build et tourne, et des mesures réelles pour la suite.

**À comprendre**
- Image, conteneur, couches et cache
- `RUN` (build) contre `ENTRYPOINT` (démarrage)
- Build multi-stage : pourquoi séparer compilation et exécution
- JDK contre JRE : ce qu'il faut pour seulement exécuter
- Réseau Docker : se joindre par le nom ; port mapping ; volumes

**À faire (moi, sans copier-coller)**
- [x] Dockerfile backend : ordre des couches pour profiter du cache, image finale légère (173 Mo), `tessdata` présent à l'exécution
- [x] Dockerfile frontend : relire l'existant et annoter chaque ligne (image finale Nginx de 30 Mo)
- [x] Lancer PostgreSQL + backend sur un réseau Docker (`medismart-net`), vérifier que Liquibase migre (45 changeSets appliqués)
- [x] **Test LiveKit :** démarrer le backend avec des valeurs bidon pour toutes les variables LiveKit, sans serveur. Noter le résultat (boot réussi, pas de fail-fast).
- [x] Lancer le frontend et vérifier que `/api` atteint le backend (le nom du Service `medismart-backend` résolu par Docker DNS, 77 villes retournées)

**Casser volontairement**
- [x] Modifier un fichier Java puis `pom.xml` et comparer ce qui est `CACHED` (couche `mvn dependency:go-offline` en cache instantané)
- [x] Arrêter la base : que fait le backend ? (Ne crash pas, timeout HikariCP de 30s puis 500, reconnexion auto au restart)
- [x] Supprimer le conteneur de la base avec puis sans volume : les données survivent-elles ? (Avec volume : 100 % préservées ; sans volume : cluster vide et `PSQLException relation does not exist`)

**Mesures à noter (elles règlent la phase 2)**
- [x] Temps de démarrage du backend : **41.6 secondes** (dimensionne le délai initial des sondes Kubernetes)
- [x] Mémoire utilisée (`docker stats`) : **~421 Mo** pour le backend, **~58.5 Mo** pour PostgreSQL
- [x] Réponse de `/api/actuator/health` : `{"status":"DOWN"}` (déclenché par `MailHealthIndicator`, à désactiver en Phase 2)

**Je sais expliquer**
- [x] Pourquoi `COPY pom.xml` vient avant `COPY src`
- [x] Pourquoi l'image finale n'a ni Maven ni le code source
- [x] Pourquoi `localhost` ne marche pas pour joindre la base depuis le conteneur du backend
- [x] Ce que le test LiveKit m'apprend sur la configuration de l'app

**Preuve :** captures des deux builds réussis et du `docker logs` du backend.

---

## Phase 2 — Kubernetes en local (1 à 2 jours)

**Objectif :** comprendre Kubernetes gratuitement, avant de payer le moindre cluster.

**À comprendre**
- Pod, Deployment, ReplicaSet, Service (ClusterIP et LoadBalancer)
- ConfigMap et Secret : ce qui va où, et pourquoi un Secret n'est qu'encodé
- Probes `readiness` et `liveness` : la différence
- `requests` et `limits` ; ce qui se passe quand la mémoire dépasse la limite
- Stratégie de mise à jour : `RollingUpdate` contre `Recreate` (décision 1)
- Résolution DNS interne : le nom du Service

**À faire**
- [x] Charger mes images dans minikube
- [x] Manifests : Deployment + Service pour le frontend (2 réplicas) et le backend (1 réplica, `Recreate`, Service `medismart-backend`)
- [x] PostgreSQL provisoire dans le cluster (sert seulement à tester en local)
- [x] ConfigMap et Secret pour les variables (section 6 du design)
- [x] Probes réglées avec les mesures de la phase 1
- [x] `requests` et `limits` calculés à partir de `docker stats`

**Casser volontairement**
- [ ] Mettre une mauvaise image : lire l'état du pod (`ImagePullBackOff`) et corriger
- [ ] Mettre une limite mémoire trop basse : observer `OOMKilled`
- [ ] Supprimer un pod du frontend : voir Kubernetes le recréer
- [ ] Renommer le Service du backend : voir Nginx échouer

**Je sais expliquer**
- [ ] La différence entre un pod, un Deployment et un Service
- [ ] Pourquoi le backend est en `ClusterIP` et le frontend en `LoadBalancer`
- [ ] Pourquoi `Recreate` plutôt que `RollingUpdate` pour le backend
- [ ] La différence entre readiness et liveness
- [ ] Où va chaque variable : ConfigMap ou Secret

**Preuve :** `kubectl get pods` en `Running`, l'app accessible via minikube.

---

## Phase 3 — Socle GCP (1 jour)

**Objectif :** préparer le terrain permanent, avec un accès minimal et sans clé JSON.

**À comprendre**
- Projet, facturation, API à activer
- IAM : compte de service, rôle, principe du moindre privilège
- Artifact Registry : dépôt, région, tag
- Workload Identity Federation (GitHub → GCP) : pourquoi c'est mieux qu'une clé JSON
- Secret Manager : secret, version, accès

**À faire**
- [ ] Projet GCP dédié, API activées
- [ ] Artifact Registry (Docker, `europe-west1`)
- [ ] Pousser à la main une image avec un tag SHA
- [ ] Compte de service CI avec des rôles minimaux
- [ ] Workload Identity Federation pour GitHub
- [ ] Secret Manager : créer les secrets de l'application (valeurs de test)
- [ ] Bucket pour l'état Terraform

**Casser volontairement**
- [ ] Donner un rôle trop faible au compte de service : lire l'erreur de permission
- [ ] Pousser une image avec un mauvais nom de dépôt

**Je sais expliquer**
- [ ] Pourquoi le moindre privilège, avec un exemple de mon projet
- [ ] Comment GitHub s'authentifie sans clé secrète
- [ ] Pourquoi le tag est un SHA et non `latest`

**Preuve :** image visible dans Artifact Registry, secrets créés.

---

## Phase 4 — Terraform : les bases (1 jour)

**Objectif :** comprendre Terraform sur de petites ressources avant de construire le cluster.

**À comprendre**
- Provider, resource, variable, output
- `init`, `plan`, `apply`, `destroy`
- L'état (state) : ce qu'il contient, pourquoi il doit être stocké à distance et protégé
- Dépendances entre ressources (implicites et explicites)

**À faire**
- [ ] Créer un bucket simple, puis le modifier, puis le détruire
- [ ] Passer l'état dans le bucket distant
- [ ] Écrire `terraform/foundation` (le socle de la phase 3) en Terraform

**Casser volontairement**
- [ ] Modifier une ressource à la main dans la console, puis lancer `plan` : que montre-t-il ?
- [ ] Supprimer le fichier d'état local (avec un état distant en place) : que se passe-t-il ?

**Je sais expliquer**
- [ ] Ce que fait `plan` et pourquoi on le lit avant chaque `apply`
- [ ] Pourquoi un fichier d'état ne va jamais sur GitHub
- [ ] Pourquoi deux dossiers : socle permanent et environnement jetable

---

## Phase 5 — Environnement jetable en Terraform (2 à 3 jours)

**Objectif :** créer et détruire proprement toute l'infrastructure à la demande. C'est la phase la plus dense.

**Ordre de construction (une couche à la fois, avec `plan` puis `apply` entre chaque)**

1. **Réseau :** VPC, sous-réseau, accès aux services privés (couloir privé vers Cloud SQL)
2. **Cluster :** GKE Standard zonal (`europe-west1-b`), 1 nœud `e2-medium`, nœuds publics, Workload Identity activé, add-on `GcsFuseCsiDriver` activé
3. **Base :** Cloud SQL PostgreSQL en IP privée, nom avec suffixe aléatoire, utilisateur et mot de passe créés par Terraform (mot de passe dans Secret Manager), protection de suppression désactivée
4. **Stockage :** bucket des fichiers (`force_destroy = true`), compte de service avec rôle minimal sur ce bucket
5. **IP statique** pour le frontend

**À comprendre**
- VPC, sous-réseaux, peering : pourquoi Cloud SQL a besoin d'un couloir privé
- Zonal contre régional (décision A)
- Workload Identity côté pod : compte de service Kubernetes lié à un compte de service Google
- Ordre de création et de suppression des ressources dépendantes

**Casser volontairement**
- [ ] Lancer `destroy` dans le mauvais ordre : lire l'erreur, comprendre la dépendance
- [ ] Créer Cloud SQL sans le couloir privé : lire l'erreur

**Je sais expliquer**
- [ ] Pourquoi Cloud SQL n'est pas accessible depuis Internet
- [ ] Pourquoi le nom d'instance Cloud SQL porte un suffixe aléatoire
- [ ] Comment un pod obtient le droit d'écrire dans un bucket sans clé
- [ ] Pourquoi le bucket des fichiers est dans l'environnement jetable

**Rappel coût :** `terraform destroy` à la fin de **chaque** session. Cloud SQL se facture même la nuit.

---

## Phase 6 — Premier déploiement réel sur GKE (1 à 2 jours)

**Objectif :** faire tourner l'app sur le vrai cluster, à la main, avant d'automatiser.

**À faire**
- [ ] Récupérer les accès au cluster et vérifier `kubectl`
- [ ] Adapter les manifests de la phase 2 : image depuis Artifact Registry (tag SHA), `SPRING_DATASOURCE_URL` vers l'IP privée de Cloud SQL, secrets depuis Secret Manager
- [ ] Monter le bucket dans le pod du backend, pointer `ATTACHMENTS_DIR` dessus
- [ ] Service `LoadBalancer` avec l'IP statique, `FRONTEND_URL` mis à jour
- [ ] Restreindre le CORS à l'origine du frontend
- [ ] Tester : inscription, connexion, upload d'un fichier, relecture du fichier après redémarrage du pod

**Casser volontairement**
- [ ] Redéployer une nouvelle image : le fichier uploadé est-il toujours là ?
- [ ] Retirer le droit d'accès au bucket : lire l'erreur
- [ ] Mauvais mot de passe de base : lire les logs

**Plan B si le montage FUSE pose problème :** PVC. Noter le problème dans le carnet de bord.

**Je sais expliquer**
- [ ] Le chemin d'une requête, du navigateur à la base
- [ ] Ce que fait le sidecar FUSE injecté dans le pod
- [ ] Pourquoi mon fichier survit à un redéploiement

**Preuves :** cluster actif, pods `Running`, app accessible via l'IP publique, fichier relu après redéploiement.

---

## Phase 7 — CI/CD avec GitHub Actions (1 à 2 jours)

**Objectif :** automatiser la fabrication des images, et lancer le déploiement à la demande.

**À comprendre**
- Workflow, job, step, secret, variable
- Déclencheurs : `push` et `workflow_dispatch`
- Authentification par Workload Identity Federation dans un workflow
- Pourquoi le CI et le CD sont séparés (décision 6)

**À faire**
- [ ] Un workflow qui fait seulement un `echo`, puis qui s'authentifie à GCP
- [ ] CI du backend : build, push vers Artifact Registry, tag = SHA du commit
- [ ] CI du frontend : idem
- [ ] CD manuel dans `medismart-cloud-deploy` : paramètre = tag, mise à jour du déploiement
- [ ] Vérifier qu'un `push` sans cluster ne casse pas le CI

**Casser volontairement**
- [ ] Mauvais nom de pool d'identité : lire l'erreur d'authentification
- [ ] Lancer le CD sans cluster : observer l'échec et le comprendre

**Je sais expliquer**
- [ ] Pourquoi le déploiement est manuel
- [ ] Ce que contient le tag d'une image et comment retrouver le code correspondant
- [ ] Comment revenir à une version précédente

**Preuves :** pipeline CI vert, image taguée SHA dans Artifact Registry, run CD vert.

---

## Phase 8 — Finalisation (1 jour)

**Objectif :** transformer un projet qui marche en projet qui se présente.

**À faire**
- [ ] Captures d'écran : cluster actif, pods `Running`, pipeline vert, Artifact Registry, app accessible, bucket avec les fichiers
- [ ] Schéma d'architecture **redessiné par moi** (`docs/architecture.png`)
- [ ] README complet : contexte, architecture, décisions et sacrifices, étapes pour reproduire, coûts réels, améliorations possibles
- [ ] Tableau de correspondance ACE (section 10 du design) complété
- [ ] Optionnel : Cloud Logging et Monitoring (un tableau de bord et une alerte), pour combler le trou identifié
- [ ] Vidéo courte de démonstration (créer, déployer, tester, détruire)
- [ ] `terraform destroy` final, facturation vérifiée le lendemain
- [ ] Repo public, ligne ajoutée au CV, lien en tête du profil GitHub

**Je sais expliquer (répétition d'entretien, 30 secondes par décision, sans notes)**
- [ ] 1 seul réplica pour le backend
- [ ] Cloud SQL en IP privée
- [ ] Fichiers dans Cloud Storage via FUSE
- [ ] Frontend public et backend privé
- [ ] CI automatique et CD manuel
- [ ] Tag SHA
- [ ] Un problème que j'ai rencontré et comment je l'ai réparé

---

## Calendrier indicatif

| Phase | Durée | Coût GCP |
|---|---|---|
| 0. Préparation | ½ jour | Aucun |
| 1. Docker | 1 à 2 jours | Aucun |
| 2. Kubernetes local | 1 à 2 jours | Aucun |
| 3. Socle GCP | 1 jour | Très faible |
| 4. Terraform : bases | 1 jour | Très faible |
| 5. Environnement jetable | 2 à 3 jours | Heures de cluster et de Cloud SQL |
| 6. Déploiement réel | 1 à 2 jours | Idem |
| 7. CI/CD | 1 à 2 jours | Faible |
| 8. Finalisation | 1 jour | Faible |

---

## Routine de chaque session GCP

**Avant de commencer**
- [ ] Alerte de budget active
- [ ] `terraform plan` lu en entier avant `apply`

**Avant de quitter**
- [ ] Service `LoadBalancer` supprimé
- [ ] `terraform destroy` terminé sans erreur
- [ ] Console GCP vérifiée : plus de cluster, de base, de disque ni de load balancer
- [ ] Entrée ajoutée au carnet de bord
- [ ] Le lendemain : vérifier la facturation
