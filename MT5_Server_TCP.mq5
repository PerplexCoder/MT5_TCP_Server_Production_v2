//+------------------------------------------------------------------+
//|                                           MT5_Server_TCP.mq5 |
//|                                    Copyright 2025, PerplexCoder |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, PerplexCoder"
#property link      ""
#property version   "2.00"
#property description "MT5 TCP Server - Versão de Produção"
#property description "Servidor TCP para comunicação com aplicações externas"
#property description "Suporte a múltiplos clientes e comandos de trading"

//--- Includes
#include "MT5_Server_TCP_Functions.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Parâmetros de entrada
input string ServerIP = "127.0.0.1";           // IP do servidor
input int ServerPort = 9090;                    // Porta do servidor
input int MaxClients = 10;                      // Máximo de clientes simultâneos
input string TradingSymbol = "EURUSD";          // Símbolo para trading
input bool EnableLogging = true;                // Habilitar logs detalhados
input int UpdateInterval = 100;                 // Intervalo de atualização (ms)
input ulong MagicNumber = 123456;               // Número mágico para ordens
input bool AutoReconnect = true;                // Reconexão automática
input int ReconnectDelay = 5000;                // Delay para reconexão (ms)

//--- Estruturas globais
struct MarketData
{
    double bid;
    double ask;
    double spread;
    double last_price;
    long volume;
    datetime timestamp;
};

struct ClientInfo
{
    int socket;
    string ip_address;
    datetime connect_time;
    datetime last_activity;
    bool is_active;
    string last_command;
};

//--- Variáveis globais
int server_socket = INVALID_HANDLE;
ClientInfo clients[10];  // Array de clientes
int active_clients = 0;
string current_symbol;
MarketData currentMarketData;
bool server_running = false;
datetime last_tick_time = 0;
int reconnect_attempts = 0;
const int MAX_RECONNECT_ATTEMPTS = 5;

//--- Objetos de trading
CTrade trade;
CSymbolInfo symbol_info;
CPositionInfo position_info;
COrderInfo order_info;

//+------------------------------------------------------------------+
//| Função de inicialização do Expert Advisor                      |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== MT5 TCP Server v2.00 - Iniciando ===");
    
    // Configurar símbolo
    current_symbol = TradingSymbol;
    if(!SymbolSelect(current_symbol, true))
    {
        Print("ERRO: Não foi possível selecionar o símbolo: ", current_symbol);
        return INIT_FAILED;
    }
    
    // Configurar objetos de trading
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    if(!symbol_info.Name(current_symbol))
    {
        Print("ERRO: Falha ao inicializar informações do símbolo: ", current_symbol);
        return INIT_FAILED;
    }
    
    // Inicializar array de clientes
    InitializeClients();
    
    // Inicializar dados de mercado
    UpdateMarketData();
    
    // Iniciar servidor TCP
    if(!StartTCPServer())
    {
        Print("ERRO: Falha ao iniciar servidor TCP");
        return INIT_FAILED;
    }
    
    Print("Servidor TCP iniciado com sucesso em ", ServerIP, ":", ServerPort);
    Print("Símbolo configurado: ", current_symbol);
    Print("Magic Number: ", MagicNumber);
    Print("Máximo de clientes: ", MaxClients);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função de desinicialização                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Finalizando MT5 TCP Server ===");
    
    // Desconectar todos os clientes
    DisconnectAllClients();
    
    // Fechar servidor
    StopTCPServer();
    
    string reason_text = "";
    switch(reason)
    {
        case REASON_PROGRAM: reason_text = "Expert removido do gráfico"; break;
        case REASON_REMOVE: reason_text = "Expert deletado"; break;
        case REASON_RECOMPILE: reason_text = "Expert recompilado"; break;
        case REASON_CHARTCHANGE: reason_text = "Mudança de símbolo ou timeframe"; break;
        case REASON_CHARTCLOSE: reason_text = "Gráfico fechado"; break;
        case REASON_PARAMETERS: reason_text = "Parâmetros alterados"; break;
        case REASON_ACCOUNT: reason_text = "Conta alterada"; break;
        case REASON_TEMPLATE: reason_text = "Template aplicado"; break;
        case REASON_INITFAILED: reason_text = "Falha na inicialização"; break;
        case REASON_CLOSE: reason_text = "Terminal fechado"; break;
        default: reason_text = "Motivo desconhecido (" + IntegerToString(reason) + ")"; break;
    }
    
    Print("Motivo da finalização: ", reason_text);
    Print("Servidor TCP finalizado.");
}

