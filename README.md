# MT5 TCP Server - Sistema de Comunicação Expandido

## Visão Geral

Este projeto implementa um sistema completo de comunicação TCP entre MetaTrader 5 (MT5) e aplicações Python, oferecendo funcionalidades avançadas para trading automatizado, análise de dados de mercado e gerenciamento de conta.

## Arquivos do Projeto

### Servidor MT5 (MQL5)

#### `MT5_Server_TCP.mq5`
**Descrição**: Expert Advisor principal que implementa o servidor TCP no MT5.

**Funcionalidades**:
- Servidor TCP multi-cliente na porta 5557
- Processamento de comandos em tempo real
- Atualização automática de dados de mercado
- Gerenciamento de conexões simultâneas
- Sistema de heartbeat para monitoramento de conexões

**Variáveis Globais**:
- `ServerPort`: Porta do servidor (padrão: 5557)
- `MaxClients`: Número máximo de clientes simultâneos (padrão: 10)
- `current_symbol`: Símbolo atual para dados de mercado (padrão: "EURUSD")
- `currentMarketData`: Estrutura com dados de mercado atuais

#### `MT5_Server_TCP_Functions.mqh`
**Descrição**: Biblioteca de funções auxiliares para o servidor.

**Funções Principais**:
- `InitializeTCPServer()`: Inicializa o servidor TCP
- `ProcessClientConnections()`: Processa conexões de clientes
- `ProcessCommand()`: Processa comandos recebidos
- `UpdateMarketData()`: Atualiza dados de mercado
- `BroadcastMarketData()`: Transmite dados para todos os clientes

#### `socket-library-mt4-mt5.mqh`
**Descrição**: Biblioteca de sockets para comunicação TCP/IP.

**Classes**:
- `ServerSocket`: Implementa servidor TCP
- `ClientSocket`: Implementa cliente TCP
- `Socket`: Classe base para operações de socket

### Cliente Python

#### `expanded_mt5_test_client.py`
**Descrição**: Cliente Python expandido para testes abrangentes do servidor MT5.

**Classe Principal**: `ExpandedMT5TestClient`

**Métodos de Conexão**:
- `connect()`: Estabelece conexão com o servidor
- `disconnect()`: Encerra conexão
- `send_command(command, params)`: Envia comando ao servidor

**Métodos de Teste**:
- `test_ping()`: Testa conectividade básica
- `test_market_data(symbols)`: Obtém dados de mercado detalhados
- `test_account_info()`: Obtém informações completas da conta
- `test_history()`: Obtém histórico de transações
- `test_positions()`: Lista posições abertas
- `test_orders()`: Lista ordens ativas
- `test_place_market_order()`: Coloca ordem a mercado
- `test_place_pending_order()`: Coloca ordem pendente
- `test_close_position()`: Fecha posição específica

#### `test_simple_client.py`
**Descrição**: Cliente básico para testes simples de conectividade.

## Comandos Suportados

### Comandos Básicos

#### `ping`
**Descrição**: Testa conectividade com o servidor.
**Resposta**:
```json
{
  "action": "pong",
  "timestamp": "2025.08.16 13:15:06",
  "server_time": 1723816506
}
```

#### `market_data`
**Descrição**: Obtém dados de mercado detalhados do símbolo atual.
**Resposta**:
```json
{
  "action": "market_data",
  "data": {
    "symbol": "EURUSD",
    "bid": 1.08951,
    "ask": 1.08961,
    "spread": 1.0,
    "last": 1.08956,
    "volume": 1000,
    "time": "2025.08.16 13:15:06",
    "digits": 5,
    "point": 0.00001,
    "tick_size": 0.00001,
    "min_lot": 0.01,
    "max_lot": 100.0,
    "lot_step": 0.01
  }
}
```

