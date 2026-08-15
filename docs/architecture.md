# Architecture

```text
SAP Fiori Elements (List Report / Object Page)
                  |
                  v
          OData V4 TravelService
                  |
                  v
   Handlers CAP (validations, actions, calculs)
                  |
                  v
       Modèle de domaine CDS SFLIGHT
                  |
        +---------+---------+
        |                   |
 SQLite (développement)  SAP HANA (production)
```

La sécurité locale utilise l'authentification simulée CAP. En production, XSUAA porte les rôles `TravelProcessor`, `TravelReviewer` et `Administrator`.