//+------------------------------------------------------------------+
//| Função principal - chamada a cada tick                         |
//+------------------------------------------------------------------+
void OnTick()
{
    // Atualizar dados de mercado
    UpdateMarketData();
    
    // Verificar conexões de clientes
    CheckClientConnections();
    
    // Processar comandos de clientes
    ProcessClientCommands();
    
    // Verificar se servidor precisa ser reiniciado
    if(!server_running && AutoReconnect)
    {
        CheckServerReconnection();
    }
}

//+------------------------------------------------------------------+
//| Função de timer                                                |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Verificar status do servidor
    if(!server_running)
    {
        if(EnableLogging)
            Print("Timer: Servidor não está rodando");
        return;
    }
    
    // Atualizar dados de mercado
    UpdateMarketData();
    
    // Verificar timeout de clientes
    CheckClientTimeouts();
    
    // Enviar heartbeat para clientes ativos
    SendHeartbeatToClients();
}

//+------------------------------------------------------------------+
//| Inicializar servidor TCP                                       |
//+------------------------------------------------------------------+
bool StartTCPServer()
{
    // Fechar servidor existente se houver
    if(server_socket != INVALID_HANDLE)
    {
        SocketClose(server_socket);
        server_socket = INVALID_HANDLE;
    }
    
    // Criar socket do servidor
    server_socket = SocketCreate();
    if(server_socket == INVALID_HANDLE)
    {
        Print("ERRO: Falha ao criar socket do servidor. Erro: ", GetLastError());
        return false;
    }
    
    // Configurar socket para não bloquear
    if(!SocketSetOption(server_socket, SOCKET_OPTION_NONBLOCK, 1))
    {
        Print("ERRO: Falha ao configurar socket não-bloqueante. Erro: ", GetLastError());
        SocketClose(server_socket);
        server_socket = INVALID_HANDLE;
        return false;
    }
    
    // Bind do socket
    if(!SocketBind(server_socket, ServerIP, ServerPort))
    {
        Print("ERRO: Falha no bind do socket. IP: ", ServerIP, " Porta: ", ServerPort, " Erro: ", GetLastError());
        SocketClose(server_socket);
        server_socket = INVALID_HANDLE;
        return false;
    }
    
    // Colocar socket em modo de escuta
    if(!SocketListen(server_socket, MaxClients))
    {
        Print("ERRO: Falha ao colocar socket em modo de escuta. Erro: ", GetLastError());
        SocketClose(server_socket);
        server_socket = INVALID_HANDLE;
        return false;
    }
    
    server_running = true;
    reconnect_attempts = 0;
    
    // Configurar timer
    EventSetTimer(1); // Timer a cada segundo
    
    if(EnableLogging)
        Print("Servidor TCP iniciado com sucesso em ", ServerIP, ":", ServerPort);
    
    return true;
}

