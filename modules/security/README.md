# Módulo de Segurança - Key Vault

## Visão Geral

Este módulo Terraform provisiona e configura um Azure Key Vault com foco em segurança máxima para gerenciamento centralizado de secrets, chaves criptográficas e certificados da aplicação de e-commerce. A implementação segue as melhores práticas de segurança com acesso privado, controles de rede rigorosos e proteção contra exclusão acidental.

## Componentes da Arquitetura

### Azure Key Vault

Cofre de chaves gerenciado para armazenamento seguro de informações sensíveis:

- **Nome**: `kv-${project_name}-${environment}`
- **SKU**: Standard
- **Tenant ID**: Obtido dinamicamente via `azurerm_client_config`
- **Finalidade**: Armazenamento centralizado de:
  - Secrets (strings de conexão, API keys, tokens)
  - Chaves criptográficas (para encryption at rest)
  - Certificados SSL/TLS

### Configurações de Segurança

#### 1. Isolamento de Rede

```hcl
public_network_access_enabled = false
```

**Acesso público completamente desabilitado**. O Key Vault não é acessível via internet pública, eliminando vetores de ataque externos.

#### 2. Network ACLs

```hcl
network_acls {
  bypass = "AzureServices"
  default_action = "Deny"
}
```

| Configuração | Valor | Descrição |
|--------------|-------|-----------|
| `default_action` | Deny | Bloqueia todo tráfego por padrão |
| `bypass` | AzureServices | Permite serviços confiáveis do Azure (Azure Backup, Azure Disk Encryption) |

**Princípio de Zero Trust**: Tudo é negado por padrão, apenas conexões privadas são permitidas.

#### 3. Proteção contra Exclusão

| Recurso | Configuração | Ambiente |
|---------|--------------|----------|
| **Soft Delete** | 7 dias de retenção | Todos |
| **Purge Protection** | Habilitado | Produção apenas |

- **Soft Delete**: Keys, secrets e certificados deletados ficam em estado de "soft delete" por 7 dias, permitindo recuperação
- **Purge Protection**: Em produção, impede exclusão permanente durante o período de retenção

#### 4. Capacidades Adicionais

```hcl
enabled_for_disk_encryption = true
```

Habilita uso do Key Vault para Azure Disk Encryption, permitindo criptografia de discos de VMs.

## Conectividade Privada

### Private Endpoint

Conexão privada entre a VNet e o Key Vault através do Azure Backbone:

- **Nome**: `pe-kv-${environment}`
- **Subnet**: Conectado à subnet da API (var.subnet_id)
- **Subresource**: `vault`
- **IP Privado**: Alocado automaticamente dentro da subnet

#### Fluxo de Acesso

```
API (10.0.1.x) → Private Endpoint → Key Vault
                    (Azure Backbone)
```

**Benefícios**:
- Tráfego não passa pela internet pública
- Latência reduzida
- Conformidade com requisitos de rede privada

### Private DNS Zone

- **Zona**: `privatelink.vaultcore.azure.net`
- **Integração**: Vinculada à VNet via Private DNS Zone Virtual Network Link

#### Resolução DNS

| FQDN Original | Resolução Pública | Resolução Privada (via VNet) |
|---------------|-------------------|------------------------------|
| `kv-ecommerce-prod.vault.azure.net` | IP Público | 10.0.1.x (Private Endpoint) |

Recursos dentro da VNet resolvem automaticamente o FQDN do Key Vault para o endereço IP privado.

## Controle de Acesso

### Access Policy - Terraform Principal

Política de acesso concedida ao principal que executa o Terraform:

#### Permissões de Secrets
| Permissão | Finalidade |
|-----------|-----------|
| Get | Ler secrets |
| List | Listar secrets |
| Set | Criar/atualizar secrets |
| Delete | Deletar secrets (soft delete) |
| Purge | Exclusão permanente |
| Recover | Recuperar secrets deletados |

#### Permissões de Certificates
| Permissão | Finalidade |
|-----------|-----------|
| Get | Ler certificados |
| List | Listar certificados |
| Create | Criar certificados |
| Delete | Deletar certificados |
| Purge | Exclusão permanente |

#### Permissões de Keys
| Permissão | Finalidade |
|-----------|-----------|
| Get | Ler chaves |
| List | Listar chaves |
| Create | Criar chaves |
| Delete | Deletar chaves |
| Purge | Exclusão permanente |

**Nota**: Em produção, políticas adicionais devem ser criadas para aplicações que consomem secrets (com permissões somente leitura: Get, List).

## Recursos Provisionados

| Recurso | Tipo | Quantidade |
|---------|------|------------|
| Key Vault | azurerm_key_vault | 1 |
| Access Policy | azurerm_key_vault_access_policy | 1 |
| Private Endpoint | azurerm_private_endpoint | 1 |
| Private DNS Zone | azurerm_private_dns_zone | 1 |
| DNS Zone Link | azurerm_private_dns_zone_virtual_network_link | 1 |

## Variáveis de Entrada

| Variável | Descrição | Tipo | Obrigatório |
|----------|-----------|------|-------------|
| `project_name` | Nome do projeto | string | Sim |
| `environment` | Ambiente (dev, staging, prod) | string | Sim |
| `location` | Localização dos recursos Azure | string | Sim |
| `resource_group_name` | Nome do Resource Group | string | Sim |
| `subnet_id` | ID da subnet para Private Endpoint | string | Sim |
| `vnet_id` | ID da Virtual Network | string | Sim |
| `tags` | Tags para os recursos | map(string) | Não |

