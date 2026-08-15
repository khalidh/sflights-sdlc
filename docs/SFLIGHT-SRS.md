# SFLIGHT — Software Requirements Specification

**Version analysée :** 1.0.0  
**Date d'analyse :** 2026-08-15  
**Méthode :** reverse engineering du code, des modèles CDS, annotations Fiori, configurations, données et tests  
**Convention de confiance :** **CONFIRMÉE**, **FORTEMENT DÉDUITE**, **HYPOTHÈSE**

---

## 1. Executive Summary

SFLIGHT est une application SAP CAP Node.js de gestion de voyages. Elle permet à un gestionnaire de consulter et maintenir des voyages et leur arborescence de réservations et suppléments, et à un validateur d'accepter ou rejeter les voyages ouverts. Le prix total est recalculé à partir des frais de réservation, des prix des vols réservés et des suppléments. Une remise explicite peut également être appliquée au total d'un voyage ouvert.

L'interface est une application SAP Fiori Elements OData V4 composée d'un List Report `Travels` et d'une Object Page. Les voyages utilisent le draft CAP. Les référentiels — agences, clients, aéroports, transporteurs, connexions, vols et suppléments — sont exposés en lecture seule. La persistance locale est SQLite ; la cible productive est SAP HANA Cloud via un conteneur HDI. L'authentification productive est XSUAA.

Toutes ces capacités sont **CONFIRMÉES** par le code. Aucune implémentation ABAP, RAP, Behavior Definition, Behavior Implementation, Service Definition ABAP ou Service Binding ABAP n'est présente.

### Résultats des passes

| Passe                                | Résultat principal                                                                                        |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| PASS 1 — Repository Discovery        | Projet CAP Node.js structuré en `db`, `srv`, `app`, `test`, configuration BTP et SDLC GitHub              |
| PASS 2 — Domain Discovery            | 10 entités persistées, 2 types de statut, compositions Travel–Booking–Supplement                          |
| PASS 3 — Behavior Discovery          | Draft, CRUD restreint, 3 actions, 3 validations principales, détermination de prix et calcul de criticité |
| PASS 4 — UI Discovery                | List Report et Object Page Travel ; tables imbriquées pour réservations et suppléments                    |
| PASS 5 — Security Discovery          | `TravelProcessor`, `TravelReviewer`, `Administrator`, XSUAA en production et mock local                   |
| PASS 6 — Test Discovery              | 7 tests : santé, lecture, draft/date, acceptation, refus d'autorisation, remise/rejet, borne de remise    |
| PASS 7 — Requirements Reconstruction | 16 FR, 17 BR, 10 UC, 2 UI, 5 SEC                                                                          |
| PASS 8 — Cross Validation            | Traçabilité code/test établie ; lacunes et ambiguïtés isolées                                             |
| PASS 9 — SRS Generation              | Présent document                                                                                          |

---

## 2. Business Context

### 2.1 Objectif métier

L'application centralise la préparation et la validation de dossiers de voyage. Un dossier associe une agence et un client, couvre une période, porte une devise et agrège des réservations de vols et des suppléments. Le dossier suit un statut ouvert, accepté ou rejeté.

**Preuves :** `db/schema.cds:73-105`, `srv/travel-service.cds:3-41`, `app/travel/annotations.cds:3-68`.

### 2.2 Processus métier principal

```text
Création / édition du voyage en brouillon
                 |
                 v
  Association agence + client + dates
                 |
                 v
 Ajout de réservations et de suppléments
                 |
                 v
 Recalcul du prix total / remise éventuelle
                 |
                 v
      Voyage actif au statut O (ouvert)
              /             \
             v               v
      Acceptation (A)    Rejet (X)
```

Le draft et les deux transitions finales sont **CONFIRMÉS**. L'ordre exact « ajout puis validation » est **FORTEMENT DÉDUIT** des restrictions de statut et des compositions, mais aucune orchestration BPM dédiée n'existe.

---

## 3. Scope

### 3.1 Inclus

- consultation, recherche et filtrage OData/Fiori des voyages ;
- création et édition draft de voyages ;
- suppression de voyages ouverts selon la restriction CDS ;
- consultation et maintenance de réservations et suppléments ;
- consultation des référentiels de transport et de tiers ;
- acceptation ou rejet d'un voyage ouvert ;
- application d'une remise en pourcentage ;
- recalcul du total lors des mutations de réservations ou suppléments ;
- affichage d'une criticité de statut ;
- sécurité par rôles et authentification ;
- déploiement BTP Cloud Foundry/HANA/HTML5 Repository.

### 3.2 Hors périmètre observé

- paiement, facturation, émission de billet et remboursement ;
- gestion autonome des référentiels dans le service exposé ;
- workflow SAP Build Process Automation ou Flexible Workflow ;
- notifications, e-mails et tâches humaines ;
- intégration à un système externe de réservation ;
- logique ABAP/RAP ;
- application UI dédiée aux clients, agences, vols ou administrateurs ;
- historique métier explicite des décisions.

---

## 4. Actors

| Acteur                                   | Responsabilités                   | Permissions confirmées                                                                                                         | Interdictions confirmées                                            | Rôle technique                              | Confiance             |
| ---------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- | ------------------------------------------- | --------------------- |
| Travel Processor                         | Préparer et maintenir les voyages | Lire les voyages ; créer/modifier/supprimer les voyages ouverts ; maintenir réservations et suppléments ; appliquer une remise | Ne peut pas accepter/rejeter ; test d'acceptation à 403             | `TravelProcessor`                           | **CONFIRMÉE**         |
| Travel Reviewer                          | Examiner et décider               | Lire voyages/réservations/suppléments ; accepter ou rejeter un voyage ouvert                                                   | Pas de CRUD Travel, Booking ou BookingSupplement ; pas de remise    | `TravelReviewer`                            | **CONFIRMÉE**         |
| Administrator                            | Administrer avec droits cumulés   | Dispose des scopes Administrator, Processor et Reviewer ; CRUD et actions par cumul                                            | CRUD Travel toujours soumis au filtre `status = 'O'`                | `Administrator` + scopes Processor/Reviewer | **CONFIRMÉE**         |
| Utilisateur authentifié sans rôle métier | Accéder techniquement au service  | Franchit potentiellement le `requires: authenticated-user`                                                                     | Les restrictions d'entités ne lui accordent aucune opération métier | Aucun rôle métier                           | **FORTEMENT DÉDUITE** |

**Sources :** `srv/travel-service.cds:3,26-41`, `xs-security.json:2-27`, `.cdsrc.json:2-10`, `test/integration/travel-service.test.js:52-62`.

### 4.1 Particularités de sécurité

- En local, les utilisateurs `processor`, `reviewer` et `admin` sont simulés avec mots de passe en clair de développement (`.cdsrc.json:4-9`).
- En production, CAP bascule vers XSUAA et HANA (`package.json:62-80`).
- L'AppRouter exige XSUAA pour les routes OData et HTML5 (`app/router/xs-app.json:3-17`).
- Le rôle Administrator possède explicitement les trois scopes (`xs-security.json:23-26`) ; ce cumul explique l'accès aux actions dont `@requires` mentionne Processor ou Reviewer.

---

## 5. Domain Model

### 5.1 Concepts métier

| Concept            | Définition et responsabilité                          | Attributs principaux                                     | Relations et cardinalités                           | Contraintes / cycle de vie                                          | Confiance     |
| ------------------ | ----------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------- | ------------- |
| Travel             | Dossier de voyage porté par une agence pour un client | numéro, dates, frais, total, devise, description, statut | 1 agence ; 1 client ; 0..n bookings                 | Statuts O/A/X ; draft côté service ; actions accept/reject/discount | **CONFIRMÉE** |
| Booking            | Réservation d'un vol dans un voyage                   | numéro, date, prix vol, devise, statut                   | 1 travel ; 1 client ; 1 flight ; 0..n supplements   | Statuts N/B/X modélisés ; modification contrôlée si voyage ouvert   | **CONFIRMÉE** |
| Booking Supplement | Poste de supplément rattaché à une réservation        | numéro de poste, prix, devise                            | 1 booking ; 1 supplement                            | Prix non négatif ; prix/devise copiés du référentiel si omis        | **CONFIRMÉE** |
| Customer           | Personne cliente d'un voyage/réservation              | numéro, identité, coordonnées, adresse                   | 0..n travels ; référencé par bookings               | Numéro annoté unique ; prénom/nom obligatoires                      | **CONFIRMÉE** |
| Agency             | Agence responsable du voyage                          | numéro, nom, adresse, contact                            | 0..n travels                                        | Numéro annoté unique ; nom obligatoire                              | **CONFIRMÉE** |
| Carrier            | Compagnie aérienne                                    | code, nom, devise                                        | 0..n connections                                    | Code annoté unique                                                  | **CONFIRMÉE** |
| Connection         | Route commerciale entre deux aéroports                | numéro, horaires, distance                               | 1 carrier ; 1 départ ; 1 destination ; 0..n flights | Associations obligatoires                                           | **CONFIRMÉE** |
| Flight             | Occurrence datée d'une connexion                      | date, prix, devise, appareil, capacité/occupation        | 1 connection ; 0..n bookings                        | Date/prix/devise obligatoires ; occupation par défaut 0             | **CONFIRMÉE** |
| Airport            | Référentiel d'aéroport                                | code, nom, ville, pays                                   | Départ/destination de connections                   | Champs principaux obligatoires ; code annoté unique                 | **CONFIRMÉE** |
| Supplement         | Catalogue de prestations additionnelles               | code, nom, prix, devise                                  | Référencé par BookingSupplement                     | Code annoté unique ; prix/devise obligatoires                       | **CONFIRMÉE** |

