# Workflow SDLC

## Chaîne de livraison

```text
Besoin / anomalie
      ↓
Issue + critères d'acceptation
      ↓
Branche feature/fix + commits conventionnels
      ↓
Pull Request vers develop
      ↓
Format → CDS/ESLint → tests/couverture → build HANA → sécurité
      ↓
Déploiement Development → tests métier → promotion main
      ↓
Tag SemVer → MTAR + provenance → approbation GitHub Environment
      ↓
Test puis Production → smoke test → observation / rollback
```

## Branches et environnements

| Branche/événement    | Contrôles                            | Résultat                  |
| -------------------- | ------------------------------------ | ------------------------- |
| `feature/*`, `fix/*` | hooks locaux                         | feedback développeur      |
| Pull request         | CI, CodeQL, audit, dependency review | décision de merge         |
| `develop`            | CI                                   | candidat Development/Test |
| `main`               | CI + sécurité                        | code publiable            |
| tag `vX.Y.Z`         | validation + build MTA + attestation | release GitHub/MTAR       |
| workflow manuel      | approbation d'environnement          | déploiement BTP           |

## Paramétrage GitHub requis

Créer trois **GitHub Environments** : `development`, `test`, `production`. Dans chacun, définir :

- `CF_API`, `CF_ORG`, `CF_SPACE` ;
- `CF_USERNAME`, `CF_PASSWORD` — préférer un utilisateur technique à privilèges minimaux ;
- des reviewers obligatoires pour `test` et `production` ;
- une restriction de branche/tag pour la production.

Protéger `main` et `develop` : pull request obligatoire, un ou deux reviewers, CODEOWNERS après remplacement du placeholder, conversations résolues, branche à jour et checks `CI`/`Security` obligatoires. Interdire force-push et suppression.

## Qualité et tests

- seuils de couverture définis dans `package.json` ;
- tests d'intégration sur SQLite et données déterministes ;
- compilation de tout le modèle CDS ;
- build HANA de production ;
- formatage Prettier et analyse ESLint ;
- audit npm, Dependency Review et CodeQL.

Les tests métier doivent couvrir scénario nominal, bornes, erreur, statut et rôle. Une modification CDS destructive exige une stratégie explicite de migration et restauration.

## Version et release

Utiliser Semantic Versioning : MAJOR pour rupture, MINOR pour fonctionnalité compatible, PATCH pour correction. Le titre de PR et les commits suivent Conventional Commits. Mettre à jour `CHANGELOG.md`, puis créer le tag depuis `main` :

```bash
npm run validate
npm version patch
git push origin main --follow-tags
```

Le workflow `Release` construit le MTAR, génère les notes et atteste sa provenance.

## Déploiement et rollback

Le déploiement est volontairement manuel et protégé. Sélectionner un tag immuable et l'environnement. Après déploiement, vérifier `/health`, les métadonnées OData et un parcours de consultation.

En cas d'incident : arrêter la promotion, conserver les journaux, redéployer le MTAR précédent, vérifier la compatibilité de la base, puis ouvrir une issue d'incident. Ne jamais restaurer une base sans validation du propriétaire des données.

## Responsabilités

| Rôle SDLC                       | Responsabilité                                        |
| ------------------------------- | ----------------------------------------------------- |
| Product Owner / fonctionnel SAP | besoin, priorité, critères et recette                 |
| Développeur CAP/UI5             | implémentation, tests, documentation                  |
| Reviewer                        | qualité, architecture, sécurité et maintenabilité     |
| DevOps/BTP                      | environnements, secrets, déploiement et observabilité |
| Security                        | vulnérabilités, exceptions et réponse à incident      |
