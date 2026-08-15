# Runbook d'exploitation

## Contrôles de santé

- `GET /health` doit répondre `200` avec `{"status":"UP"}` ;
- `GET /odata/v4/travel/$metadata` doit répondre `200` après authentification ;
- vérifier l'état des applications et services avec `cf apps` et `cf services`.

## Diagnostic

```bash
cf logs sflight-cap-srv --recent
cf env sflight-cap-srv
cf events sflight-cap-srv
```

Masquer les jetons, credentials, données clients et en-têtes d'autorisation avant tout partage de journaux.

## Rollback

1. Identifier la dernière release saine et son MTAR attesté.
2. Vérifier si le changement contient une migration incompatible.
3. Redéployer avec `cf deploy <release-precedente>.mtar -f`.
4. Effectuer les smoke tests et surveiller les erreurs.
5. Documenter chronologie, impact, cause et actions préventives.
