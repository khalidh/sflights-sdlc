# Contribuer à SFLIGHT CAP

## Flux de travail

1. Créer une issue avec critères d'acceptation.
2. Créer une branche depuis `develop` : `feature/<issue>-description`, `fix/<issue>-description` ou `chore/<description>`.
3. Développer en petites modifications testées.
4. Utiliser Conventional Commits : `feat(travel): ajouter la remise`.
5. Ouvrir une pull request vers `develop` et obtenir au moins une approbation.
6. Promouvoir `develop` vers `main` par pull request après validation en environnement de test.
7. Créer un tag SemVer `vX.Y.Z` depuis `main` pour produire un MTAR signé.

Les correctifs urgents partent de `main` via `hotfix/*`, puis sont réintégrés dans `main` et `develop`.

## Definition of Ready

- besoin métier et acteur identifiés ;
- critères d'acceptation vérifiables ;
- impacts données, API, UI et sécurité évalués ;
- dépendances et hypothèses documentées.

## Definition of Done

- code, CDS, annotations et documentation revus ;
- tests positifs, négatifs et d'autorisation ajoutés ;
- `npm run validate` réussit ;
- aucune vulnérabilité haute connue ;
- changement de données rétrocompatible ou procédure de migration documentée ;
- plan de déploiement et de rollback défini.

## Installation locale

```bash
npm ci
npm run db:deploy
npm test
npm run watch
```

Ne jamais versionner de secrets, jetons, destinations, fichiers `default-env.json` ou bases locales.