### 5.2 Représentation textuelle

```text
Agency [1] ───────────────┐
                          v
Customer [1] ────────> Travel [1]
                          ├── status: O | A | X
                          └── Booking [0..n]
                                ├── Customer [1]
                                ├── Flight [1]
                                │     └── Connection [1]
                                │           ├── Carrier [1]
                                │           ├── Departure Airport [1]
                                │           └── Destination Airport [1]
                                └── BookingSupplement [0..n]
                                      └── Supplement [1]
```

### 5.3 Agrégats DDD déduits

- **Agrégat Travel :** `Travels` est racine ; `Bookings` et `BookingSupplements` sont des compositions. Cette frontière est **CONFIRMÉE techniquement** (`db/schema.cds:73-105`).
- **Référentiels indépendants :** Agency, Customer, Airport, Carrier, Connection, Flight et Supplement ont leur propre identité UUID et sont associés, non composés. Cette lecture est **FORTEMENT DÉDUITE** de la modélisation CDS.
- Aucun bounded context explicite n'est déclaré. Un unique namespace `sflight` et un seul service suggèrent un seul contexte applicatif ; **FORTEMENT DÉDUIT**.

---

## 6. Data Model

Toutes les entités incluent `BusinessObject`, donc une clé `ID: UUID` et les champs administratifs CAP `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy` via `cuid, managed` (`db/common.cds:3,17`).

### 6.1 Agencies

| Élément      | Description                                                                             |
| ------------ | --------------------------------------------------------------------------------------- |
| Entité       | `sflight.Agencies`                                                                      |
| Description  | Agence de voyage responsable d'un dossier                                               |
| Source       | `db/schema.cds:5-15`                                                                    |
| Clé primaire | `ID: UUID` hérité                                                                       |
| Attributs    | `agencyNumber`, `name`, `street`, `postalCode`, `city`, `countryCode`, `phone`, `email` |
| Types        | String(8/80/10/40/3/30/255)                                                             |
| Associations | `travels` vers `Travels`                                                                |
| Cardinalités | Agency 1 ← 0..n Travels                                                                 |
| Contraintes  | numéro et nom obligatoires ; `agencyNumber @assert.unique`                              |
| Calculs      | Aucun                                                                                   |

### 6.2 Customers

| Élément      | Description                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------- |
| Entité       | `sflight.Customers`                                                                                        |
| Description  | Client voyageur ou commanditaire                                                                           |
| Source       | `db/schema.cds:17-28`                                                                                      |
| Clé primaire | `ID: UUID`                                                                                                 |
| Attributs    | `customerNumber`, `firstName`, `lastName`, `email`, `phone`, `street`, `postalCode`, `city`, `countryCode` |
| Types        | String                                                                                                     |
| Associations | `travels` ; référencé aussi par `Bookings.customer`                                                        |
| Cardinalités | Customer 1 ← 0..n Travels ; Customer 1 ← 0..n Bookings (inverse non déclaré)                               |
| Contraintes  | numéro/prénom/nom obligatoires ; numéro annoté unique                                                      |
| Calculs      | Aucun                                                                                                      |

### 6.3 Airports

| Élément      | Description                                                             |
| ------------ | ----------------------------------------------------------------------- |
| Entité       | `sflight.Airports`                                                      |
| Description  | Référentiel des aéroports                                               |
| Source       | `db/schema.cds:30-35`                                                   |
| Clé primaire | `ID: UUID`                                                              |
| Attributs    | `airportCode`, `name`, `city`, `countryCode`                            |
| Types        | String(3/80/40/3)                                                       |
| Associations | Cible de `Connections.departureAirport` et `destinationAirport`         |
| Cardinalités | Un Airport peut être utilisé par 0..n Connections ; inverse non déclaré |
| Contraintes  | Tous les champs obligatoires ; code annoté unique                       |
| Calculs      | Aucun                                                                   |

### 6.4 Carriers

| Élément      | Description                                         |
| ------------ | --------------------------------------------------- |
| Entité       | `sflight.Carriers`                                  |
| Description  | Compagnie aérienne                                  |
| Source       | `db/schema.cds:37-42`                               |
| Clé primaire | `ID: UUID`                                          |
| Attributs    | `carrierCode`, `name`, `currency`                   |
| Types        | String(3/80), Currency String(3)                    |
| Associations | `connections`                                       |
| Cardinalités | Carrier 1 ← 0..n Connections                        |
| Contraintes  | code, nom, devise obligatoires ; code annoté unique |
| Calculs      | Aucun                                               |

### 6.5 Connections

| Élément      | Description                                                      |
| ------------ | ---------------------------------------------------------------- |
| Entité       | `sflight.Connections`                                            |
| Description  | Liaison aérienne planifiée entre deux aéroports                  |
| Source       | `db/schema.cds:44-53`                                            |
| Clé primaire | `ID: UUID`                                                       |
| Attributs    | `connectionNumber`, `departureTime`, `arrivalTime`, `distanceKm` |
| Types        | String(4), Time, Integer                                         |
| Associations | `carrier`, `departureAirport`, `destinationAirport`, `flights`   |
| Cardinalités | 1 carrier ; 1 aéroport départ ; 1 destination ; 0..n flights     |
| Contraintes  | numéro et trois associations obligatoires                        |
| Calculs      | Aucun                                                            |

### 6.6 Flights

| Élément      | Description                                                                     |
| ------------ | ------------------------------------------------------------------------------- |
| Entité       | `sflight.Flights`                                                               |
| Description  | Vol daté exécutant une connexion                                                |
| Source       | `db/schema.cds:55-64`                                                           |
| Clé primaire | `ID: UUID`                                                                      |
| Attributs    | `flightDate`, `price`, `currency`, `planeType`, `maximumSeats`, `occupiedSeats` |
| Types        | Date, Decimal(15,2), Currency, String(20), Integer                              |
| Associations | `connection`, `bookings`                                                        |
| Cardinalités | 1 connection ; 0..n bookings                                                    |
| Contraintes  | connection/date/prix/devise obligatoires ; occupiedSeats par défaut 0           |
| Calculs      | Aucun calcul de sièges observé                                                  |

### 6.7 Supplements

| Élément      | Description                                       |
| ------------ | ------------------------------------------------- |
| Entité       | `sflight.Supplements`                             |
| Description  | Catalogue de prestations additionnelles           |
| Source       | `db/schema.cds:66-71`                             |
| Clé primaire | `ID: UUID`                                        |
| Attributs    | `supplementCode`, `name`, `price`, `currency`     |
| Types        | String(10/80), Decimal(15,2), Currency            |
| Associations | Cible de `BookingSupplements.supplement`          |
| Cardinalités | 1 Supplement ← 0..n BookingSupplements            |
| Contraintes  | tous champs obligatoires ; code annoté unique     |
| Calculs      | Source de la détermination prix/devise d'un poste |

### 6.8 Travels

| Élément      | Description                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------- |
| Entité       | `sflight.Travels`                                                                                       |
| Description  | Racine du dossier de voyage                                                                             |
| Source       | `db/schema.cds:73-85`                                                                                   |
| Clé primaire | `ID: UUID`                                                                                              |
| Attributs    | `travelNumber`, `beginDate`, `endDate`, `bookingFee`, `totalPrice`, `currency`, `description`, `status` |
| Types        | Integer, Date, Decimal(15,2), Currency, String(255), TravelStatus                                       |
| Associations | `agency`, `customer`; composition `bookings`                                                            |
| Cardinalités | 1 agency ; 1 customer ; 0..n bookings                                                                   |
| Contraintes  | numéro/agence/client/dates/devise obligatoires ; numéro annoté unique ; statut par défaut O             |
| Calculs      | `totalPrice`; champ de service virtuel `statusCriticality`                                              |

### 6.9 Bookings