#### `account_info`
**Descrição**: Obtém informações detalhadas da conta.
**Resposta**:
```json
{
  "action": "account_info",
  "data": {
    "login": 12345678,
    "name": "Demo Account",
    "server": "MetaQuotes-Demo",
    "currency": "USD",
    "balance": 10000.00,
    "equity": 10000.00,
    "profit": 0.00,
    "margin": 0.00,
    "margin_free": 10000.00,
    "margin_level": 0.00,
    "leverage": 100,
    "trade_allowed": true,
    "trade_expert": true,
    "assets": 10000.00,
    "liabilities": 0.00,
    "commission_blocked": 0.00
  }
}
```

#### `history`
**Descrição**: Obtém histórico de transações dos últimos 30 dias.
**Resposta**:
```json
{
  "action": "history",
  "data": {
    "from": "2025.07.17 13:15:06",
    "to": "2025.08.16 13:15:06",
    "deals": [
      {
        "ticket": 31995826,
        "order": 53492073,
        "time": "2025.08.16 00:05:49",
        "type": 2,
        "entry": 1,
        "symbol": "BTCUSD",
        "volume": 1.0,
        "price": 117450.54,
        "commission": 0.0,
        "swap": 0.0,
        "profit": 61.44,
        "comment": ""
      }
    ],
    "orders": [
      {
        "ticket": 53492073,
        "time_setup": "2025.08.16 00:08:46",
        "time_done": "2025.08.16 00:09:29",
        "type": 0,
        "state": 4,
        "symbol": "BTCUSD",
        "volume_initial": 1.0,
        "volume_current": 0.0,
        "price_open": 117450.54,
        "sl": 0.0,
        "tp": 0.0,
        "comment": ""
      }
    ]
  }
}
```

### Comandos de Trading

#### `positions`
**Descrição**: Lista todas as posições abertas.
**Resposta**:
```json
{
  "action": "positions",
  "data": [
    {
      "ticket": 12345,
      "symbol": "EURUSD",
      "type": 0,
      "volume": 0.1,
      "price_open": 1.08950,
      "price_current": 1.08960,
      "sl": 0.0,
      "tp": 0.0,
      "profit": 1.0,
      "swap": 0.0,
      "comment": ""
    }
  ]
}
```

#### `orders`
**Descrição**: Lista todas as ordens ativas (pendentes).
**Resposta**:
```json
{
  "action": "orders",
  "data": [
    {
      "ticket": 67890,
      "symbol": "EURUSD",
      "type": 2,
      "volume": 0.1,
      "price_open": 1.09000,
      "sl": 1.08500,
      "tp": 1.09500,
      "comment": "Buy Limit"
    }
  ]
}
```

#### `place_order`
**Descrição**: Coloca uma ordem a mercado.
**Parâmetros**:
- `symbol`: Símbolo do instrumento
- `volume`: Volume da ordem
- `type`: Tipo da ordem (0=Buy, 1=Sell)
- `sl`: Stop Loss (opcional)
- `tp`: Take Profit (opcional)

#### `place_pending_order`
**Descrição**: Coloca uma ordem pendente.
**Parâmetros**:
- `symbol`: Símbolo do instrumento
- `volume`: Volume da ordem
- `type`: Tipo da ordem (2=Buy Limit, 3=Sell Limit, 4=Buy Stop, 5=Sell Stop)
- `price`: Preço da ordem
- `sl`: Stop Loss (opcional)
- `tp`: Take Profit (opcional)

#### `close_position`
**Descrição**: Fecha uma posição específica.
**Parâmetros**:
- `ticket`: Ticket da posição a ser fechada

## Estruturas de Dados

### MarketData
```mql5
struct MarketData
{
    double bid;           // Preço de compra
    double ask;           // Preço de venda
    double spread;        // Spread em pontos
    datetime timestamp;   // Timestamp da cotação
    long volume;          // Volume do tick
    double last_price;    // Último preço negociado
};
```

### ClientInfo
```mql5
struct ClientInfo
{
    int socket_handle;    // Handle do socket
    datetime last_ping;   // Último ping recebido
    bool is_active;       // Status da conexão
    string client_id;     // ID do cliente
};
```

## Configuração e Uso

