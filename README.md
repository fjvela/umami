# umami

Based on https://davidsantiago.fr/deploy-umami-on-azure-container-apps
- posgresql password must be encoded using percent-encoding - https://www.prisma.io/docs/concepts/database-connectors/postgresql#connection-url

Deploy [umami](https://umami.is/) - your website analytics using:
- Azure Container Apps: https://azure.microsoft.com/en-us/products/container-apps/#overview
- Azure Database for PostgreSQL flexible servers: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/