| Élément      | Description                                                                      |
| ------------ | -------------------------------------------------------------------------------- |
| Entité       | `sflight.Bookings`                                                               |
| Description  | Réservation d'un vol dans un voyage                                              |
| Source       | `db/schema.cds:87-97`                                                            |
| Clé primaire | `ID: UUID`                                                                       |
| Attributs    | `bookingNumber`, `bookingDate`, `flightPrice`, `currency`, `status`              |
| Types        | Integer, Date, Decimal(15,2), Currency, BookingStatus                            |
| Associations | `travel`, `customer`, `flight`; composition `supplements`                        |
| Cardinalités | 1 travel ; 1 customer ; 1 flight ; 0..n booking supplements                      |
| Contraintes  | associations, numéro, date et devise obligatoires ; prix non négatif par handler |
| Calculs      | Entre dans le total du voyage                                                    |

### 6.10 BookingSupplements

| Élément      | Description                                                               |
| ------------ | ------------------------------------------------------------------------- |
| Entité       | `sflight.BookingSupplements`                                              |
| Description  | Poste de supplément facturé sur une réservation                           |
| Source       | `db/schema.cds:99-105`                                                    |
| Clé primaire | `ID: UUID`                                                                |
| Attributs    | `itemNumber`, `price`, `currency`                                         |
| Types        | Integer, Decimal(15,2), Currency                                          |
| Associations | `booking`, `supplement`                                                   |
| Cardinalités | 1 booking ; 1 supplement                                                  |
| Contraintes  | booking/poste/supplement/devise obligatoires ; prix non négatif           |
| Calculs      | Prix/devise copiés du Supplement si prix absent ; entre dans total Travel |

### 6.11 Contraintes de données à valider

- `@assert.unique` est placé au niveau des éléments. L'intention d'unicité est **CONFIRMÉE**, mais son enforcement effectif sur toutes les bases n'est pas couvert par les tests : **HYPOTHÈSE à valider techniquement**.
- Aucune contrainte composite n'empêche deux `bookingNumber` identiques dans un même voyage ou deux `itemNumber` identiques dans une réservation.
- Aucune règle de cohérence de devise entre Travel, Booking, Flight et Supplement n'est implémentée.
- Aucune validation de capacité `occupiedSeats <= maximumSeats` n'est présente.

---

## 7. Functional Requirements

### FR-001 — Consulter la liste des voyages

**Description :** afficher les voyages avec agence, client, période, total, devise et statut.  
**Acteur :** Processor, Reviewer, Administrator.  
**Priorité :** Haute.  
**Préconditions :** utilisateur authentifié avec un rôle autorisé.  
**Entrées :** requête OData, filtres/tri/pagination Fiori.  
**Traitement :** lecture `Travels`, expansions à la demande, calcul de criticité après lecture.  
**Sorties :** collection de voyages.  
**Règles associées :** BR-012, SEC-002.  
**Écran :** UI-001.  
**API :** `GET /odata/v4/travel/Travels`.  
**Source :** `srv/travel-service.cds:5-7,26-27`; `app/travel/annotations.cds:9-22`.  
**Confiance : CONFIRMÉE.**

### FR-002 — Rechercher, filtrer et trier les voyages

**Description :** utiliser les capacités Fiori/OData serveur sur numéro, agence, client, statut et dates.  
**Acteur :** tous rôles métier.  
**Priorité :** Haute.  
**Préconditions :** accès lecture.  
**Entrées :** critères de filtre, `$filter`, `$orderby`, recherche si prise en charge par le template.  
**Traitement :** modèle OData en `operationMode: Server`.  
**Sorties :** liste restreinte.  
**Règles associées :** SEC-002.  
**Écran :** UI-001.  
**API :** OData V4 `Travels`.  
**Source :** `app/travel/annotations.cds:9`; `app/travel/webapp/manifest.json:41-45`.  
**Confiance : CONFIRMÉE pour les filtres ; FORTEMENT DÉDUITE pour la recherche libre.**

### FR-003 — Consulter le détail d'un voyage

**Description :** ouvrir une Object Page avec informations générales et réservations.  
**Acteur :** tous rôles métier.  
**Priorité :** Haute.  
**Préconditions :** voyage existant et droit READ.  
**Entrées :** clé OData du voyage.  
**Traitement :** navigation List Report → Object Page.  
**Sorties :** en-tête, champs généraux, table des réservations.  
**Règles associées :** BR-012.  
**Écran :** UI-002.  
**API :** `GET Travels(ID=...,IsActiveEntity=true)`.  
**Source :** `manifest.json:49-70`; `annotations.cds:3-31`.  
**Confiance : CONFIRMÉE.**

### FR-004 — Créer un voyage en draft

**Description :** créer un voyage avec édition transactionnelle draft.  
**Acteur :** Processor, Administrator.  
**Priorité :** Haute.  
**Préconditions :** rôle autorisé.  
**Entrées :** numéro, agence, client, dates, frais, devise, description.  
**Traitement :** création du draft CAP, validations à la sauvegarde/activation.  
**Sorties :** voyage actif au statut O par défaut.  
**Règles associées :** BR-001, BR-002, BR-003, BR-013.  
**Écran :** UI-002 en mode création.  
**API :** protocole draft OData V4 de `Travels`.  
**Source :** `srv/travel-service.cds:4-5,28`; `db/schema.cds:73-84`; `srv/travel-service.js:7-10,34-43`.  
**Confiance : CONFIRMÉE par le modèle ; création positive non couverte par test.**

### FR-005 — Modifier un voyage ouvert

**Description :** modifier les données d'un voyage tant qu'il est ouvert.  
**Acteur :** Processor, Administrator.  
**Préconditions :** statut O, rôle autorisé.  
**Entrées :** champs modifiables hors total en UI.  
**Traitement :** cycle draft, validation lors de l'activation.  
**Sorties :** voyage actif mis à jour.  
**Règles associées :** BR-001 à BR-003, BR-013.  
**Écran :** UI-002.  
**API :** draftEdit/PATCH/draftActivate.  
**Source :** `travel-service.cds:4,28`; `annotations.cds:47`; test `travel-service.test.js:27-43`.  
**Confiance : CONFIRMÉE.**

### FR-006 — Supprimer un voyage ouvert

**Description :** supprimer un voyage et, par composition, ses enfants.  
**Acteur :** Processor, Administrator.  
**Préconditions :** statut O.  
**Entrées :** ID Travel.  
**Traitement :** DELETE CAP soumis à `@restrict`; cascade de composition attendue du framework.  
**Sorties :** suppression du dossier.  
**Règles associées :** BR-013.  
**Écran :** UI-002, action standard Fiori déduite.  
**API :** DELETE OData Travel.  
**Source :** `travel-service.cds:28`; `schema.cds:84,96`.  
**Confiance : CONFIRMÉE pour le droit ; FORTEMENT DÉDUITE pour la cascade et le bouton UI, non testés.**

### FR-007 — Gérer les réservations

**Description :** consulter, créer, modifier et supprimer les réservations rattachées au voyage.  
**Acteur :** Processor/Administrator en écriture ; Reviewer en lecture.  
**Préconditions :** voyage ouvert pour la validation applicative quand `travel_ID` est fourni.  
**Entrées :** numéro/date/client/flight/prix/devise/statut.  
**Traitement :** CRUD CAP, contrôle prix/statut, recalcul du total.  
**Sorties :** réservation et total mis à jour.  
**Règles associées :** BR-004, BR-005, BR-009, SEC-003.  
**Écran :** table Réservations UI-002.  
**API :** entity set `Bookings` et navigation `Travels/bookings`.  
**Source :** `schema.cds:87-97`; `travel-service.cds:14,33-36`; `travel-service.js:12,26,45-55,103-120`.  
**Confiance : CONFIRMÉE par code ; non couverte par tests d'intégration.**

### FR-008 — Gérer les suppléments de réservation

**Description :** maintenir les postes de supplément d'une réservation.  
**Acteur :** Processor/Administrator en écriture ; Reviewer en lecture.  
**Préconditions :** réservation existante.  
**Entrées :** poste, supplément, prix/devise optionnellement déterminés.  
**Traitement :** validation/détermination puis recalcul du Travel.  
**Sorties :** poste et total mis à jour.  
**Règles associées :** BR-006, BR-007, BR-009, SEC-004.  
**Écran :** table Suppléments imbriquée.  
**API :** `BookingSupplements`/navigation.  
**Source :** `schema.cds:99-105`; `travel-service.js:13,27-32,57-68`; `annotations.cds:59-68`.  
**Confiance : CONFIRMÉE par code ; parcours UI complet HYPOTHÉTIQUE faute de route Booking dédiée.**

### FR-009 — Accepter un voyage

**Description :** passer un voyage ouvert à A.  
**Acteur :** Reviewer, Administrator par cumul de scope.  
**Préconditions :** voyage existant, statut O.  
**Entrées :** ID Travel.  
**Traitement :** action liée `accept`, contrôle statut, UPDATE.  
**Sorties :** Travel avec `status='A'`.  
**Règles associées :** BR-010, BR-011, SEC-005.  
**Écran :** UI-001/UI-002.  
**API :** `POST .../TravelService.accept`.  
**Source :** `travel-service.cds:9,29`; `travel-service.js:15,70-82`; tests lignes 46-68.  
**Confiance : CONFIRMÉE et testée.**

