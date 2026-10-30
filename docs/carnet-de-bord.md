# Carnet de bord — MediSmart Cloud Deploy

Journal des incidents, analyses et apprentissages rencontrés au cours des différentes phases du projet.

---

## 28/10/2026 — Échec de résolution DNS Maven au premier build Docker

- **Ce que je voulais faire :** Compiler le backend dans un conteneur Docker multi-stage (`mvn dependency:go-offline`).
- **Ce qui s'est passé (message d'erreur exact) :**
  ```text
  [FATAL] Non-resolvable parent POM for com.medismart:backend:0.0.1-SNAPSHOT: 
  The following artifacts could not be resolved: org.springframework.boot:spring-boot-starter-parent:pom:3.2.3 (absent): 
  Could not transfer artifact ... from/to central (https://repo.maven.apache.org/maven2): 
  repo.maven.apache.org: Temporary failure in name resolution
  ```
- **Ce que j'ai compris :** Docker Desktop venait tout juste d'être démarré. Le service DNS interne du moteur Docker n'avait pas encore terminé son initialisation réseau, ce qui a causé un échec temporaire de résolution de noms de domaine au sein du conteneur de build.
- **Comment j'ai réparé :** Vérifié la connectivité et la résolution DNS avec un conteneur éphémère (`docker run --rm alpine ping -c 2 repo.maven.apache.org`), puis relancé le build une fois le réseau stabilisé.

---

## 28/10/2026 — Contexte de build volumineux (183 Mo) sur le frontend

- **Ce que je voulais faire :** Builder l'image Docker du frontend Angular avec un multi-stage build Node 20 + Nginx.
- **Ce qui s'est passé :** Docker a transféré 183 Mo de contexte (`transferring context: 183.48MB`), ralentissant considérablement le début du build.
- **Ce que j'ai compris :** En l'absence de fichier `.dockerignore`, Docker transférait les répertoires locaux `node_modules/`, `.angular/` et `dist/` vers le démon Docker, alors que le conteneur réinstalle ses propres dépendances via `npm ci`.
- **Comment j'ai réparé :** Création d'un fichier `.dockerignore` à la racine de `frontend-app` (excluant `node_modules`, `.angular`, `dist`, `.git`, `.idea`) ainsi que pour le backend (excluant `target`, `.git`, `uploads`).

---

## 28/10/2026 — Actuator Health en état DOWN malgré un boot réussi

- **Ce que je voulais faire :** Vérifier l'état de santé du backend via `/api/actuator/health`.
- **Ce qui s'est passé :** Le endpoint renvoie HTTP 503 avec le payload `{"status":"DOWN"}` alors que Spring Boot et PostgreSQL fonctionnent parfaitement.
- **Ce que j'ai compris :** Spring Boot Actuator enregistre automatiquement un `MailHealthIndicator` dès que `spring-boot-starter-mail` est présent dans le classpath. Comme les variables `MAIL_USERNAME` et `MAIL_PASSWORD` sont factices, le check SMTP échoue et bascule le statut global en `DOWN`.
- **Impact & Solution pour Kubernetes (Phase 2) :** Une `readinessProbe` Kubernetes redémarrerait ou isolerait le pod si le health global est `DOWN`. Solution : désactiver l'indicateur mail (`MANAGEMENT_HEALTH_MAIL_ENABLED=false`) pour baser la sonde uniquement sur les composants vitaux (base de données et espace disque).

---

## 28/10/2026 — Coupure volontaire de PostgreSQL en cours d'exécution

- **Ce que je voulais faire :** Observer le comportement du backend Spring Boot en cas de perte de connectivité avec la base (`docker stop medismart-postgres`).
- **Ce qui s'est passé :**
  - Le conteneur backend ne plante **pas** : il reste en cours d'exécution (`Up`).
  - Toute requête API nécessitant la base (`/api/villes`) bloque pendant le délai de `connectionTimeout` HikariCP (30 secondes), puis renvoie une réponse HTTP 500 avec `java.net.UnknownHostException: medismart-postgres` dans les logs (le nom DNS n'est plus résolu).
  - Au redémarrage de la base (`docker start medismart-postgres`), HikariCP rétablit automatiquement le pool de connexions sans nécessiter de redémarrage du backend (HTTP 200 immédiat).

---

## 28/10/2026 — Survie des données : suppression de conteneur avec vs sans volume Docker

- **Ce que je voulais faire :** Vérifier concrètement le rôle des volumes Docker sur la persistance des données PostgreSQL.
- **Ce qui s'est passé :**
  - **Avec volume (`-v medismart-pgdata:...`)** : La suppression du conteneur (`docker rm -f medismart-postgres`) suivie de sa recréation avec le même volume a conservé l'intégralité des 77 villes et des 45 changeSets Liquibase.
  - **Sans volume** : En recréant le conteneur sans monter le volume, PostgreSQL est reparti d'un cluster neuf et vide. L'appel à l'API a immédiatement échoué avec l'erreur `PSQLException: ERROR: relation "rendez_vous" does not exist`, car le backend déjà démarré n'exécute Liquibase qu'à son boot initial.
- **Ce que j'ai compris :** Les conteneurs sont éphémères et sans état par nature. Toutes les données persistantes doivent impérativement être découplées du cycle de vie du conteneur via un volume monté (ou un service managé comme Cloud SQL en Cloud).
