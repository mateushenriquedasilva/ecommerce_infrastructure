# Módulo de Rede Privada - E-commerce

## Visão Geral

Este módulo Terraform provisiona uma arquitetura de rede privada completa no Azure para uma aplicação de e-commerce. A infraestrutura implementa segmentação de rede, isolamento de camadas e comunicação segura entre componentes através de uma Virtual Network (VNet) privada.

## Arquitetura de Rede

### Virtual Network (VNet)

A rede virtual principal (`vnet-${project_name}-${environment}`) utiliza o espaço de endereçamento **10.0.0.0/16**, fornecendo até 65.536 endereços IP para hospedar todos os componentes da infraestrutura.

### Subnets

A arquitetura é dividida em três subnets isoladas, cada uma com uma finalidade específica:

#### 1. Subnet API (`subnet-api-${environment}`)
- **CIDR**: 10.0.1.0/24 (256 endereços)
- **Finalidade**: Hospedagem da camada de aplicação (API/Backend)
- **Características**:
  - **Delegação**: Configurada para `Microsoft.Web/serverFarms`, permitindo integração direta com Azure App Services
  - **Service Endpoints**:
    - `Microsoft.KeyVault`: Acesso seguro e privado ao Azure Key Vault para gerenciamento de secrets
    - `Microsoft.Storage`: Conectividade otimizada com Azure Storage
  - **Conectividade**: Permite comunicação com a subnet de database

#### 2. Subnet Database (`subnet-db-${environment}`)
- **CIDR**: 10.0.2.0/24 (256 endereços)
- **Finalidade**: Hospedagem do PostgreSQL Flexible Server
- **Características**:
  - **Delegação**: Configurada para `Microsoft.DBforPostgreSQL/flexibleServers`
  - **Service Endpoints**: `Microsoft.Storage` para backups e logs
  - **Isolamento**: Recebe conexões apenas da subnet API na porta 5432
  - **Segurança**: Todo tráfego de saída é bloqueado por padrão

#### 3. Subnet Application Gateway (`subnet-agw-${environment}`)
- **CIDR**: 10.0.3.0/24 (256 endereços)
- **Finalidade**: Hospedagem do Application Gateway (ponto de entrada público)
- **Características**: Load balancing, SSL termination e roteamento HTTP/HTTPS

## Segurança de Rede

### Network Security Groups (NSGs)

#### NSG API
Protege a camada de aplicação com as seguintes regras:

| Regra | Prioridade | Direção | Protocolo | Porta | Origem | Ação |
|-------|-----------|---------|-----------|-------|--------|------|
| AllowHTTPS | 100 | Inbound | TCP | 443 | * | Permitir |
| AllowHTTP | 110 | Inbound | TCP | 80 | * | Permitir |

#### NSG Database
Implementa o princípio de privilégio mínimo:

| Regra | Prioridade | Direção | Protocolo | Porta | Origem | Ação |
|-------|-----------|---------|-----------|-------|--------|------|
| AllowPostgreSQL | 100 | Inbound | TCP | 5432 | 10.0.1.0/24 | Permitir |
| DenyAllOutbound | 4096 | Outbound | * | * | * | Negar |

**Nota**: A regra `DenyAllOutbound` garante que o banco de dados não inicie conexões externas, aumentando significativamente a postura de segurança.

## Conectividade Privada

### Private DNS Zone

- **Zona**: `privatelink.postgres.database.azure.com`
- **Finalidade**: Resolução de nomes DNS para acesso privado ao PostgreSQL
- **Integração**: Vinculada à VNet através de Private DNS Zone Virtual Network Link

Este componente permite que os recursos dentro da VNet resolvam o FQDN do PostgreSQL para um endereço IP privado (10.0.2.x), eliminando a necessidade de comunicação pela internet pública.

## Fluxo de Tráfego

```
Internet → Application Gateway (10.0.3.x)
              ↓
        API Subnet (10.0.1.x)
              ↓
   Database Subnet (10.0.2.x)
```

### Comunicação entre Camadas

