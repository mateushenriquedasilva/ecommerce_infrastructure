# Módulo de Database - PostgreSQL Flexible Server

## Visão Geral

Este módulo Terraform provisiona um Azure Database for PostgreSQL Flexible Server com foco em segurança, alta disponibilidade e conformidade. A infraestrutura implementa comunicação exclusivamente privada, backups automáticos, e configurações otimizadas para ambientes de produção de e-commerce.

## Componentes da Arquitetura

### PostgreSQL Flexible Server

Banco de dados gerenciado totalmente integrado à rede privada:

- **Nome**: `psql-${project_name}-${environment}`
- **Versão**: PostgreSQL 15
- **Finalidade**: Armazenamento transacional do e-commerce
- **Conectividade**: 100% privada via subnet delegada
- **Zona de Disponibilidade**: Zona 1 (primary)

### Características Principais

#### 1. Isolamento de Rede Total

```hcl
public_network_access_enabled = false
delegated_subnet_id = var.subnet_id
private_dns_zone_id = var.private_dns_zone_id
```

**Zero exposição pública**:
- Sem endereço IP público
- Implantado em subnet delegada (10.0.2.0/24)
- Acessível apenas via rede privada
- DNS privado para resolução de nomes

#### 2. Alta Disponibilidade (Produção)

| Ambiente | Modo HA | Standby Zone | RPO | RTO |
|----------|---------|--------------|-----|-----|
| **Produção** | ZoneRedundant | Zona 2 | ~0s | ~60-120s |
| **Dev/Staging** | Disabled | N/A | Depende backup | 15-30 min |

**ZoneRedundant (Produção)**:
- Réplica síncrona em zona de disponibilidade diferente
- Failover automático em caso de falha
- Zero perda de dados (RPO = 0)
- Downtime mínimo durante failover

#### 3. SKU e Performance

| SKU | Ambiente | vCores | RAM | IOPS | Throughput |
|-----|----------|--------|-----|------|------------|
| `B_Standard_B1ms` | Dev/Staging | 1 | 2GB | 640 | 10 MB/s |
| `GP_Standard_D2s_v3` | Produção (recomendado) | 2 | 8GB | 3200 | 48 MB/s |

**Camadas Disponíveis**:
- **Burstable (B)**: Desenvolvimento, testes, cargas leves
- **General Purpose (GP)**: Produção, aplicações empresariais
- **Memory Optimized (MO)**: Workloads com uso intensivo de memória

#### 4. Armazenamento e Backups

| Configuração | Valor Padrão | Produção Recomendado |
|--------------|--------------|----------------------|
| Storage | 32GB | 128GB - 1TB |
| Backup Retention | 7 dias | 35 dias |
| Geo-Redundant Backup | Desabilitado | Habilitado |
| Auto-scaling | Habilitado (padrão) | Habilitado |

**Características de Backup**:
- Backups automáticos diários
- Point-in-time restore (PITR) dentro do período de retenção
- Backups incrementais contínuos
- Geo-redundância opcional para DR

## Segurança

### Configurações de Segurança Implementadas

#### 1. Require Secure Transport

```hcl
require_secure_transport = "on"
```

**Efeito**: Força todas as conexões a usar TLS/SSL
- Previne man-in-the-middle attacks
- Criptografia de dados em trânsito obrigatória
- Rejeita conexões não criptografadas

#### 2. Logging de Conexões

```hcl
log_connections = "on"
log_disconnections = "on"
```

**Auditoria completa**:
- Registra todas as tentativas de conexão
- Monitora disconnections
- Facilita investigação de incidentes
- Compliance com requisitos de auditoria

### Fluxo de Autenticação

```
Application → Private Endpoint → PostgreSQL
                  (TLS 1.2+)     (Subnet 10.0.2.x)
```

**Credenciais**: Armazenadas no Key Vault e referenciadas via Terraform variables

## Database e Configurações

### Database Ecommerce

```hcl
name      = "ecommerce_${environment}"
collation = "en_US.UTF8"
charset   = "UTF8"
```

