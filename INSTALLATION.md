# Guia de Instalação - MT5 TCP Server

**Versão:** 2.00  
**Autor:** PerplexCoder  
**Copyright:** 2025, PerplexCoder  
**Data:** Janeiro 2025

## Pré-requisitos

### Software Necessário
- MetaTrader 5 (versão mais recente)
- Python 3.8 ou superior
- Windows 10/11 (recomendado)

### Bibliotecas Python
```bash
pip install socket
pip install json
pip install threading
pip install datetime
pip install logging
```

## Instalação do Servidor MT5

### 1. Preparação do Ambiente

1. **Abra o MetaEditor**
   - Caminho: `D:\mt5_xp\MetaEditor64.exe`
   - Ou através do MetaTrader 5: Ferramentas → MetaQuotes Language Editor

2. **Crie uma nova pasta no diretório de Expert Advisors**
   ```
   %APPDATA%\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Experts\MT5_TCP_Server
   ```

### 2. Instalação dos Arquivos

1. **Copie os arquivos principais:**
   - `MT5_Server_TCP.mq5` → pasta `Experts/MT5_TCP_Server/`
   - `MT5_Server_TCP_Functions.mqh` → pasta `Include/` ou `Experts/MT5_TCP_Server/`

2. **Compile o Expert Advisor:**
   - Abra `MT5_Server_TCP.mq5` no MetaEditor
   - Pressione F7 ou clique em "Compile"
   - Verifique se não há erros de compilação

### 3. Configuração do MetaTrader 5

1. **Habilite o AutoTrading:**
   - No MT5, clique no botão "AutoTrading" na barra de ferramentas
   - Certifique-se de que está ativo (verde)

2. **Configurações de Segurança:**
   - Vá em Ferramentas → Opções → Expert Advisors
   - Marque "Permitir trading automatizado"
   - Marque "Permitir importação de DLL"
   - Marque "Permitir importação de funções externas"

3. **Configurações de Rede:**
   - Vá em Ferramentas → Opções → Expert Advisors
   - Marque "Permitir conexões WebRequest para URLs listadas"
   - Adicione: `http://localhost:*`

## Configuração do Cliente Python

### 1. Preparação do Ambiente Python

1. **Instale as dependências:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure o arquivo config.ini:**
   - Edite as configurações de servidor (IP, porta)
   - Ajuste os parâmetros de trading conforme necessário
   - Configure os símbolos que deseja monitorar

### 2. Estrutura de Arquivos
```
MT5_TCP_Server_Production/
├── MT5_Server_TCP.mq5
├── MT5_Server_TCP_Functions.mqh
├── expanded_mt5_test_client.py
├── config.ini
├── README.md
├── INSTALLATION.md
├── setup.bat
└── .gitignore
```

## Configuração Inicial

### 1. Configuração do Servidor

1. **Anexe o Expert Advisor ao gráfico:**
   - Abra um gráfico no MT5
   - Arraste `MT5_Server_TCP` da janela Navigator para o gráfico
   - Configure os parâmetros na aba "Inputs"

2. **Parâmetros Principais:**
   ```
   ServerPort = 9090          // Porta do servidor TCP
   MaxClients = 10            // Máximo de clientes simultâneos
   EnableLogging = true       // Habilitar logs
   LogLevel = 2               // Nível de log (0-3)
   ```

### 2. Configuração do Cliente

1. **Edite o config.ini:**
   ```ini
   [SERVER]
   host = localhost
   port = 9090
   timeout = 30
   
   [TRADING]
   default_lot = 0.01
   max_lot = 1.0
   slippage = 3
   ```

2. **Execute o cliente de teste:**
   ```bash
   python expanded_mt5_test_client.py
   ```

## Verificação da Instalação

### 1. Teste de Conectividade

1. **Inicie o servidor MT5:**
   - Anexe o EA ao gráfico
   - Verifique os logs na aba "Experts"
   - Procure por: "TCP Server iniciado na porta 9090"

2. **Teste a conexão do cliente:**
   ```python
   python expanded_mt5_test_client.py
   ```

3. **Comandos de teste básicos:**
   - `GET_ACCOUNT_INFO` - Informações da conta
   - `GET_SYMBOLS` - Lista de símbolos
   - `GET_MARKET_DATA:EURUSD` - Dados de mercado

### 2. Resolução de Problemas

#### Erro: "Porta já em uso"
- Verifique se outro EA está usando a mesma porta
- Altere a porta no parâmetro `ServerPort`
- Reinicie o MetaTrader 5

#### Erro: "Conexão recusada"
- Verifique se o firewall está bloqueando a porta
- Certifique-se de que o EA está ativo no gráfico
- Verifique os logs do MT5

#### Erro: "Trading não permitido"
- Habilite o AutoTrading no MT5
- Verifique as configurações de Expert Advisors
- Certifique-se de que a conta permite trading automatizado

## Configurações Avançadas

### 1. Configuração de Firewall

**Windows Defender:**
```cmd
netsh advfirewall firewall add rule name="MT5 TCP Server" dir=in action=allow protocol=TCP localport=9090
```

### 2. Configuração para Produção

1. **Altere a porta padrão:**
   - Use uma porta não padrão (ex: 8765)
   - Configure SSL/TLS se necessário

2. **Configurações de segurança:**
   - Limite o número de conexões simultâneas
   - Implemente autenticação se necessário
   - Configure logs detalhados

### 3. Monitoramento

1. **Logs do servidor:**
   - Localização: `%APPDATA%\MetaQuotes\Terminal\[ID]\MQL5\Logs\`
   - Arquivo: `YYYYMMDD.log`

2. **Logs do cliente:**
   - Configurados no `config.ini`
   - Arquivo: `mt5_client.log`

## Backup e Manutenção

### 1. Backup dos Arquivos
```bash
# Execute o setup.bat para backup automático
setup.bat backup
```

### 2. Atualização
1. Faça backup dos arquivos atuais
2. Substitua os arquivos pelos novos
3. Recompile o Expert Advisor
4. Teste a conectividade

## Suporte

Para suporte técnico:
- Verifique os logs de erro
- Consulte a documentação no README.md
- Reporte problemas com logs detalhados

---

**Nota:** Este guia assume uma instalação padrão do MetaTrader 5. Ajuste os caminhos conforme sua configuração específica.

**Última atualização:** Janeiro 2025  
**Versão do documento:** 2.00