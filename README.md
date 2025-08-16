# MT5 TCP Server Production System

## Visão Geral

O MT5 TCP Server Production System é uma solução completa para comunicação TCP entre MetaTrader 5 e aplicações externas. Este sistema permite controle remoto de operações de trading, consulta de dados de mercado e gerenciamento de posições através de uma interface TCP robusta e segura.

The MT5 TCP Server Production System is a complete solution for TCP communication between MetaTrader 5 and external applications. This system enables remote control of trading operations, market data queries, and position management through a robust and secure TCP interface.

## Estrutura do Projeto

### Arquivos Principais

#### 1. MT5_Server_TCP.mq5
**Descrição**: Expert Advisor principal que implementa o servidor TCP no MetaTrader 5.

**Classes e Estruturas**:
- `CommandData`: Estrutura para dados de comando recebidos
- `ResponseData`: Estrutura para dados de resposta enviados

**Funções Principais**:
- `OnInit()`: Inicialização do servidor TCP
  - **Retorno**: `int` - Status de inicialização (INIT_SUCCEEDED ou INIT_FAILED)
- `OnDeinit()`: Finalização e limpeza de recursos
  - **Parâmetros**: `const int reason` - Motivo da finalização
- `OnTick()`: Processamento de comandos TCP a cada tick
- `StartTCPServer()`: Inicia o servidor TCP na porta configurada
  - **Retorno**: `bool` - True se servidor iniciado com sucesso
- `ProcessClientConnections()`: Processa conexões de clientes
- `HandleClientCommand()`: Processa comandos recebidos dos clientes
  - **Parâmetros**: `int client_socket` - Socket do cliente
  - **Retorno**: `bool` - True se comando processado com sucesso

**Variáveis Globais**:
- `server_socket`: Socket do servidor TCP
- `client_sockets[]`: Array de sockets de clientes conectados
- `max_clients`: Número máximo de clientes simultâneos
- `server_port`: Porta do servidor TCP

#### 2. MT5_Server_TCP_Functions.mqh
**Descrição**: Biblioteca de funções auxiliares para operações de trading e comunicação.

**Estruturas**:
```mql5
struct CommandData {
    string action;        // Ação a ser executada
    string symbol;        // Símbolo do instrumento
    double volume;        // Volume da operação
    double price;         // Preço da operação
    int ticket;          // Ticket da posição/ordem
    string comment;      // Comentário da operação
};

struct ResponseData {
    bool success;        // Status da operação
    string message;      // Mensagem de resposta
    double value;        // Valor numérico de retorno
    int ticket;         // Ticket gerado/modificado
};
```

**Funções de Trading**:
- `ExecuteOpenBuy()`: Executa ordem de compra
  - **Parâmetros**: `string symbol, double volume, double price, string comment`
  - **Retorno**: `ResponseData` - Resultado da operação
- `ExecuteOpenSell()`: Executa ordem de venda
  - **Parâmetros**: `string symbol, double volume, double price, string comment`
  - **Retorno**: `ResponseData` - Resultado da operação
- `ExecuteClosePosition()`: Fecha posição específica
  - **Parâmetros**: `int ticket`
  - **Retorno**: `ResponseData` - Resultado do fechamento
- `ExecuteModifyPosition()`: Modifica stop loss e take profit
  - **Parâmetros**: `int ticket, double sl, double tp`
  - **Retorno**: `ResponseData` - Resultado da modificação

**Funções de Consulta**:
- `GetMarketData()`: Obtém dados de mercado do símbolo
  - **Parâmetros**: `string symbol`
  - **Retorno**: `ResponseData` - Dados de bid, ask, spread
- `GetPositions()`: Lista todas as posições abertas
  - **Retorno**: `string` - JSON com posições abertas
- `GetOrders()`: Lista todas as ordens pendentes
  - **Retorno**: `string` - JSON com ordens pendentes

**Funções Auxiliares**:
- `ParseJSONCommand()`: Analisa comando JSON recebido
  - **Parâmetros**: `string json_string`
  - **Retorno**: `CommandData` - Estrutura de comando parseada
- `FormatResponse()`: Formata resposta em JSON
  - **Parâmetros**: `ResponseData response`
  - **Retorno**: `string` - JSON formatado para envio

#### 3. expanded_mt5_test_client.py
**Descrição**: Cliente Python para teste e comunicação com o servidor MT5 TCP.

