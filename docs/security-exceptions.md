# Registre des exceptions de sécurité

Toute exception doit avoir un propriétaire, une justification, des mesures compensatoires et une date d'expiration. Elle doit être réévaluée à chaque mise à jour de dépendance.

| ID         | Composant                                                          | Portée                                | Risque                                                                                    | Mesures                                                                                                   | Expiration |
| ---------- | ------------------------------------------------------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ---------- |
| SEC-EX-001 | Dépendances transitives de `@ui5/cli` 4.0.62 (`sigstore`/`pacote`) | Build uniquement, absentes du runtime | Advisories npm hauts/modérés sans version corrective compatible publiée lors de l'analyse | Lockfile, Dependabot, audit non bloquant visible, artefact MTAR attesté, runtime audité avec `--omit=dev` | 2026-09-15 |

Le propriétaire SDLC doit supprimer cette exception dès la publication d'une version UI5 CLI corrigée. Une exception expirée fait échouer la revue de release, même si le workflow technique reste vert.