### FR-010 — Rejeter un voyage

Structure identique à FR-009, avec `status='X'`, action `rejectTravel`.  
**Source :** `travel-service.cds:10,29`; `travel-service.js:16,70-82`; test `travel-service.test.js:75-90`.  
**Confiance : CONFIRMÉE et testée.**

### FR-011 — Appliquer une remise

**Description :** diminuer le total courant d'un pourcentage strictement supérieur à 0 et inférieur ou égal à 100.  
**Acteur :** Processor, Administrator.  
**Préconditions :** voyage existant et ouvert.  
**Entrées :** `percent: Decimal(5,2)`.  
**Traitement :** `totalPrice × (1-percent/100)`, arrondi à 2 décimales.  
**Sorties :** voyage et total remisé.  
**Règles associées :** BR-008, BR-011.  
**Écran :** action Fiori « Appliquer une remise ».  
**API :** `TravelService.applyDiscount`.  
**Source :** `travel-service.cds:11,30`; `travel-service.js:85-100`; tests lignes 70-102.  
**Confiance : CONFIRMÉE et testée.**

### FR-012 — Recalculer le prix total

**Description :** recalculer `bookingFee + Σ flightPrice + Σ supplement.price`.  
**Acteur :** système, après mutation d'un Booking ou BookingSupplement.  
**Préconditions :** identifiant parent disponible.  
**Entrées :** Travel ID dérivé.  
**Traitement :** agrégation et arrondi 2 décimales.  
**Sorties :** `Travels.totalPrice`.  
**Règles associées :** BR-009.  
**Écran :** total en lecture seule.  
**API :** traitement interne, pas d'action publique dédiée.  
**Source :** `travel-service.js:26-32,103-120`; `annotations.cds:47`.  
**Confiance : CONFIRMÉE par code, non testée.**

### FR-013 — Utiliser des aides à la saisie agence/client

**Description :** fournir Value Help depuis `Agencies` et `Customers`.  
**Acteur :** Processor/Administrator en édition.  
**Source :** `annotations.cds:34-46`.  
**Confiance : CONFIRMÉE.**

### FR-014 — Consulter les référentiels

**Description :** lire Agencies, Customers, Airports, Carriers, Connections, Flights et Supplements sans mutation.  
**Acteur :** utilisateur authentifié ; restrictions spécifiques non ajoutées sur ces projections.  
**Source :** `travel-service.cds:17-23`; service global ligne 3.  
**Confiance : CONFIRMÉE.**

### FR-015 — Afficher la criticité du statut

**Description :** mapper A→3, X→1, O/autre→2 pour le rendu Fiori.  
**Acteur :** tout lecteur.  
**Source :** `travel-service.cds:7`; `travel-service.js:18-24`; `annotations.cds:18`.  
**Confiance : CONFIRMÉE.**

### FR-016 — Exposer la santé technique

**Description :** répondre `200 {status:'UP'}` sur `/health`.  
**Acteur :** supervision.  
**Source :** `server.js:3-5`; test `travel-service.test.js:8-12`.  
**Confiance : CONFIRMÉE et testée.**

---

## 8. Use Cases

## UC-001 — Consulter et filtrer les voyages

**Acteur :** Processor, Reviewer, Administrator.  
**Objectif :** trouver et examiner des dossiers de voyage.  
**Préconditions :** authentification et rôle avec READ.  
**Déclencheur :** ouverture de l'application.

**Scénario nominal**

1. Le système ouvre le List Report `Travels`.
2. L'acteur saisit des filtres parmi numéro, agence, client, statut, début et fin.
3. Fiori envoie la requête OData au serveur.
4. Le service retourne les lignes autorisées et la criticité calculée.
5. L'acteur ouvre éventuellement la fiche détaillée.

**Scénarios alternatifs :** tri, pagination, variante de page.  
**Exceptions :** utilisateur sans rôle → accès non accordé par `@restrict`.  
**Postconditions :** aucune mutation.  
**Entités utilisées :** Travels, Agencies, Customers.  
**Règles métier :** BR-012.  
**Écrans :** UI-001, UI-002.  
**Services/API :** TravelService/Travels READ.  
**Sources :** `manifest.json:47-70`; `annotations.cds:9-22`; `travel-service.cds:27`.

## UC-002 — Créer un voyage

**Acteur :** Processor, Administrator.  
**Objectif :** enregistrer un nouveau dossier.  
**Préconditions :** rôle d'écriture.  
**Déclencheur :** action standard Créer du List Report.

**Scénario nominal**

1. Fiori crée un draft.
2. L'acteur saisit numéro, agence, client, période, frais, devise et description.
3. Le système initialise le statut à O et les montants à 0 si absents.
4. À l'activation, les validations de date et montant sont exécutées.
5. Le draft est activé.

**Alternatives :** abandon du draft.  
**Exceptions :** fin avant début ou montant négatif → HTTP 400.  
**Postconditions :** Travel actif ouvert.  
**Entités :** Travels, Agencies, Customers.  
**Règles :** BR-001 à BR-003.  
**Écran :** UI-002.  
**API :** draft New/PATCH/Activate.  
**Sources :** `travel-service.cds:4-5,28`; `travel-service.js:7-10,34-43`.

## UC-003 — Modifier ou supprimer un voyage ouvert

**Acteur :** Processor, Administrator.  
**Objectif :** corriger un dossier non finalisé.  
**Préconditions :** statut O.  
**Déclencheur :** Edit ou Delete.

**Scénario nominal :** création d'un draft d'édition, modification, validation, activation ; ou DELETE.  
**Exceptions :** statut non O → restriction/refus ; dates/montants invalides → 400.  
**Postconditions :** dossier mis à jour ou supprimé.  
**Sources :** `travel-service.cds:28`; test draft lignes 27-43.

## UC-004 — Gérer une réservation

**Acteur :** Processor, Administrator.  
**Objectif :** ajouter/modifier/supprimer un vol réservé.  
**Préconditions :** voyage ouvert.  
**Déclencheur :** interaction avec la section Réservations.

**Scénario nominal**

1. L'acteur saisit les données de réservation et le vol.
2. Le système vérifie que `flightPrice >= 0`.
3. Si `travel_ID` est transmis, le système vérifie le statut O.
4. La réservation est persistée.
5. Le total Travel est recalculé.

**Exceptions :** prix négatif → 400 ; voyage non ouvert → 409.  
**Entités :** Travel, Booking, Customer, Flight.  
**Règles :** BR-004, BR-005, BR-009.  
**Écran :** section Réservations.  
**API :** Bookings CRUD/navigation.  
**Sources :** `travel-service.js:12,26,45-55,103-120`.

## UC-005 — Ajouter un supplément

**Acteur :** Processor, Administrator.  
**Objectif :** facturer une prestation additionnelle.  
**Préconditions :** Booking existant.  
**Scénario nominal :** choisir Supplement ; si prix omis, copier prix/devise catalogue ; persister ; recalculer Travel.  
**Exception :** prix négatif → 400.  
**Entités :** BookingSupplement, Supplement, Booking, Travel.  
**Règles :** BR-006, BR-007, BR-009.  
**Sources :** `travel-service.js:27-32,57-68`.

## UC-006 — Accepter un voyage

**Acteur :** Reviewer, Administrator.  
**Objectif :** marquer le dossier accepté.  
**Préconditions :** voyage existant et O.  
**Scénario nominal :** sélectionner, exécuter Accepter, contrôler rôle/statut, passer à A, retourner le dossier.  
**Exceptions :** sans rôle → 403 ; absent → 404 ; non ouvert → 409.  
**Postconditions :** statut A ; CRUD Processor bloqué.  
**Sources :** `travel-service.js:15,70-82`; tests lignes 46-68.

## UC-007 — Rejeter un voyage

Identique à UC-006, avec action Rejeter et état final X.  
**Sources :** `travel-service.js:16,70-82`; test lignes 75-90.

## UC-008 — Appliquer une remise

**Acteur :** Processor, Administrator.  
**Objectif :** diminuer le total d'un voyage ouvert.  
**Préconditions :** Travel O.  
**Scénario nominal :** saisir pourcentage ; valider `(0,100]` ; calculer/arrondir ; mettre à jour.  
**Exceptions :** borne invalide 400 ; absent 404 ; statut non O 409.  
**Sources :** `travel-service.js:85-100`; tests lignes 70-102.

## UC-009 — Consulter les référentiels

**Acteur :** utilisateur authentifié.  
**Objectif :** alimenter affichages et Value Helps.  
**Préconditions :** authentification.  
**Postconditions :** aucune mutation.  
**Sources :** `travel-service.cds:17-23`; `annotations.cds:34-46`.

## UC-010 — Superviser l'application