**Classes**:
- `MT5TCPClient`: Classe principal para comunicação TCP
  - **Métodos**:
    - `__init__(host, port)`: Inicializa cliente TCP
    - `connect()`: Conecta ao servidor MT5
      - **Retorno**: `bool` - Status da conexão
    - `disconnect()`: Desconecta do servidor
    - `send_command(command)`: Envia comando ao servidor
      - **Parâmetros**: `dict command` - Comando em formato dicionário
      - **Retorno**: `dict` - Resposta do servidor

**Funções de Teste**:
- `test_connection()`: Testa conectividade com servidor
  - **Retorno**: `bool` - Status do teste
- `test_market_data()`: Testa obtenção de dados de mercado
  - **Parâmetros**: `string symbol`
  - **Retorno**: `dict` - Dados de mercado
- `test_open_position()`: Testa abertura de posição
  - **Parâmetros**: `string action, string symbol, float volume`
  - **Retorno**: `dict` - Resultado da operação
- `test_close_position()`: Testa fechamento de posição
  - **Parâmetros**: `int ticket`
  - **Retorno**: `dict` - Resultado do fechamento
- `test_get_positions()`: Testa listagem de posições
  - **Retorno**: `list` - Lista de posições abertas

## Arquivos de Configuração

### config.ini
**Descrição**: Arquivo de configuração principal do sistema.

**Seções**:
- `[SERVER]`: Configurações do servidor TCP
  - `port`: Porta do servidor (padrão: 9090)
  - `max_clients`: Máximo de clientes simultâneos
  - `heartbeat_interval`: Intervalo de heartbeat em segundos
- `[LOGGING]`: Configurações de log
  - `enable_logging`: Habilita/desabilita logs
  - `log_level`: Nível de log (INFO, DEBUG, ERROR)
- `[TRADING]`: Configurações de trading
  - `max_volume`: Volume máximo por operação
  - `allowed_symbols`: Símbolos permitidos para trading
- `[SECURITY]`: Configurações de segurança
  - `enable_authentication`: Habilita autenticação
  - `allowed_ips`: IPs permitidos para conexão

## Arquivos de Instalação

### INSTALLATION.md
**Descrição**: Guia completo de instalação e configuração do sistema.

**Conteúdo**:
- Pré-requisitos do sistema
- Instalação do MetaTrader 5
- Configuração do Expert Advisor
- Instalação das dependências Python
- Configuração de firewall
- Testes de conectividade
- Solução de problemas comuns

### setup.bat
**Descrição**: Script de instalação automatizada para Windows.

**Funcionalidades**:
- Verifica instalação do Python
- Instala dependências Python automaticamente
- Configura variáveis de ambiente
- Compila arquivos MQL5
- Configura regras de firewall
- Executa testes de conectividade

## Comandos Suportados

### Comandos de Trading
- `OPEN_BUY`: Abre posição de compra
- `OPEN_SELL`: Abre posição de venda
- `CLOSE_POSITION`: Fecha posição específica
- `MODIFY_POSITION`: Modifica SL/TP de posição

### Comandos de Consulta
- `GET_MARKET_DATA`: Obtém dados de mercado
- `GET_POSITIONS`: Lista posições abertas
- `GET_ORDERS`: Lista ordens pendentes
- `GET_ACCOUNT_INFO`: Informações da conta

### Comandos de Sistema
- `PING`: Teste de conectividade
- `STATUS`: Status do servidor
- `SHUTDOWN`: Encerra servidor (admin)

## Formato de Comunicação

### Formato de Comando (JSON)
```json
{
    "action": "OPEN_BUY",
    "symbol": "EURUSD",
    "volume": 0.1,
    "price": 1.1234,
    "comment": "Test trade"
}
```

### Formato de Resposta (JSON)
```json
{
    "success": true,
    "message": "Position opened successfully",
    "ticket": 12345,
    "value": 1.1234
}
```

## Segurança

- Autenticação por IP
- Validação de comandos
- Logs de auditoria
- Controle de volume máximo
- Timeout de conexão

## Requisitos do Sistema

- MetaTrader 5 build 3000+
- Windows 10/11 ou Windows Server 2016+
- Python 3.8+
- Conexão de internet estável
- Firewall configurado

## Suporte e Manutenção

- Logs detalhados em `Logs/` directory
- Monitoramento de performance
- Backup automático de configurações
- Atualizações de segurança regulares

---

**Versão**: 2.0  
**Data**: 2025  
**Autor**: PerplexCoder