### Pré-requisitos
- MetaTrader 5 instalado
- Python 3.7+ com bibliotecas padrão
- Conta demo ou real no MT5
- Permissões para Expert Advisors habilitadas

### Instalação

1. **Copiar arquivos MQL5**:
   - Copie `MT5_Server_TCP.mq5` para `MQL5/Experts/`
   - Copie `MT5_Server_TCP_Functions.mqh` para `MQL5/Include/`
   - Copie `socket-library-mt4-mt5.mqh` para `MQL5/Include/`

2. **Compilar no MetaEditor**:
   ```bash
   MetaEditor64.exe /compile:"MT5_Server_TCP.mq5"
   ```

3. **Configurar MT5**:
   - Habilitar "Allow automated trading"
   - Habilitar "Allow DLL imports"
   - Adicionar `127.0.0.1:5557` às URLs permitidas

### Execução

1. **Iniciar servidor MT5**:
   - Anexar `MT5_Server_TCP` a um gráfico
   - Verificar logs no terminal MT5

2. **Executar cliente Python**:
   ```bash
   python expanded_mt5_test_client.py
   ```

## Testes Implementados

### Teste Básico de Conectividade
- Conexão TCP na porta 5557
- Teste de ping/pong
- Verificação de timeout

### Teste de Dados de Mercado
- Obtenção de Bid/Ask em tempo real
- Informações detalhadas do símbolo
- Dados de volume e timestamp
- Especificações de trading (lotes, spreads)

### Teste de Informações da Conta
- Dados básicos da conta (login, servidor, moeda)
- Informações financeiras (saldo, patrimônio, margem)
- Configurações de trading (alavancagem, permissões)
- Dados de risco (ativos, passivos)

### Teste de Histórico
- Histórico de negociações (deals)
- Histórico de ordens executadas
- Filtros por período (últimos 30 dias)
- Limitação de resultados (100 registros)

### Testes de Trading
- Listagem de posições abertas
- Listagem de ordens pendentes
- Colocação de ordens a mercado
- Colocação de ordens pendentes
- Fechamento de posições

## Segurança

### Proteções Implementadas
- Detecção de conta real vs demo
- Limitação de clientes simultâneos
- Validação de comandos
- Timeout de conexões inativas
- Logs detalhados de operações

### Recomendações
- Use apenas em contas demo para testes
- Configure firewall adequadamente
- Monitore logs regularmente
- Implemente autenticação adicional se necessário

## Troubleshooting

### Problemas Comuns

1. **Conexão recusada**:
   - Verificar se o EA está rodando
   - Confirmar porta 5557 disponível
   - Verificar configurações de firewall

2. **Timeout de conexão**:
   - Verificar estabilidade da rede
   - Aumentar timeout no cliente
   - Verificar logs do servidor

3. **Comandos não reconhecidos**:
   - Verificar sintaxe dos comandos
   - Confirmar versão do servidor
   - Verificar logs de erro

4. **Dados incompletos**:
   - Verificar conexão com broker
   - Confirmar símbolo disponível
   - Verificar horário de mercado

## Logs e Monitoramento

### Logs do Servidor MT5
- Conexões de clientes
- Comandos processados
- Erros de execução
- Atualizações de dados

### Logs do Cliente Python
- Status de conexão
- Respostas recebidas
- Erros de comunicação
- Resultados de testes

## Desenvolvimento Futuro

### Melhorias Planejadas
- Autenticação de clientes
- Criptografia de dados
- Suporte a múltiplos símbolos
- Interface web de monitoramento
- Integração com bases de dados
- API REST complementar

### Contribuições
Contribuições são bem-vindas! Por favor:
1. Fork o repositório
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## Licença
Este projeto é fornecido "como está" para fins educacionais e de desenvolvimento. Use por sua própria conta e risco.

## Contato
Para suporte técnico ou dúvidas, consulte a documentação ou abra uma issue no repositório.

---

**Última atualização**: 16 de Agosto de 2025
**Versão**: 2.0 - Expandida com funcionalidades avançadas