**Acteur :** plateforme/DevOps.  
**Objectif :** vérifier que le serveur répond.  
**Scénario :** GET `/health` → 200/UP.  
**Source :** `server.js:3-5`; test lignes 8-12.

---

## 9. Business Rules

### BR-001 — Cohérence de période

**Description :** la fin ne peut précéder le début.  
**Déclencheur :** CREATE/UPDATE/PATCH/SAVE Travel, notamment activation draft.  
**Condition :** les deux dates existent et `endDate < beginDate`.  
**Traitement/Résultat :** erreur HTTP 400 ciblée sur `endDate`.  
**Message :** « La date de fin doit être postérieure ou égale à la date de début ».  
**Entités :** Travel.  
**Implémentation/source :** `travel-service.js:7-10,34-37`.  
**Niveau : CONFIRMÉE et testée** (`test:21-43`).

### BR-002 — Frais de réservation non négatifs

Condition `bookingFee < 0` → HTTP 400, message dynamique « bookingFee ne peut pas être négatif ».  
**Source :** `travel-service.js:38-41`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-003 — Total non négatif à l'entrée

Condition `totalPrice < 0` → HTTP 400. Le champ est toutefois readonly dans l'UI.  
**Source :** `travel-service.js:38-41`; `annotations.cds:47`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-004 — Prix de vol non négatif

Condition `flightPrice < 0` → 400 « Le prix du vol ne peut pas être négatif ».  
**Source :** `travel-service.js:45-48`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-005 — Réservation modifiable seulement sur voyage ouvert

Si `travel_ID` est présent et le parent n'est pas O → 409.  
**Message :** « Les réservations ne sont modifiables que pour un voyage ouvert ».  
**Source :** `travel-service.js:49-54`.  
**Niveau : CONFIRMÉE, couverture partielle : la condition dépend de la présence du FK dans la charge utile.**

### BR-006 — Prix de supplément non négatif

Condition `price < 0` → 400.  
**Source :** `travel-service.js:57-60`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-007 — Détermination du prix du supplément

Si `supplement_ID` est fourni et `price` absent, copier `Supplement.price` et `currency`. Si le Supplement n'est pas trouvé, aucune erreur explicite n'est émise par le handler.  
**Source :** `travel-service.js:61-67`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-008 — Bornes de remise

Le pourcentage doit être numérique, `> 0` et `<= 100`; sinon 400 « La remise doit être comprise entre 0 et 100 ».  
**Source :** `travel-service.js:85-90`.  
**Niveau : CONFIRMÉE et testée à 101.**

### BR-009 — Calcul du total

`totalPrice = round2(bookingFee + Σ Booking.flightPrice + Σ BookingSupplement.price)`. Déclenchement après CREATE/UPDATE/DELETE de Booking ou BookingSupplement.  
**Source :** `travel-service.js:26-32,103-120`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-010 — Transition de statut uniquement depuis O

Accept/reject refusent tout Travel non ouvert avec 409 « Seul un voyage ouvert peut changer de statut ».  
**Source :** `travel-service.js:70-82`.  
**Niveau : CONFIRMÉE, transition positive testée ; refus non testé.**

### BR-011 — Remise seulement sur voyage ouvert

Après validation du pourcentage et existence, un statut autre que O produit 409.  
**Source :** `travel-service.js:91-97`.  
**Niveau : CONFIRMÉE, non testée.**

### BR-012 — Criticité Fiori du statut

A→3 (positive), X→1 (negative), autre/O→2 (criticality intermédiaire).  
**Source :** `travel-service.js:18-24`; `annotations.cds:18`.  
**Niveau : CONFIRMÉE, non testée explicitement.**

### BR-013 — CRUD Travel limité aux ouverts

CREATE/UPDATE/DELETE accordés au Processor/Admin avec condition `status='O'`. READ séparé.  
**Source :** `travel-service.cds:26-31`.  
**Niveau : CONFIRMÉE.**

### BR-014 — Référentiels immuables via TravelService

Les sept projections référentielles sont `@readonly`.  
**Source :** `travel-service.cds:17-23`.  
**Niveau : CONFIRMÉE.**

### BR-015 — Valeurs initiales

Travel.status=O, Booking.status=N, bookingFee/totalPrice/flightPrice/prix supplément=0, occupiedSeats=0.  
**Source :** `common.cds:6-15`; `schema.cds:62,79-83,93-95,103`.  
**Niveau : CONFIRMÉE.**

### BR-016 — Arrondi financier

Remise et recalcul arrondissent à deux décimales par `Math.round(value*100)/100`.  
**Source :** `travel-service.js:98,118-120`.  
**Niveau : CONFIRMÉE.**

### BR-017 — Suppression/absence silencieuse lors du recalcul

Sans Travel ID ou si Travel absent, le recalcul s'arrête sans erreur.  
**Source :** `travel-service.js:103-110`.  
**Niveau : CONFIRMÉE.**

---

## 10. State Machines

### 10.1 Travel

```text
                 accept [Reviewer]
              ┌────────────────────> A (Accepted)
              |
O (Open) ─────┤
              |
              └────────────────────> X (Rejected)
               rejectTravel [Reviewer]
```

| État initial | Action         | Acteur         | Conditions    | État final | Implémentation               |
| ------------ | -------------- | -------------- | ------------- | ---------- | ---------------------------- |
| O            | `accept`       | Reviewer/Admin | existant et O | A          | `travel-service.js:15,70-82` |
| O            | `rejectTravel` | Reviewer/Admin | existant et O | X          | `travel-service.js:16,70-82` |

Aucune transition depuis A ou X et aucun retour à O ne sont implémentés. Toute tentative des deux actions depuis A/X produit 409.

### 10.2 Booking

Les valeurs N (new), B (booked), X (cancelled) sont **CONFIRMÉES** dans le type (`common.cds:11-15`), mais aucune action ni règle de transition n'existe. Une machine à états Booking serait donc une **HYPOTHÈSE interdite à formaliser davantage** sans validation fonctionnelle.

### 10.3 Draft technique

```text
Active Travel ──draftEdit──> Draft ──PATCH──> Draft ──draftActivate──> Active Travel
                                  └──────────── DELETE/Cancel ───────> Active inchangé
```

Ce cycle est technique CAP/Fiori et confirmé par `@odata.draft.enabled` et le test lignes 21-43.

---

## 11. User Interface Specifications

### UI-001 — Liste des voyages

**Type :** Fiori Elements List Report.  
**Objectif :** rechercher, consulter et déclencher les principales actions Travel.  
**Entité principale :** `/Travels`.  
**Zones :** Filter Bar, table, gestion de variante au niveau page.  
**Filtres :** travelNumber, agency_ID, customer_ID, status, beginDate, endDate.  
**Colonnes :** numéro, agence, nom client, début, fin, prix total, devise, statut.  
**Actions :** Accepter, Rejeter, Appliquer une remise ; actions standard draft/CRUD selon métadonnées et autorisations.  
**Navigation :** sélection Travel → UI-002.  
**Validations :** remontées OData ; validation métier surtout à l'activation du draft.  
**Visibilité conditionnelle :** criticité du statut ; aucune annotation explicite `UI.Hidden` ou `OperationAvailable` sur les actions.  
**Autorisations :** contrôlées côté service ; la visibilité proactive par rôle n'est pas configurée explicitement.  
**Sources :** `manifest.json:47-65`; `annotations.cds:3-22`.

### UI-002 — Fiche voyage

**Type :** Fiori Elements Object Page.  
**Objectif :** consulter/éditer un voyage et ses réservations.  
**Entité :** Travels.  
**En-tête :** titre numéro Travel, description.  
**Section Informations générales :** numéro, agence, client, dates, frais, total, devise, statut, description.  
**Section Réservations :** table avec numéro, date, connexion/vol, prix, devise, statut.  
**Sous-structure Suppléments :** facet déclarée sur Booking ; table poste, supplément, prix, devise.  
**Aides à la saisie :** Agency et Customer.  
**Champs readonly :** totalPrice.  
**Navigation :** aucune route explicite Booking Object Page dans le manifest.  
**Validations :** dates/montants côté service.  
**Sources :** `manifest.json:66-71`; `annotations.cds:23-68`.

### 11.1 Limites UI observées

- Aucun contrôleur custom, extension fragment ou formatter métier : seulement `AppComponent` standard.
- Aucun `OperationAvailable` ne désactive explicitement accept/reject/discount selon le statut ; le backend reste l'autorité.
- La facet Supplements est déclarée sur Booking, mais l'absence de cible/route Object Page Booking rend son accès exact **HYPOTHÉTIQUE**.
- Les entités de référence n'ont aucun écran principal.

---

## 12. Navigation

```text
Launchpad intent: #Travel-manage
        |
        v
Travel List Report (TravelsList)
        |
        +── sélectionner Travel
                |
                v
        Travel Object Page
                |
                +── Informations générales
                |
                └── Bookings [table 0..n]
                         |
                         └── Supplements [facet annotée, accès exact à valider]
```