1. **Internet → API**: Requisições públicas chegam via Application Gateway
2. **API → Database**: Conexão direta via endereço privado (10.0.2.x) na porta 5432
3. **API → Key Vault/Storage**: Tráfego otimizado via Service Endpoints (sem passar pela internet)

## Recursos Provisionados

| Recurso | Tipo | Quantidade |
|---------|------|------------|
| Resource Group | azurerm_resource_group | 1 |
| Virtual Network | azurerm_virtual_network | 1 |
| Subnets | azurerm_subnet | 3 |
| Network Security Groups | azurerm_network_security_group | 2 |
| NSG Associations | azurerm_subnet_network_security_group_association | 2 |
| Private DNS Zone | azurerm_private_dns_zone | 1 |
| DNS Zone Link | azurerm_private_dns_zone_virtual_network_link | 1 |

## Variáveis de Entrada

| Variável | Descrição | Tipo | Padrão |
|----------|-----------|------|--------|
| `project_name` | Nome do projeto | string | - |
| `environment` | Ambiente (dev, staging, prod) | string | - |
| `location` | Localização dos recursos Azure | string | - |
| `vnet_address_space` | Espaço de endereçamento da VNet | list(string) | ["10.0.0.0/16"] |
| `subnet_api_prefix` | CIDR da subnet API | list(string) | ["10.0.1.0/24"] |
| `subnet_database_prefix` | CIDR da subnet Database | list(string) | ["10.0.2.0/24"] |
| `subnet_agw_prefix` | CIDR da subnet AGW | list(string) | ["10.0.3.0/24"] |
| `tags` | Tags para os recursos | map(string) | {} |

## Outputs

| Output | Descrição |
|--------|-----------|
| `resource_group_name` | Nome do Resource Group |
| `resource_group_location` | Localização do Resource Group |
| `vnet_id` | ID da Virtual Network |
| `vnet_name` | Nome da Virtual Network |
| `subnet_api_id` | ID da Subnet API |
| `subnet_database_id` | ID da Subnet Database |
| `subnet_agw_id` | ID da Subnet Application Gateway |
| `private_dns_zone_id` | ID da Private DNS Zone |
| `nsg_api_id` | ID do NSG API |
| `nsg_database_id` | ID do NSG Database |

## Benefícios de Segurança

1. **Isolamento de Camadas**: Cada componente (API, Database, Gateway) opera em sua própria subnet isolada
2. **Comunicação Privada**: Database não possui IP público, acessível apenas via rede privada
3. **Microsegmentação**: NSGs implementam controle granular de tráfego
4. **Service Endpoints**: Acesso a serviços PaaS sem exposição à internet pública
5. **DNS Privado**: Resolução de nomes interna à VNet, sem vazamento de informações

## Exemplo de Uso

```hcl
module "networking" {
  source = "./modules/networking"

  project_name = "ecommerce"
  environment  = "prod"
  location     = "East US"

  vnet_address_space      = ["10.0.0.0/16"]
  subnet_api_prefix       = ["10.0.1.0/24"]
  subnet_database_prefix  = ["10.0.2.0/24"]
  subnet_agw_prefix       = ["10.0.3.0/24"]

  tags = {
    Project     = "E-commerce"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

## Considerações

- A subnet Database tem todo o tráfego de saída bloqueado por padrão. Se backups ou replicação forem necessários, ajuste o NSG.
- O espaço de endereçamento 10.0.0.0/16 suporta crescimento futuro. Subnets adicionais podem ser criadas no range 10.0.4.0+ até 10.0.255.0.
- As delegações de subnet são exclusivas - uma subnet delegada só pode ser usada pelo serviço delegado.

## Compliance

Esta arquitetura implementa boas práticas alinhadas com:
- **Zero Trust Architecture**: Segmentação de rede e controle de tráfego granular
- **Defense in Depth**: Múltiplas camadas de segurança (NSGs, Private Endpoints, Service Endpoints)
- **Least Privilege**: Permissões mínimas necessárias para cada componente