**Características**:
- Unicode completo (UTF8)
- Collation em inglês (modificar se necessário)
- Schema isolado por ambiente

### Connection String

```
Host=psql-ecommerce-prod.postgres.database.azure.com;
Database=ecommerce_prod;
Username=psqladmin@psql-ecommerce-prod;
Password=<from-key-vault>;
SslMode=Require;
```

## Recursos Provisionados

| Recurso | Tipo | Quantidade |
|---------|------|------------|
| PostgreSQL Server | azurerm_postgresql_flexible_server | 1 |
| Database | azurerm_postgresql_flexible_server_database | 1 |
| Server Configurations | azurerm_postgresql_flexible_server_configuration | 3 |

## Variáveis de Entrada

| Variável | Descrição | Tipo | Padrão | Obrigatório |
|----------|-----------|------|--------|-------------|
| `project_name` | Nome do projeto | string | - | Sim |
| `environment` | Ambiente (dev, staging, prod) | string | - | Sim |
| `resource_group_name` | Nome do Resource Group | string | - | Sim |
| `location` | Localização dos recursos Azure | string | - | Sim |
| `subnet_id` | ID da subnet delegada | string | - | Sim |
| `private_dns_zone_id` | ID da Private DNS Zone | string | - | Sim |
| `administrator_login` | Username do administrador | string | - | Sim |
| `administrator_password` | Senha do administrador | string | - | Sim |
| `sku_name` | SKU do servidor | string | B_Standard_B1ms | Não |
| `storage_mb` | Armazenamento em MB | number | 32768 | Não |
| `backup_retention_days` | Dias de retenção de backup | number | 7 | Não |
| `geo_redundant_backup_enabled` | Habilitar backup geo-redundante | bool | false | Não |
| `tags` | Tags para os recursos | map(string) | {} | Não |

## Outputs

| Output | Descrição | Sensível |
|--------|-----------|----------|
| `server_id` | ID do servidor PostgreSQL | Não |
| `server_fqdn` | FQDN do servidor | Não |
| `database_name` | Nome do database | Não |
| `administrator_login` | Username do administrador | Sim |

## Exemplo de Uso

### Desenvolvimento

```hcl
module "database" {
  source = "./modules/database"

  project_name         = "ecommerce"
  environment          = "dev"
  location             = "East US"
  resource_group_name  = module.networking.resource_group_name
  subnet_id            = module.networking.subnet_database_id
  private_dns_zone_id  = module.networking.private_dns_zone_id
  
  administrator_login    = "psqladmin"
  administrator_password = random_password.db_password.result

  sku_name                = "B_Standard_B1ms"
  storage_mb              = 32768
  backup_retention_days   = 7
  geo_redundant_backup_enabled = false

  tags = {
    Project     = "E-commerce"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
```

### Produção

```hcl
module "database" {
  source = "./modules/database"

  project_name         = "ecommerce"
  environment          = "prod"
  location             = "East US"
  resource_group_name  = module.networking.resource_group_name
  subnet_id            = module.networking.subnet_database_id
  private_dns_zone_id  = module.networking.private_dns_zone_id
  
  administrator_login    = "psqladmin"
  administrator_password = azurerm_key_vault_secret.db_password.value

  sku_name                = "GP_Standard_D4s_v3"  # 4 vCores, 16GB RAM
  storage_mb              = 131072                 # 128GB
  backup_retention_days   = 35
  geo_redundant_backup_enabled = true

  tags = {
    Project     = "E-commerce"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Criticality = "High"
  }
}
```

## Integração com Aplicações

### App Service Connection

1. **Armazenar Connection String no Key Vault**:

```hcl
resource "azurerm_key_vault_secret" "db_connection" {
  name         = "database-connection-string"
  value        = "Host=${module.database.server_fqdn};Database=${module.database.database_name};Username=${var.administrator_login};Password=${var.administrator_password};SslMode=Require;"
  key_vault_id = module.security.key_vault_id
}
```