//+------------------------------------------------------------------+
//| Parar servidor TCP                                             |
//+------------------------------------------------------------------+
void StopTCPServer()
{
    server_running = false;
    
    if(server_socket != INVALID_HANDLE)
    {
        SocketClose(server_socket);
        server_socket = INVALID_HANDLE;
        if(EnableLogging)
            Print("Servidor TCP fechado");
    }
    
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Inicializar array de clientes                                  |
//+------------------------------------------------------------------+
void InitializeClients()
{
    for(int i = 0; i < MaxClients; i++)
    {
        clients[i].socket = INVALID_HANDLE;
        clients[i].ip_address = "";
        clients[i].connect_time = 0;
        clients[i].last_activity = 0;
        clients[i].is_active = false;
        clients[i].last_command = "";
    }
    active_clients = 0;
}

//+------------------------------------------------------------------+
//| Verificar conexões de clientes                                 |
//+------------------------------------------------------------------+
void CheckClientConnections()
{
    if(!server_running || server_socket == INVALID_HANDLE)
        return;
    
    // Aceitar novas conexões
    int client_socket = SocketAccept(server_socket, 0);
    if(client_socket != INVALID_HANDLE)
    {
        // Encontrar slot livre para o cliente
        int free_slot = FindFreeClientSlot();
        if(free_slot >= 0)
        {
            clients[free_slot].socket = client_socket;
            clients[free_slot].ip_address = "Cliente_" + IntegerToString(free_slot);
            clients[free_slot].connect_time = TimeCurrent();
            clients[free_slot].last_activity = TimeCurrent();
            clients[free_slot].is_active = true;
            clients[free_slot].last_command = "";
            
            active_clients++;
            
            // Configurar socket do cliente para não bloquear
            SocketSetOption(client_socket, SOCKET_OPTION_NONBLOCK, 1);
            
            if(EnableLogging)
                Print("Novo cliente conectado no slot ", free_slot, ". Total de clientes: ", active_clients);
            
            // Enviar mensagem de boas-vindas
            string welcome_msg = CreateWelcomeMessage();
            SendToClient(free_slot, welcome_msg);
        }
        else
        {
            // Não há slots livres, fechar conexão
            SocketClose(client_socket);
            if(EnableLogging)
                Print("Conexão rejeitada - máximo de clientes atingido");
        }
    }
}

//+------------------------------------------------------------------+
//| Encontrar slot livre para cliente                              |
//+------------------------------------------------------------------+
int FindFreeClientSlot()
{
    for(int i = 0; i < MaxClients; i++)
    {
        if(!clients[i].is_active)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Processar comandos de clientes                                 |
//+------------------------------------------------------------------+
void ProcessClientCommands()
{
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i].is_active && clients[i].socket != INVALID_HANDLE)
        {
            string received_data = "";
            int bytes_received = SocketReceive(clients[i].socket, received_data, 1024, 0);
            
            if(bytes_received > 0)
            {
                clients[i].last_activity = TimeCurrent();
                clients[i].last_command = received_data;
                
                if(EnableLogging)
                    Print("Cliente ", i, " enviou: ", received_data);
                
                // Processar comando
                string response = ProcessCommand(received_data, i);
                
                // Enviar resposta
                if(StringLen(response) > 0)
                {
                    SendToClient(i, response);
                }
            }
            else if(bytes_received < 0)
            {
                int error = GetLastError();
                if(error != 0 && error != 4014) // 4014 = WSAEWOULDBLOCK (normal para socket não-bloqueante)
                {
                    if(EnableLogging)
                        Print("Erro ao receber dados do cliente ", i, ". Erro: ", error);
                    DisconnectClient(i);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Enviar dados para cliente específico                           |
//+------------------------------------------------------------------+
bool SendToClient(int client_index, string data)
{
    if(client_index < 0 || client_index >= MaxClients)
        return false;
    
    if(!clients[client_index].is_active || clients[client_index].socket == INVALID_HANDLE)
        return false;
    
    // Adicionar terminador de linha se não houver
    if(StringFind(data, "\n") < 0)
        data += "\n";
    
    int bytes_sent = SocketSend(clients[client_index].socket, data, StringLen(data), 0);
    
    if(bytes_sent <= 0)
    {
        if(EnableLogging)
            Print("Falha ao enviar dados para cliente ", client_index, ". Erro: ", GetLastError());
        DisconnectClient(client_index);
        return false;
    }
    
    if(EnableLogging && StringFind(data, "pong") < 0) // Não logar pongs para evitar spam
        Print("Enviado para cliente ", client_index, ": ", StringSubstr(data, 0, MathMin(100, StringLen(data))));
    
    return true;
}

//+------------------------------------------------------------------+
//| Desconectar cliente específico                                 |
//+------------------------------------------------------------------+
void DisconnectClient(int client_index)
{
    if(client_index < 0 || client_index >= MaxClients)
        return;
    
    if(clients[client_index].is_active)
    {
        if(clients[client_index].socket != INVALID_HANDLE)
        {
            SocketClose(clients[client_index].socket);
        }
        
        clients[client_index].socket = INVALID_HANDLE;
        clients[client_index].ip_address = "";
        clients[client_index].connect_time = 0;
        clients[client_index].last_activity = 0;
        clients[client_index].is_active = false;
        clients[client_index].last_command = "";
        
        active_clients--;
        
        if(EnableLogging)
            Print("Cliente ", client_index, " desconectado. Clientes ativos: ", active_clients);
    }
}

//+------------------------------------------------------------------+
//| Desconectar todos os clientes                                  |
//+------------------------------------------------------------------+
void DisconnectAllClients()
{
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i].is_active)
        {
            DisconnectClient(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Verificar timeout de clientes                                  |
//+------------------------------------------------------------------+
void CheckClientTimeouts()
{
    datetime current_time = TimeCurrent();
    const int TIMEOUT_SECONDS = 300; // 5 minutos
    
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i].is_active)
        {
            if(current_time - clients[i].last_activity > TIMEOUT_SECONDS)
            {
                if(EnableLogging)
                    Print("Cliente ", i, " timeout - desconectando");
                DisconnectClient(i);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Enviar heartbeat para clientes ativos                          |
//+------------------------------------------------------------------+
void SendHeartbeatToClients()
{
    static datetime last_heartbeat = 0;
    datetime current_time = TimeCurrent();
    
    // Enviar heartbeat a cada 30 segundos
    if(current_time - last_heartbeat >= 30)
    {
        string heartbeat = CreateHeartbeatMessage();
        
        for(int i = 0; i < MaxClients; i++)
        {
            if(clients[i].is_active)
            {
                SendToClient(i, heartbeat);
            }
        }
        
        last_heartbeat = current_time;
    }
}

//+------------------------------------------------------------------+
//| Atualizar dados de mercado                                     |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
    if(!symbol_info.RefreshRates())
        return;
    
    currentMarketData.bid = symbol_info.Bid();
    currentMarketData.ask = symbol_info.Ask();
    currentMarketData.spread = symbol_info.Spread();
    currentMarketData.last_price = symbol_info.Last();
    currentMarketData.volume = symbol_info.Volume();
    currentMarketData.timestamp = TimeCurrent();
    
    last_tick_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Verificar reconexão do servidor                                |
//+------------------------------------------------------------------+
void CheckServerReconnection()
{
    static datetime last_reconnect_attempt = 0;
    datetime current_time = TimeCurrent();
    
    if(current_time - last_reconnect_attempt >= ReconnectDelay / 1000)
    {
        if(reconnect_attempts < MAX_RECONNECT_ATTEMPTS)
        {
            reconnect_attempts++;
            Print("Tentativa de reconexão ", reconnect_attempts, "/", MAX_RECONNECT_ATTEMPTS);
            
            if(StartTCPServer())
            {
                Print("Reconexão bem-sucedida");
                reconnect_attempts = 0;
            }
            else
            {
                Print("Falha na reconexão ", reconnect_attempts);
            }
        }
        else
        {
            Print("Máximo de tentativas de reconexão atingido. Desabilitando reconexão automática.");
            // Não desabilitar completamente, apenas aguardar mais tempo
            reconnect_attempts = 0;
            last_reconnect_attempt = current_time + 60; // Tentar novamente em 1 minuto
        }
        
        last_reconnect_attempt = current_time;
    }
}

//+------------------------------------------------------------------+
//| Criar mensagem de boas-vindas                                  |
//+------------------------------------------------------------------+
string CreateWelcomeMessage()
{
    string json = "{";
    json += "\"action\":\"welcome\",";
    json += "\"server\":\"MT5 TCP Server v2.00\",";
    json += "\"symbol\":\"" + current_symbol + "\",";
    json += "\"server_time\":" + IntegerToString(TimeCurrent()) + ",";
    json += "\"magic_number\":" + IntegerToString(MagicNumber) + ",";
    json += "\"status\":\"connected\"";
    json += "}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Criar mensagem de heartbeat                                    |
//+------------------------------------------------------------------+
string CreateHeartbeatMessage()
{
    string json = "{";
    json += "\"action\":\"heartbeat\",";
    json += "\"server_time\":" + IntegerToString(TimeCurrent()) + ",";
    json += "\"active_clients\":" + IntegerToString(active_clients) + ",";
    json += "\"market_open\":" + (SymbolInfoInteger(current_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL ? "true" : "false") + ",";
    json += "\"status\":\"ok\"";
    json += "}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Obter status do servidor                                       |
//+------------------------------------------------------------------+
string GetServerStatus()
{
    string json = "{";
    json += "\"action\":\"server_status\",";
    json += "\"data\":{";
    json += "\"server_running\":" + (server_running ? "true" : "false") + ",";
    json += "\"active_clients\":" + IntegerToString(active_clients) + ",";
    json += "\"max_clients\":" + IntegerToString(MaxClients) + ",";
    json += "\"current_symbol\":\"" + current_symbol + "\",";
    json += "\"server_time\":" + IntegerToString(TimeCurrent()) + ",";
    json += "\"last_tick\":" + IntegerToString(last_tick_time) + ",";
    json += "\"magic_number\":" + IntegerToString(MagicNumber) + ",";
    json += "\"auto_reconnect\":" + (AutoReconnect ? "true" : "false") + ",";
    json += "\"reconnect_attempts\":" + IntegerToString(reconnect_attempts) + ",";
    json += "\"market_open\":" + (SymbolInfoInteger(current_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL ? "true" : "false") + ",";
    json += "\"account_balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
    json += "\"account_equity\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + ",";
    json += "\"positions_total\":" + IntegerToString(PositionsTotal()) + ",";
    json += "\"orders_total\":" + IntegerToString(OrdersTotal());
    json += "}}";
    
    return json;
}

//+------------------------------------------------------------------+