**Source :** intent `manifest.json:17-24`, routes `49-71`, facets `annotations.cds:23-25,59-68`.

---

## 13. Services & APIs

### 13.1 TravelService

| Propriété        | Valeur                                             |
| ---------------- | -------------------------------------------------- |
| Nom              | `TravelService`                                    |
| Technologie      | SAP CAP Node.js ApplicationService                 |
| Protocole        | OData V4                                           |
| URL              | `/odata/v4/travel/` dérivée du nom                 |
| Authentification | `authenticated-user`; mock local, XSUAA production |
| Consommateur     | Fiori Elements `sflight.travel`                    |
| Draft            | Travels et compositions                            |

### 13.2 Matrice CRUD

| Service       | Entity             |        READ |   CREATE |   UPDATE |   DELETE | Actions                            |
| ------------- | ------------------ | ----------: | -------: | -------: | -------: | ---------------------------------- |
| TravelService | Travels            |       P/R/A | P/A si O | P/A si O | P/A si O | accept/reject: R/A ; discount: P/A |
| TravelService | Bookings           |       P/R/A |      P/A |      P/A |      P/A | aucune explicite                   |
| TravelService | BookingSupplements |       P/R/A |      P/A |      P/A |      P/A | aucune explicite                   |
| TravelService | Agencies           | authentifié |      non |      non |      non | aucune                             |
| TravelService | Customers          | authentifié |      non |      non |      non | aucune                             |
| TravelService | Airports           | authentifié |      non |      non |      non | aucune                             |
| TravelService | Carriers           | authentifié |      non |      non |      non | aucune                             |
| TravelService | Connections        | authentifié |      non |      non |      non | aucune                             |
| TravelService | Flights            | authentifié |      non |      non |      non | aucune                             |
| TravelService | Supplements        | authentifié |      non |      non |      non | aucune                             |

P=TravelProcessor, R=TravelReviewer, A=Administrator. Pour les référentiels, seule l'exigence globale d'authentification est explicitement observée.

### 13.3 Actions explicites

| Action          | Entité  | Paramètre            | Conditions                    | Résultat              | Autorisation    | Source                                 |
| --------------- | ------- | -------------------- | ----------------------------- | --------------------- | --------------- | -------------------------------------- |
| `accept`        | Travels | aucun                | existe, status O              | status A + Travel     | Reviewer/Admin  | `travel-service.cds:9,29`; JS 15,70-82 |
| `rejectTravel`  | Travels | aucun                | existe, status O              | status X + Travel     | Reviewer/Admin  | CDS 10,29 ; JS 16,70-82                |
| `applyDiscount` | Travels | percent Decimal(5,2) | numérique, ]0,100], existe, O | total remisé + Travel | Processor/Admin | CDS 11,30 ; JS 17,85-100               |

### 13.4 Associations navigables

Le service projette les associations du modèle : Travel→Agency/Customer/Bookings ; Booking→Travel/Customer/Flight/Supplements ; Flight→Connection ; Connection→Carrier/Airports/Flights. Leur navigabilité OData est **CONFIRMÉE par projection `*`/projection simple**, sous réserve des règles CAP générées.

### 13.5 API technique additionnelle

`GET /health` est une route Express hors OData, sans exigence d'authentification explicite dans `server.js`.

---

## 14. Security & Roles

### SEC-001 — Authentification du service

TravelService exige `authenticated-user`. Local : mocked auth ; production : XSUAA.  
**Source :** `travel-service.cds:3`; `package.json:70-78`.  
**Confiance : CONFIRMÉE.**

### SEC-002 — Lecture métier

READ Travel/Booking/BookingSupplement accordé uniquement à P/R/A.  
**Source :** `travel-service.cds:26-40`.  
**Confiance : CONFIRMÉE.**

### SEC-003 — Écriture métier

P/A gèrent les Travels ouverts et les enfants ; Reviewer lecture seule.  
**Source :** `travel-service.cds:28,35,40`.  
**Confiance : CONFIRMÉE.**

### SEC-004 — Séparation des tâches

Processor applique la remise ; Reviewer accepte/rejette. Le test confirme qu'un Processor ne peut accepter.  
**Source :** `travel-service.cds:29-30`; test lignes 58-68.  
**Confiance : CONFIRMÉE et partiellement testée.**

### SEC-005 — Routage sécurisé BTP

AppRouter utilise XSUAA et transfère le token à `srv-api`.  
**Source :** `xs-app.json:3-17`; `mta.yaml:25-33`.  
**Confiance : CONFIRMÉE.**

### 14.1 Point de vigilance CSRF

La route OData de l'AppRouter déclare `csrfProtection: false` (`xs-app.json:10`). Cela désactive la protection AppRouter sur cette route. CAP/OData peut gérer ses propres tokens selon le contexte, mais la défense effective n'est pas démontrée par les tests. **Validation sécurité requise.**

---

## 15. Architecture

```text
SAP Fiori Elements / SAPUI5
app/travel/webapp + annotations.cds
                |
                v
SAP AppRouter + XSUAA + HTML5 Apps Repository
app/router/xs-app.json, xs-security.json
                |
                v
OData V4 TravelService (CAP)
srv/travel-service.cds
                |
                v
Handlers métier CAP Node.js
srv/travel-service.js
                |
                v
Modèle de domaine CDS
db/common.cds + db/schema.cds
                |
       +--------+---------+
       |                  |
SQLite développement   SAP HANA/HDI production
package.json           mta.yaml/gen/db
```

### 15.1 Mapping des couches

| Couche             | Responsabilité                            | Fichiers                                    |
| ------------------ | ----------------------------------------- | ------------------------------------------- |
| Présentation       | List Report/Object Page, i18n, navigation | `app/travel/webapp/*`                       |
| Métadonnées UI     | champs, facets, actions, Value Helps      | `app/travel/annotations.cds`                |
| Routage            | protection et routage UI/OData            | `app/router/xs-app.json`                    |
| Contrat de service | projections, draft, actions, restrictions | `srv/travel-service.cds`                    |
| Domaine métier     | validations, calculs, transitions         | `srv/travel-service.js`                     |
| Persistance        | entités, types, associations              | `db/*.cds`                                  |
| Données initiales  | jeux de démonstration                     | `db/data/*.csv`                             |
| Sécurité           | scopes et role templates                  | `xs-security.json`, `.cdsrc.json`           |
| Déploiement        | modules CF, HDI, XSUAA, HTML5 repo        | `mta.yaml`                                  |
| Qualité/SDLC       | tests, CI, sécurité, release              | `test`, `.github/workflows`, `package.json` |

### 15.2 Cartographie du repository

| Répertoire/fichier  | Responsabilité                           | Contenu                                            | Couche              | Fonctionnalités                            |
| ------------------- | ---------------------------------------- | -------------------------------------------------- | ------------------- | ------------------------------------------ |
| `db/`               | modèle persistant                        | CDS + 10 CSV                                       | Data/Domain         | toutes entités et données de démonstration |
| `srv/`              | exposition et comportements              | service CDS + handler JS                           | Service/Application | CRUD, actions, règles, calculs             |
| `app/travel/`       | client Fiori Elements                    | manifest, Component, annotations, i18n, UI5 config | Présentation        | liste/fiche voyages                        |
| `app/router/`       | entrée BTP sécurisée                     | AppRouter package + routes                         | Edge/Security       | XSUAA, proxy OData, HTML5 repo             |
| `test/integration/` | spécification exécutable                 | Jest + cds.test                                    | Quality             | 7 comportements                            |
| `.github/`          | gouvernance SDLC                         | CI, security, release, deploy, templates           | DevOps              | gates et promotion                         |
| `docs/`             | architecture/exploitation/spécifications | ADR, runbook, SDLC, SRS                            | Documentation       | compréhension et exploitation              |
| `package.json`      | runtime/outillage/profiles               | CAP, SQLite/HANA, scripts                          | Configuration       | build/test/run                             |
| `mta.yaml`          | livraison BTP                            | AppRouter, srv, db deployer, UI content, services  | Deployment          | CF/HANA/XSUAA/HTML5                        |
| `xs-security.json`  | modèle d'autorisation                    | scopes et templates                                | Security            | trois rôles                                |
| `server.js`         | extension bootstrap                      | health endpoint                                    | Runtime             | supervision                                |

---

## 16. Non-Functional Requirements