2. **Referenciar no App Service**:

```hcl
resource "azurerm_linux_web_app" "api" {
  # ... outras configurações
  
  app_settings = {
    "DATABASE_CONNECTION_STRING" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_connection.id})"
  }
}
```

### Entity Framework Core (.NET)

```csharp
services.AddDbContext<EcommerceContext>(options =>
    options.UseNpgsql(
        Configuration.GetConnectionString("DATABASE_CONNECTION_STRING"),
        npgsqlOptions => {
            npgsqlOptions.EnableRetryOnFailure(
                maxRetryCount: 3,
                maxRetryDelay: TimeSpan.FromSeconds(5),
                errorCodesToAdd: null
            );
        }
    )
);
```

### Node.js (pg)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_CONNECTION_STRING,
  ssl: {
    rejectUnauthorized: true
  },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

## Gestão de Senhas

### Geração Segura com Terraform

```hcl
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "postgresql-admin-password"
  value        = random_password.db_password.result
  key_vault_id = module.security.key_vault_id
}
```

### Rotação de Senhas

**Processo Recomendado**:
1. Criar novo usuário com mesmos privilégios
2. Atualizar connection strings para novo usuário
3. Monitorar por 24-48h
4. Revogar usuário anterior

**Rotação Automática**: Configure Azure Key Vault rotation policies (requer função automation).

## Monitoramento e Manutenção

### Métricas Importantes

| Métrica | Alerta Recomendado | Ação |
|---------|-------------------|------|
| CPU Percentage | > 80% por 10 min | Scale up SKU |
| Memory Percentage | > 85% por 10 min | Scale up ou otimizar queries |
| Storage Percentage | > 85% | Aumentar storage |
| Active Connections | > 80% do limite | Revisar connection pooling |
| Failed Connections | > 5 por minuto | Investigar credenciais/network |

### Queries Úteis para Diagnóstico

#### Conexões Ativas

```sql
SELECT 
  datname,
  usename,
  application_name,
  client_addr,
  state,
  query_start,
  state_change
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;
```

#### Tamanho dos Databases

```sql
SELECT 
  pg_database.datname,
  pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

#### Queries Lentas (Top 10)

```sql
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

## Backup e Disaster Recovery

### Backups Automáticos

- **Frequência**: Contínua (PITR)
- **Retenção**: 7-35 dias configurável
- **Tipo**: Full + incremental contínuo
- **Geo-redundância**: Opcional (replicação cross-region)

### Point-in-Time Restore (PITR)

Restaurar para qualquer momento dentro do período de retenção:

```bash
az postgres flexible-server restore \
  --resource-group rg-ecommerce-prod \
  --name psql-ecommerce-prod-restored \
  --source-server psql-ecommerce-prod \
  --restore-time "2026-02-01T10:30:00Z"
```

### Disaster Recovery Strategy

| Cenário | Solução | RTO | RPO |
|---------|---------|-----|-----|
| Corrupção de dados | PITR | < 1h | Minutos |
| Falha zonal | High Availability (auto) | 60-120s | 0 |
| Falha regional | Geo-restore | 1-4h | < 1h |

## Otimização de Performance

### Configurações Recomendadas para Produção

```sql
-- Shared Buffers (25% da RAM)
ALTER SYSTEM SET shared_buffers = '2GB';

-- Effective Cache Size (50-75% da RAM)
ALTER SYSTEM SET effective_cache_size = '6GB';

-- Maintenance Work Mem
ALTER SYSTEM SET maintenance_work_mem = '512MB';

-- Work Mem
ALTER SYSTEM SET work_mem = '16MB';

-- Max Connections
ALTER SYSTEM SET max_connections = 200;
```

### Connection Pooling

**Recomendação**: Use PgBouncer para ambientes de alta concorrência

Benefícios:
- Reduz overhead de conexões
- Melhora throughput
- Permite mais conexões simultâneas

## Segurança e Compliance

### Checklist de Segurança

