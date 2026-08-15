# Politique de sécurité

Ne signalez pas publiquement une vulnérabilité exploitable. Utilisez l'onglet **Security → Report a vulnerability** du dépôt GitHub ou contactez l'équipe sécurité interne.

Incluez : composant et version, préconditions, preuve de concept minimale, impact et contournement éventuel. Ne joignez aucune donnée personnelle ni secret réel.

Les versions supportées sont la dernière version mineure publiée et, pendant 90 jours, la version mineure précédente. Les secrets compromis doivent être révoqués avant toute correction de code.

Les déploiements utilisent uniquement des secrets GitHub Environment : `CF_API`, `CF_ORG`, `CF_SPACE`, `CF_USERNAME`, `CF_PASSWORD`.