| ID      | Statut      | Exigence démontrable                                                                 | Preuve                                |
| ------- | ----------- | ------------------------------------------------------------------------------------ | ------------------------------------- |
| NFR-001 | **OBSERVÉ** | Node.js >=22                                                                         | `package.json:6-8`                    |
| NFR-002 | **OBSERVÉ** | OData V4 et Fiori Elements UI5 >=1.120                                               | `manifest.json:12-14,33-34`           |
| NFR-003 | **OBSERVÉ** | SQLite en développement, HANA en production                                          | `package.json:62-78`                  |
| NFR-004 | **OBSERVÉ** | XSUAA en production, authentification mockée en local                                | mêmes sources + `.cdsrc.json`         |
| NFR-005 | **OBSERVÉ** | Déploiement Cloud Foundry MTA, HDI shared, HTML5 repository                          | `mta.yaml:16-104`                     |
| NFR-006 | **OBSERVÉ** | Santé HTTP simple                                                                    | `server.js:3-5`                       |
| NFR-007 | **OBSERVÉ** | Tests Jest avec seuils 45% statements/lines, 25% branches, 50% fonctions             | `package.json:45-60`                  |
| NFR-008 | **OBSERVÉ** | CI : format/lint/test/build ; sécurité : audit/CodeQL/dependency review              | `.github/workflows/*.yml`             |
| NFR-009 | **OBSERVÉ** | Build release MTAR, SBOM et attestation                                              | `.github/workflows/release.yml`       |
| NFR-010 | **DÉDUIT**  | Adaptation desktop/tablet/mobile                                                     | `manifest.json:27-30`                 |
| NFR-011 | **OBSERVÉ** | Requêtes OData en mode serveur et autoExpandSelect                                   | `manifest.json:41-45`                 |
| NFR-012 | **DÉDUIT**  | Aucune exigence chiffrée de performance, volumétrie ou disponibilité n'est démontrée | absence de configuration/tests dédiés |

### 16.1 Observabilité

Seul `/health` est instrumenté. Aucun export OpenTelemetry, métrique, alerte, tracing distribué ou service SAP Application Logging n'est configuré explicitement. Les logs CAP standards sont disponibles ; les objectifs SLO/SLA sont absents.

### 16.2 Compatibilité et cloud

Le MTA utilise `nodejs_buildpack`, un conteneur HDI `hdi-shared`, XSUAA application, HTML5 app-host/app-runtime et AppRouter. Le mode tenant XSUAA est `dedicated`; il ne s'agit pas d'une application SaaS multitenant.

---

## 17. BDD Scenarios

```gherkin
Feature: Consultation des voyages

  Scenario: Un gestionnaire consulte les voyages avec leurs références
    Given un utilisateur avec le rôle TravelProcessor
    And des voyages existent
    When il lit Travels avec Agency et Customer
    Then le service répond 200
    And au moins un voyage est retourné
    And le nom de l'agence est disponible
```

```gherkin
Feature: Validation des dates d'un voyage

  Scenario: Refuser l'activation d'un brouillon dont la fin précède le début
    Given un voyage ouvert
    And un TravelProcessor a créé un brouillon d'édition
    When il fixe le début au 10 octobre et la fin au 1er octobre
    And il active le brouillon
    Then le service répond 400
    And le message cible endDate
```

```gherkin
Feature: Décision sur un voyage

  Scenario: Un reviewer accepte un voyage ouvert
    Given un voyage au statut O
    And un utilisateur TravelReviewer
    When il exécute l'action accept
    Then le statut devient A

  Scenario: Un processor ne peut pas accepter un voyage
    Given un voyage au statut O
    And un utilisateur TravelProcessor sans rôle Reviewer
    When il exécute l'action accept
    Then le service répond 403

  Scenario: Un reviewer rejette un voyage ouvert
    Given un voyage au statut O
    And un utilisateur TravelReviewer
    When il exécute rejectTravel
    Then le statut devient X
```

```gherkin
Feature: Remise sur un voyage

  Scenario: Appliquer dix pour cent de remise
    Given un voyage ouvert dont le total est 100 EUR
    And un TravelProcessor
    When il applique une remise de 10
    Then le total devient 90 EUR

  Scenario: Refuser une remise supérieure à cent pour cent
    Given un TravelProcessor
    When il demande une remise de 101
    Then le service répond 400
```

```gherkin
Feature: Calcul du prix total

  Scenario: Recalculer après ajout d'un supplément
    Given un voyage avec des frais de réservation
    And une réservation de vol
    When un supplément est ajouté
    Then le total vaut les frais plus tous les prix de vols plus tous les suppléments
    And le total est arrondi à deux décimales
```

Ce dernier scénario est dérivé du code mais n'est pas encore matérialisé dans les tests Jest.

```gherkin
Feature: Santé technique

  Scenario: Vérifier que le serveur répond
    When la supervision appelle GET /health
    Then la réponse HTTP est 200
    And le corps vaut {"status":"UP"}
```

---

## 18. Requirements Traceability Matrix

| Requirement | Description                 | Type             | Source                                        | Composant                 |
| ----------- | --------------------------- | ---------------- | --------------------------------------------- | ------------------------- |
| FR-001      | Lire les voyages            | Fonctionnel      | `srv/travel-service.cds:5-7,27`               | TravelService             |
| FR-002      | Filtrer les voyages         | Fonctionnel      | `annotations.cds:9`; `manifest.json:44`       | Fiori/OData               |
| FR-003      | Ouvrir la fiche             | Fonctionnel/UI   | `manifest.json:49-70`                         | Fiori routing             |
| FR-004      | Créer en draft              | Fonctionnel      | `travel-service.cds:4`; `schema.cds:73-84`    | CAP Draft                 |
| FR-005      | Modifier un voyage ouvert   | Fonctionnel      | `travel-service.cds:28`; test `21-43`         | CAP Draft                 |
| FR-006      | Supprimer un voyage ouvert  | Fonctionnel      | `travel-service.cds:28`                       | OData CRUD                |
| FR-007      | Gérer Booking               | Fonctionnel      | `schema.cds:87-97`; JS `45-55`                | Booking                   |
| FR-008      | Gérer BookingSupplement     | Fonctionnel      | `schema.cds:99-105`; JS `57-68`               | Supplement                |
| FR-009      | Accepter                    | Fonctionnel      | CDS `9,29`; JS `15,70-82`; test `46-56`       | Action accept             |
| FR-010      | Rejeter                     | Fonctionnel      | CDS `10,29`; JS `16,70-82`; test `75-90`      | Action rejectTravel       |
| FR-011      | Remise                      | Fonctionnel      | CDS `11,30`; JS `85-100`; test `70-102`       | applyDiscount             |
| FR-012      | Recalculer total            | Fonctionnel      | JS `26-32,103-120`                            | Pricing                   |
| FR-013      | Value Helps                 | UI               | `annotations.cds:34-46`                       | Fiori annotations         |
| FR-014      | Lire référentiels           | Fonctionnel      | `travel-service.cds:17-23`                    | Readonly projections      |
| FR-015      | Criticité statut            | UI               | JS `18-24`; annotations `18`                  | Status display            |
| FR-016      | Santé                       | Technique        | `server.js:3-5`; test `8-12`                  | Express                   |
| BR-001      | Dates cohérentes            | Business Rule    | JS `34-37`; test `21-43`                      | validateTravel            |
| BR-002      | bookingFee >= 0             | Business Rule    | JS `38-41`                                    | validateTravel            |
| BR-003      | totalPrice >= 0             | Business Rule    | JS `38-41`                                    | validateTravel            |
| BR-004      | flightPrice >= 0            | Business Rule    | JS `45-48`                                    | validateBooking           |
| BR-005      | Booking seulement Travel O  | Business Rule    | JS `49-54`                                    | validateBooking           |
| BR-006      | Supplement price >= 0       | Business Rule    | JS `57-60`                                    | validateBookingSupplement |
| BR-007      | Détermination supplément    | Business Rule    | JS `61-67`                                    | validateBookingSupplement |
| BR-008      | Remise ]0,100]              | Business Rule    | JS `85-90`; test `93-102`                     | applyDiscount             |
| BR-009      | Formule total               | Business Rule    | JS `103-120`                                  | recalculateTravel         |
| BR-010      | Transition depuis O         | Business Rule    | JS `70-82`                                    | setStatus                 |
| BR-011      | Remise seulement O          | Business Rule    | JS `95-97`                                    | applyDiscount             |
| BR-012      | Criticité                   | Business Rule/UI | JS `18-24`                                    | READ handler              |
| BR-013      | CRUD Travel ouvert          | Authorization    | CDS `26-31`                                   | @restrict                 |
| BR-014      | Référentiels readonly       | Business Rule    | CDS `17-23`                                   | Projections               |
| UI-001      | List Report                 | Interface        | `manifest.json:50,54-65`; annotations `9-22`  | Fiori Elements            |
| UI-002      | Object Page                 | Interface        | `manifest.json:51,66-71`; annotations `23-68` | Fiori Elements            |
| SEC-001     | Authentification            | Sécurité         | CDS `3`; package `70-78`                      | CAP/XSUAA                 |
| SEC-002     | READ P/R/A                  | Sécurité         | CDS `27,34,39`                                | @restrict                 |
| SEC-003     | WRITE P/A                   | Sécurité         | CDS `28,35,40`                                | @restrict                 |
| SEC-004     | Séparation décisions/remise | Sécurité         | CDS `29-30`; test `58-68`                     | Actions                   |
| SEC-005     | AppRouter XSUAA             | Sécurité         | `xs-app.json:3-17`; MTA `25-33`               | BTP edge                  |
| NFR-001     | Node >=22                   | Non fonctionnel  | `package.json:6-8`                            | Runtime                   |
| NFR-003     | SQLite/HANA                 | Non fonctionnel  | `package.json:62-78`                          | Persistence               |
| NFR-005     | Déploiement MTA             | Non fonctionnel  | `mta.yaml:16-104`                             | BTP                       |
| NFR-007     | Couverture                  | Non fonctionnel  | `package.json:45-60`                          | Jest                      |