- ✅ Acesso público desabilitado
- ✅ Comunicação via rede privada
- ✅ TLS obrigatório (require_secure_transport)
- ✅ Logs de conexão habilitados
- ✅ Senha forte (32 caracteres gerada automaticamente)
- ✅ Credenciais no Key Vault
- ✅ Backups automáticos
- ✅ High Availability em produção
- ✅ Subnet delegada com NSG restritivo

### Conformidade

- **PCI DSS**: Criptografia em trânsito e at rest, auditoria de acesso
- **GDPR**: Data residency, backup encryption, audit logs
- **HIPAA**: TLS obrigatório, audit logging, access controls
- **SOC 2**: Automated backups, HA, security monitoring

## Custos Estimados

### Desenvolvimento

| Componente | Especificação | Custo Mensal (USD) |
|------------|---------------|-------------------|
| PostgreSQL | B_Standard_B1ms | ~$13 |
| Storage | 32GB | ~$4 |
| Backup | 7 dias | ~$1 |
| **Total** | | **~$18** |

### Produção

| Componente | Especificação | Custo Mensal (USD) |
|------------|---------------|-------------------|
| PostgreSQL | GP_Standard_D4s_v3 (HA) | ~$438 |
| Storage | 128GB | ~$16 |
| Backup | 35 dias + Geo-redundante | ~$15 |
| **Total** | | **~$469** |

*Valores aproximados para região East US. Custos variam por região e uso.*

## Limitações Conhecidas

### Flexible Server vs Single Server

| Recurso | Flexible Server | Single Server (deprecado) |
|---------|----------------|---------------------------|
| HA Zones | ✅ Sim | ❌ Não |
| Subnet Integration | ✅ Sim | ⚠️ Limitado |
| Performance | ✅ Melhor | Inferior |
| Managed Identity | ✅ Sim | ❌ Não |

### Quotas e Limites

- **Max Connections**: Varia por SKU (tipicamente 100-5000)
- **Max Storage**: 16TB
- **Max Databases**: Ilimitado (limitado por resources)
- **Backup Retention**: Máximo 35 dias

## Troubleshooting

### Erro: "remaining connection slots are reserved"

**Causa**: Limite de conexões atingido  
**Solução**: 
1. Revisar connection pooling na aplicação
2. Aumentar max_connections (requer restart)
3. Escalar SKU

### Erro: "SSL connection is required"

**Causa**: Tentativa de conexão sem TLS  
**Solução**: Adicionar `sslmode=require` na connection string

### Performance Degradada

**Diagnóstico**:
1. Verificar métricas de CPU/Memory/IOPS
2. Analisar `pg_stat_statements` para queries lentas
3. Verificar bloqueios com `pg_locks`
4. Revisar índices faltantes

### Conexão Failed from API

**Checklist**:
1. ✅ API está na subnet correta?
2. ✅ NSG permite tráfego na porta 5432?
3. ✅ Private DNS Zone está vinculada?
4. ✅ Credenciais corretas?
5. ✅ TLS habilitado na connection string?

## Migração de Dados

### De Single Server para Flexible Server

```bash
# 1. Dump do banco origem
pg_dump -h psql-old.postgres.database.azure.com \
  -U admin -d ecommerce -Fc -f ecommerce.dump

# 2. Restore no Flexible Server
pg_restore -h psql-ecommerce-prod.postgres.database.azure.com \
  -U psqladmin -d ecommerce_prod -v ecommerce.dump
```

### De On-Premises

Use **Azure Database Migration Service** para migração com downtime mínimo.

## Próximos Passos

1. ⚙️ Configure Azure Monitor Metrics e Alerts
2. 📊 Implemente Query Performance Insights
3. 🔐 Configure Managed Identity para aplicações
4. 📈 Estabeleça baseline de performance
5. 🔄 Configure logs para Azure Log Analytics
6. 🧪 Teste disaster recovery procedures
7. 📝 Documente runbooks operacionais
8. 🔍 Configure slow query logging
