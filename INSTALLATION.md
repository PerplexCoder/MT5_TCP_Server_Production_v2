# Guia de Instalação - MT5 TCP Server

## Pré-requisitos

### MetaTrader 5
- MetaTrader 5 instalado e configurado
- Conta de trading (demo ou real)
- Permissões para executar Expert Advisors

### Python
- Python 3.7 ou superior
- Bibliotecas necessárias:
  ```bash
  pip install asyncio json socket
  ```

## Instalação do Servidor MT5

### 1. Copiar Arquivos para MT5
1. Abra o MetaEditor (F4 no MT5 ou diretamente)
2. Navegue até a pasta `MQL5\Experts`
3. Copie os seguintes arquivos:
   - `MT5_Server_TCP.mq5`
   - `MT5_Server_TCP_Functions.mqh`

### 2. Compilar o Expert Advisor
1. No MetaEditor, abra `MT5_Server_TCP.mq5`
2. Pressione F7 ou clique em "Compile"
3. Verifique se não há erros de compilação
4. O arquivo `MT5_Server_TCP.ex5` será gerado automaticamente

### 3. Configurar Permissões no MT5
1. No MT5, vá em `Tools > Options > Expert Advisors`
2. Marque as seguintes opções:
   - ✅ Allow automated trading
   - ✅ Allow DLL imports
   - ✅ Allow imports of external experts

### 4. Executar o Servidor
1. No MT5, arraste o EA `MT5_Server_TCP` para um gráfico
2. Configure os parâmetros:
   - **ServerPort**: 5557 (padrão)
   - **MaxClients**: 10 (padrão)
   - **EnableLogging**: true (recomendado)
3. Clique em "OK" para iniciar

## Teste da Instalação

### Executar Cliente de Teste
```bash
python expanded_mt5_test_client.py
```

### Verificar Conexão
O cliente deve exibir:
- ✅ Conexão estabelecida
- ✅ Dados de mercado recebidos
- ✅ Informações da conta
- ✅ Histórico de transações

## Configuração de Rede

### Firewall
Certifique-se de que a porta 5557 está liberada:
```powershell
New-NetFirewallRule -DisplayName "MT5 TCP Server" -Direction Inbound -Protocol TCP -LocalPort 5557 -Action Allow
```

### Acesso Remoto
Para acesso de outras máquinas:
1. Configure o IP do servidor no cliente Python
2. Libere a porta no firewall do servidor
3. Configure o roteador se necessário

## Solução de Problemas

### Servidor não inicia
- Verifique se a porta 5557 não está em uso
- Confirme as permissões do MT5
- Verifique os logs no MT5

### Cliente não conecta
- Teste conectividade: `telnet localhost 5557`
- Verifique firewall
- Confirme se o servidor está rodando

### Erros de trading
- Verifique se automated trading está habilitado
- Confirme saldo suficiente na conta
- Verifique horário de mercado

## Logs e Monitoramento

### Logs do Servidor
- Console do MT5: mensagens em tempo real
- Arquivo de log: `MT5_Server_TCP.log` (se habilitado)

### Logs do Cliente
- Saída do console Python
- Implementar logging personalizado conforme necessário

## Segurança

### Recomendações
- Use apenas em redes confiáveis
- Implemente autenticação se necessário
- Monitore conexões ativas
- Use contas demo para testes

### Limitações
- Máximo 10 clientes simultâneos (configurável)
- Sem criptografia de dados
- Sem autenticação por padrão

## Suporte

Para problemas ou dúvidas:
1. Consulte o README.md
2. Verifique os logs de erro
3. Teste com conta demo primeiro
4. Documente erros específicos para análise