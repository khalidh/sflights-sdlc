# SFLIGHT CAP

Application de référence SAP CAP pour gérer des voyages, leurs réservations et leurs suppléments.

## Exécution locale

```sh
npm ci
npm run db:deploy
npm test
npm run watch
```

L'authentification locale est simulée. Utilisateurs : `processor`, `reviewer`, `admin` (voir `.cdsrc.json`).

## Structure

- `db/` : modèle de domaine CDS et données initiales
- `srv/` : service OData V4 et règles métier
- `app/travel/` : application SAP Fiori Elements
- `test/` : tests d'intégration
- `xs-security.json`, `mta.yaml` : sécurité et déploiement SAP BTP

## SDLC

Le dépôt fournit des gates locaux et des workflows GitHub pour la CI, la sécurité, les releases MTAR et le déploiement SAP BTP.

```sh
npm run validate
```

Consulter [CONTRIBUTING.md](CONTRIBUTING.md) pour contribuer, [docs/sdlc.md](docs/sdlc.md) pour configurer GitHub/BTP et [docs/runbook.md](docs/runbook.md) pour l'exploitation et le rollback.