### 18.1 Tests comme spécification

| Test            | Précondition         | Action                      | Attendu                  | Requirement | Rule       | Implementation      |
| --------------- | -------------------- | --------------------------- | ------------------------ | ----------- | ---------- | ------------------- |
| Santé           | serveur démarré      | GET `/health`               | 200/UP                   | FR-016      | —          | `server.js:3-5`     |
| Lecture Travel  | Processor + données  | GET expand agency/customer  | collection + agency.name | FR-001      | SEC-002    | projection/read     |
| Dates draft     | Travel O + Processor | edit, patch dates, activate | 400                      | FR-005      | BR-001     | validateTravel      |
| Acceptation     | Travel O + Reviewer  | accept                      | status A                 | FR-009      | BR-010     | setStatus           |
| Refus Processor | Travel O + Processor | accept                      | 403                      | FR-009      | SEC-004    | @requires/@restrict |
| Remise + rejet  | Travel O total 100   | remise 10 puis rejet        | 90 puis X                | FR-010/011  | BR-008/010 | handlers actions    |
| Remise invalide | percent 101          | applyDiscount               | 400                      | FR-011      | BR-008     | applyDiscount       |

```text
test/integration/travel-service.test.js
          ↓
FR-001, FR-005, FR-009, FR-010, FR-011, FR-016
          ↓
BR-001, BR-008, BR-010, SEC-004
          ↓
srv/travel-service.cds + srv/travel-service.js + server.js
```

---

## 19. Glossary

| Terme              | Définition                                       | Objet technique associé                    |
| ------------------ | ------------------------------------------------ | ------------------------------------------ |
| Travel             | Dossier de voyage agrégateur                     | `sflight.Travels`, `TravelService.Travels` |
| Booking            | Réservation d'un vol                             | `sflight.Bookings`                         |
| Booking Supplement | Poste de prestation additionnelle                | `sflight.BookingSupplements`               |
| Customer           | Client lié au voyage/réservation                 | `sflight.Customers`                        |
| Agency             | Agence organisatrice                             | `sflight.Agencies`                         |
| Carrier            | Compagnie aérienne                               | `sflight.Carriers`                         |
| Connection         | Liaison entre aéroports                          | `sflight.Connections`                      |
| Flight             | Occurrence datée d'une connexion                 | `sflight.Flights`                          |
| Airport            | Aéroport de départ/destination                   | `sflight.Airports`                         |
| Supplement         | Catalogue des prestations                        | `sflight.Supplements`                      |
| Draft              | Copie transactionnelle éditable avant activation | `@odata.draft.enabled`                     |
| Open               | Voyage modifiable, code O                        | `TravelStatus.open`                        |
| Accepted           | Voyage accepté, code A                           | `TravelStatus.accepted`                    |
| Rejected           | Voyage rejeté, code X                            | `TravelStatus.rejected`                    |
| TravelProcessor    | Gestionnaire de voyages                          | scope/role template XSUAA                  |
| TravelReviewer     | Validateur de voyages                            | scope/role template XSUAA                  |
| MTAR               | Archive de déploiement multi-target BTP          | `mta.yaml`                                 |
| HDI                | Conteneur de persistance SAP HANA                | `sflight-cap-db`                           |

---

## 20. Open Questions

### 20.1 Questions fonctionnelles à valider avec un consultant SAP

1. Le statut O signifie-t-il « Open », « New » ou « Processing » dans le vocabulaire métier cible ?
2. L'acceptation/rejet est-elle irréversible ? Faut-il une action de réouverture ?
3. Une justification/commentaire est-il obligatoire lors d'un rejet ? Aucun champ ne l'enregistre.
4. La remise doit-elle porter sur le total complet, seulement les vols, ou uniquement les frais ? Le code remise le total courant.
5. Une remise doit-elle être mémorisée (taux, montant, auteur, date) ? Le code ne conserve que le nouveau total.
6. Un recalcul ultérieur doit-il écraser une remise ? Actuellement, une mutation Booking/Supplement recalcule depuis les composants et peut donc annuler implicitement la remise.
7. Les devises Travel/Booking/Flight/Supplement doivent-elles être identiques ou converties ? Aucune conversion n'existe.
8. Les numéros Booking et Item doivent-ils être uniques dans leur parent ?
9. Les statuts Booking N/B/X ont-ils des transitions et acteurs définis ?
10. Faut-il contrôler capacité du vol, dates de vol dans la période Travel, et cohérence client Travel/Booking ?
11. La suppression d'un Travel doit-elle cascader fonctionnellement et rester possible lorsqu'il contient des Bookings ?
12. Le Reviewer doit-il voir tous les voyages ou seulement ceux « soumis » ? Aucun état Submitted/Processing n'existe.
13. Les référentiels sont-ils administrés dans une autre application ou synchronisés depuis S/4HANA ?
14. La facet Supplements doit-elle être accessible dans une Booking Object Page dédiée ?
15. Faut-il masquer/désactiver les actions dans Fiori selon rôle et statut via `OperationAvailable` ?

### 20.2 Questions techniques et sécurité

1. Confirmer l'enforcement productif des annotations élémentaires `@assert.unique`; envisager des contraintes uniques nommées au niveau entité.
2. Réactiver ou justifier `csrfProtection: false` sur la route OData.
3. Ajouter des tests pour CRUD Booking/Supplement, recalcul, montants négatifs, 404/409, Admin et référentiels readonly.
4. Clarifier la gestion des DELETE : après suppression Booking/Supplement, `req.data` contient-il toujours les FK nécessaires au recalcul dans tous les dialectes CAP ?
5. Définir volumétrie, temps de réponse, disponibilité, rétention, sauvegarde/restauration et RPO/RTO.
6. Ajouter audit métier des décisions et remises si exigé.
7. Définir la stratégie de migration HANA pour les évolutions CDS incompatibles.
8. Confirmer que `/health` doit rester public et distinguer liveness/readiness si nécessaire.

### 20.3 Contradictions et écarts observés

- Le modèle expose des statuts Booking, mais aucun comportement associé : modèle plus riche que l'implémentation.
- L'UI déclare une facet Supplements sur Booking sans route Booking Object Page explicite : annotation plus riche que la navigation configurée.
- `totalPrice` est readonly dans Fiori mais validé comme une entrée modifiable par le handler : protection UI et contrat API ne sont pas parfaitement alignés.
- La description XSUAA Administrator suggère une administration générale, mais les référentiels restent readonly et les voyages non ouverts restent non modifiables par la restriction de service.
- Les README/docs décrivent le socle, mais seuls les tests et handlers démontrent les règles détaillées ; ce SRS privilégie le code et les tests.

---

## Annexe A — Inventaire des artefacts SAP recherchés

| Artefact recherché                     | Résultat                                   |
| -------------------------------------- | ------------------------------------------ |
| CDS Domain Model                       | Présent : `db/common.cds`, `db/schema.cds` |
| CAP Service Definition                 | Présent : `srv/travel-service.cds`         |
| CAP Handler                            | Présent : `srv/travel-service.js`          |
| Fiori annotations                      | Présent : `app/travel/annotations.cds`     |
| SAPUI5 manifest/Component              | Présent                                    |
| ABAP classes                           | Absent                                     |
| RAP Behavior Definition/Implementation | Absent                                     |
| ABAP Service Definition/Binding        | Absent                                     |
| OData V4                               | Présent via CAP                            |
| Sécurité/rôles                         | XSUAA + mock local présents                |
| Tests unitaires                        | Aucun fichier unitaire isolé               |
| Tests d'intégration                    | Présents, Jest/cds.test                    |
| Données de démonstration               | 10 CSV présents                            |
| Déploiement                            | MTA Cloud Foundry/HANA/HTML5/XSUAA         |

## Annexe B — Dernière recherche de complétude

La dernière recherche transversale a couvert : déclarations `entity/type/service/action/function`, annotations `requires/restrict/readonly/draft/UI/Common`, handlers `before/on/after`, erreurs `400/403/404/409`, opérations `SELECT/UPDATE`, routes manifest/AppRouter, rôles/scopes, tests et CSV. Aucun autre service, action, fonction, handler métier, écran Fiori, rôle applicatif ou artefact ABAP/RAP n'a été découvert hors des éléments documentés ci-dessus.