## Outputs

| Output | Descrição | Uso |
|--------|-----------|-----|
| `key_vault_id` | ID do Key Vault | Referência em outros módulos |
| `key_vault_name` | Nome do Key Vault | CLI/scripts de automação |
| `key_vault_uri` | URI do Key Vault | Configuração de aplicações |

## Exemplo de Uso

```hcl
module "security" {
  source = "./modules/security"

  project_name        = "ecommerce"
  environment         = "prod"
  location            = "East US"
  resource_group_name = module.networking.resource_group_name
  subnet_id           = module.networking.subnet_api_id
  vnet_id             = module.networking.vnet_id

  tags = {
    Project     = "E-commerce"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Criticality = "High"
  }
}
```

## Casos de Uso

### 1. Armazenar Connection String do Banco de Dados

```bash
az keyvault secret set \
  --vault-name kv-ecommerce-prod \
  --name "db-connection-string" \
  --value "Host=postgres-server;Database=ecommerce;..."
```

### 2. Armazenar API Key de Serviço Externo

```bash
az keyvault secret set \
  --vault-name kv-ecommerce-prod \
  --name "stripe-api-key" \
  --value "sk_live_..."
```

### 3. Criar Chave de Criptografia

```bash
az keyvault key create \
  --vault-name kv-ecommerce-prod \
  --name "data-encryption-key" \
  --kty RSA \
  --size 2048
```

## Integração com Aplicações

### App Service / Azure Functions

Configure **System-assigned Managed Identity** e adicione Access Policy:

```hcl
resource "azurerm_key_vault_access_policy" "app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = azurerm_linux_web_app.api.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
```

### Referência em Configuração de App Service

```hcl
app_settings = {
  "DATABASE_CONNECTION_STRING" = "@Microsoft.KeyVault(SecretUri=${module.security.key_vault_uri}secrets/db-connection-string/)"
}
```

## Segurança e Compliance

### Benefícios Implementados

1. ✅ **Zero Network Exposure**: Acesso público desabilitado
2. ✅ **Private Connectivity**: Comunicação via Azure Backbone
3. ✅ **Encryption in Transit**: TLS 1.2+ obrigatório
4. ✅ **Encryption at Rest**: Dados criptografados automaticamente pelo Azure
5. ✅ **Audit Logging**: Integração com Azure Monitor (configurar separadamente)
6. ✅ **Disaster Recovery**: Soft delete para recuperação
7. ✅ **Immutability (Prod)**: Purge protection previne exclusão permanente

### Conformidade

Esta implementação atende requisitos de:

- **PCI DSS**: Armazenamento seguro de dados sensíveis
- **GDPR**: Proteção de dados pessoais
- **SOC 2**: Controles de acesso e auditoria
- **ISO 27001**: Gestão de chaves criptográficas

## Monitoramento Recomendado

Configure Azure Monitor para capturar:

- **AuditEvent**: Todas as operações no Key Vault
- **Failed Access Attempts**: Tentativas de acesso não autorizado
- **Secret Retrieval**: Acesso a secrets específicos
- **Administrative Operations**: Mudanças em políticas de acesso

Exemplo de query KQL:

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where ResultType == "Unauthorized"
| summarize Count=count() by CallerIPAddress, bin(TimeGenerated, 5m)
```

## Limitações e Considerações

### Limitações do SKU Standard
- Chaves protegidas por software (não HSM)
- Para requisitos de FIPS 140-2 Level 2, considere SKU Premium com HSM

### Custo
- **Standard**: ~$0.03 por 10.000 operações
- Sem custo base mensal
- Private Endpoint: ~$7.30/mês

### Quotas
- **Secrets**: 25.000 por vault
- **Keys**: 25.000 por vault
- **Transactions**: 2.000 requisições/10s por vault

### Recuperação de Desastres

Embora o Key Vault seja um serviço regional, os secrets são automaticamente replicados dentro da região. Para disaster recovery entre regiões:

1. Configure backup automatizado de secrets
2. Implemente replicação cross-region se necessário
3. Documente processo de recuperação

## Manutenção

### Rotação de Secrets

Implemente rotação regular de:
- ✅ Connection strings: 90 dias
- ✅ API keys: 90 dias
- ✅ Certificados: 30 dias antes do vencimento

### Revisão de Access Policies

- Audite permissões trimestralmente
- Remova identidades não utilizadas
- Aplique princípio de privilégio mínimo
- Use Managed Identities sempre que possível

## Troubleshooting

### Erro: "Forbidden - Request originated from client IP"

**Causa**: Tentativa de acesso via IP público  
**Solução**: Conecte-se via VPN/Bastion ou utilize Azure Cloud Shell

### Erro: "Access denied to vault"

**Causa**: Access Policy não configurada  
**Solução**: Adicione Access Policy para o principal/identity

### DNS não resolve para IP privado

**Causa**: Private DNS Zone não vinculada à VNet  
**Solução**: Verifique `azurerm_private_dns_zone_virtual_network_link`

## Próximos Passos

1. Configure Azure Monitor Diagnostics para auditoria
2. Implemente Azure Policy para governança
3. Configure alertas para operações críticas
4. Documente processo de rotação de secrets
5. Integre com CI/CD pipeline para gestão de secrets
