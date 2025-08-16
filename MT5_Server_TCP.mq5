//+------------------------------------------------------------------+
//|                                              MT5_Server_TCP.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "4.00"
#property description "Expert Advisor servidor para comunicação com Python via TCP - VERSÃO SOCKET NATIVA"

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "include\socket-library-mt4-mt5.mqh"

//--- Input parameters
input int    ServerPort = 5557;           // Porta do servidor TCP
input bool   EnableLogging = false;        // Habilitar logging detalhado
input string LogFileName = "MT5_Server_TCP"; // Nome do arquivo de log
input int    ServerTimeout = 1000;        // Timeout do servidor em ms
input bool   EnableHeartbeat = true;      // Habilitar heartbeat
input int    HeartbeatInterval = 30;      // Intervalo de heartbeat em segundos
input int    MaxClients = 10;             // Número máximo de clientes simultâneos

//--- Global variables
string current_symbol;
CTrade trade;
CSymbolInfo symbol_info;
CPositionInfo position_info;
COrderInfo order_info;

// TCP Server variables
ServerSocket *tcp_server = NULL;
ClientSocket *clients[10];  // Array de clientes conectados
int client_count = 0;
bool server_active = false;
datetime last_heartbeat = 0;

// Variáveis para dados de mercado em tempo real
struct MarketData
{
    double bid;          // Preço de venda
    double ask;          // Preço de compra
    double spread;       // Spread em pontos
    datetime timestamp;  // Timestamp do tick
    ulong volume;        // Volume do tick
    double last_price;   // Último preço negociado
};

// Cache de dados de mercado para otimização
MarketData currentMarketData;
MarketData lastMarketData;
bool marketDataChanged = false;
uint lastMarketDataUpdate = 0;
int marketDataUpdateInterval = 1;        // ms

// Buffer circular para histórico de preços (últimos 100 ticks)
MarketData priceHistory[100];
int priceHistoryIndex = 0;
int priceHistoryCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Inicializar array de clientes
    for(int i = 0; i < 10; i++)
    {
        clients[i] = NULL;
    }
    
    // Obter símbolo atual
    current_symbol = Symbol();
    
    // Configurar informações do símbolo
    if(!symbol_info.Name(current_symbol))
    {
        LogMessage("ERRO: Não foi possível obter informações do símbolo " + current_symbol);
        return INIT_FAILED;
    }
    
    // Configurar objeto de negociação
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Inicializar servidor TCP
    bool tcp_init_success = InitializeTCPServer();
    
    LogMessage("MT5 Server TCP iniciado no símbolo: " + current_symbol);
    
    if(tcp_init_success && server_active)
    {
        LogMessage("=== SERVIDOR TCP ATIVO NA PORTA " + IntegerToString(ServerPort) + " ===");
    }
    else
    {
        LogMessage("ERRO: Falha ao inicializar servidor TCP");
        return INIT_FAILED;
    }
    
    // Inicializar dados de mercado
    UpdateMarketData();
    
    // Configurar timer para processamento
    EventSetMillisecondTimer(1); // Timer de 1ms para baixa latência
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    LogMessage("Finalizando MT5 Server TCP...");
    
    // Fechar todas as conexões de clientes
    CloseAllClients();
    
    // Fechar servidor
    if(tcp_server != NULL)
    {
        delete tcp_server;
        tcp_server = NULL;
    }
    
    server_active = false;
    EventKillTimer();
    
    LogMessage("MT5 Server TCP finalizado");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Atualizar dados de mercado
    UpdateMarketData();
    
    // Enviar dados para clientes conectados se houve mudança
    if(marketDataChanged && server_active)
    {
        BroadcastMarketData();
        marketDataChanged = false;
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(!server_active) return;
    
    // Processar conexões TCP
    HandleTCPConnections();
    
    // Processar mensagens dos clientes
    ProcessClientMessages();
    
    // Verificar heartbeat
    if(EnableHeartbeat && TimeCurrent() - last_heartbeat > HeartbeatInterval)
    {
        SendHeartbeat();
        last_heartbeat = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Inicializar servidor TCP                                        |
//+------------------------------------------------------------------+
bool InitializeTCPServer()
{
    LogMessage("=== INICIANDO SERVIDOR TCP ===");
    LogMessage("Porta configurada: " + IntegerToString(ServerPort));
    
    // Criar servidor TCP
    tcp_server = new ServerSocket((ushort)ServerPort, false); // false = aceitar conexões remotas
    
    if(tcp_server == NULL)
    {
        LogMessage("ERRO: Falha ao criar servidor TCP");
        return false;
    }
    
    if(!tcp_server.Created())
    {
        LogMessage("ERRO: Falha ao criar socket do servidor - porta " + IntegerToString(ServerPort) + " pode estar em uso");
        delete tcp_server;
        tcp_server = NULL;
        return false;
    }
    
    server_active = true;
    LogMessage("Servidor TCP criado com sucesso na porta " + IntegerToString(ServerPort));
    LogMessage("Aguardando conexões de clientes...");
    
    return true;
}

//+------------------------------------------------------------------+
//| Processar conexões TCP                                          |
//+------------------------------------------------------------------+
void HandleTCPConnections()
{
    if(!server_active || tcp_server == NULL) return;
    
    // Aceitar novas conexões
    ClientSocket *new_client = tcp_server.Accept();
    if(new_client != NULL)
    {
        if(client_count < MaxClients)
        {
            // Encontrar slot livre
            for(int i = 0; i < MaxClients; i++)
            {
                if(clients[i] == NULL)
                {
                    clients[i] = new_client;
                    client_count++;
                    LogMessage("Cliente conectado [" + IntegerToString(i) + "]. Total de clientes: " + IntegerToString(client_count));
                    
                    // Enviar mensagem de boas-vindas
                    string welcome = "{\"status\":\"connected\",\"server\":\"MT5_TCP_Server\",\"version\":\"4.0\",\"symbol\":\"" + current_symbol + "\"}";
                    new_client.Send(welcome);
                    break;
                }
            }
        }
        else
        {
            LogMessage("Máximo de clientes atingido. Rejeitando conexão.");
            delete new_client;
        }
    }
}

//+------------------------------------------------------------------+
//| Processar mensagens dos clientes                                |
//+------------------------------------------------------------------+
void ProcessClientMessages()
{
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i] == NULL) continue;
        
        // Verificar se cliente ainda está conectado
        if(!clients[i].IsSocketConnected())
        {
            LogMessage("Cliente [" + IntegerToString(i) + "] desconectado");
            delete clients[i];
            clients[i] = NULL;
            client_count--;
            continue;
        }
        
        // Receber mensagens
        string message = clients[i].Receive();
        if(message != "")
        {
            LogMessage("Mensagem recebida do cliente [" + IntegerToString(i) + "]: " + message);
            
            // Processar comando
            string response = ProcessCommand(message);
            if(response != "")
            {
                clients[i].Send(response);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Processar comando recebido                                      |
//+------------------------------------------------------------------+
string ProcessCommand(string command)
{
    // Parse do comando JSON
    if(StringFind(command, "ping") >= 0 || StringFind(command, "PING") >= 0)
    {
        return "{\"action\":\"pong\",\"timestamp\":\"" + TimeToString(TimeCurrent()) + "\",\"server_time\":" + IntegerToString(TimeCurrent()) + "}";
    }
    else if(StringFind(command, "market_data") >= 0)
    {
        return GetMarketDataJSON();
    }
    else if(StringFind(command, "account_info") >= 0)
    {
        return GetAccountInfoJSON();
    }
    else if(StringFind(command, "positions") >= 0)
    {
        return GetPositionsJSON();
    }
    else if(StringFind(command, "orders") >= 0)
    {
        return GetOrdersJSON();
    }
    else if(StringFind(command, "place_order") >= 0)
    {
        return ProcessPlaceOrder(command);
    }
    else if(StringFind(command, "place_pending_order") >= 0)
    {
        return ProcessPlacePendingOrder(command);
    }
    else if(StringFind(command, "close_position") >= 0)
    {
        return ProcessClosePosition(command);
    }
    else if(StringFind(command, "history") >= 0)
    {
        return GetHistoryJSON();
    }
    
    // Comando não reconhecido
    return "{\"error\":\"Comando não reconhecido\",\"received\":\"" + command + "\"}";
}

//+------------------------------------------------------------------+
//| Atualizar dados de mercado                                      |
//+------------------------------------------------------------------+
void UpdateMarketData()
{
    // Salvar dados anteriores
    lastMarketData = currentMarketData;
    
    // Obter novos dados
    currentMarketData.bid = SymbolInfoDouble(current_symbol, SYMBOL_BID);
    currentMarketData.ask = SymbolInfoDouble(current_symbol, SYMBOL_ASK);
    currentMarketData.spread = (currentMarketData.ask - currentMarketData.bid) / SymbolInfoDouble(current_symbol, SYMBOL_POINT);
    currentMarketData.timestamp = TimeCurrent();
    currentMarketData.volume = SymbolInfoInteger(current_symbol, SYMBOL_VOLUME);
    currentMarketData.last_price = SymbolInfoDouble(current_symbol, SYMBOL_LAST);
    
    // Verificar se houve mudança
    if(currentMarketData.bid != lastMarketData.bid || 
       currentMarketData.ask != lastMarketData.ask ||
       currentMarketData.volume != lastMarketData.volume)
    {
        marketDataChanged = true;
        
        // Adicionar ao histórico
        priceHistory[priceHistoryIndex] = currentMarketData;
        priceHistoryIndex = (priceHistoryIndex + 1) % 100;
        if(priceHistoryCount < 100) priceHistoryCount++;
    }
}

//+------------------------------------------------------------------+
//| Transmitir dados de mercado para todos os clientes             |
//+------------------------------------------------------------------+
void BroadcastMarketData()
{
    string market_data = GetMarketDataJSON();
    
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i] != NULL && clients[i].IsSocketConnected())
        {
            clients[i].Send(market_data);
        }
    }
}

//+------------------------------------------------------------------+
//| Obter dados de mercado em formato JSON                         |
//+------------------------------------------------------------------+
string GetMarketDataJSON()
{
    string json = "{";
    json += "\"action\":\"market_data\",";
    json += "\"data\":{";
    json += "\"symbol\":\"" + current_symbol + "\",";
    json += "\"bid\":" + DoubleToString(currentMarketData.bid, Digits()) + ",";
    json += "\"ask\":" + DoubleToString(currentMarketData.ask, Digits()) + ",";
    json += "\"spread\":" + DoubleToString(currentMarketData.spread, 1) + ",";
    json += "\"last\":" + DoubleToString(currentMarketData.last_price, Digits()) + ",";
    json += "\"volume\":" + IntegerToString(currentMarketData.volume) + ",";
    json += "\"time\":\"" + TimeToString(currentMarketData.timestamp, TIME_DATE|TIME_SECONDS) + "\",";
    json += "\"digits\":" + IntegerToString(Digits()) + ",";
    json += "\"point\":" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_POINT), 8) + ",";
    json += "\"tick_size\":" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE), 8) + ",";
    json += "\"min_lot\":" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_MIN), 2) + ",";
    json += "\"max_lot\":" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_MAX), 2) + ",";
    json += "\"lot_step\":" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_STEP), 2);
    json += "}}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Obter informações da conta em formato JSON                     |
//+------------------------------------------------------------------+
string GetAccountInfoJSON()
{
    string json = "{";
    json += "\"action\":\"account_info\",";
    json += "\"data\":{";
    json += "\"login\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ",";
    json += "\"name\":\"" + AccountInfoString(ACCOUNT_NAME) + "\",";
    json += "\"server\":\"" + AccountInfoString(ACCOUNT_SERVER) + "\",";
    json += "\"currency\":\"" + AccountInfoString(ACCOUNT_CURRENCY) + "\",";
    json += "\"balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
    json += "\"equity\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + ",";
    json += "\"profit\":" + DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2) + ",";
    json += "\"margin\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + ",";
    json += "\"margin_free\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + ",";
    json += "\"margin_level\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2) + ",";
    json += "\"leverage\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)) + ",";
    json += "\"trade_allowed\":" + (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "true" : "false") + ",";
    json += "\"trade_expert\":" + (AccountInfoInteger(ACCOUNT_TRADE_EXPERT) ? "true" : "false") + ",";
    json += "\"margin_so_mode\":" + IntegerToString(AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)) + ",";
    json += "\"margin_so_call\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL), 2) + ",";
    json += "\"margin_so_so\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 2) + ",";
    json += "\"margin_initial\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_INITIAL), 2) + ",";
    json += "\"margin_maintenance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_MAINTENANCE), 2) + ",";
    json += "\"assets\":" + DoubleToString(AccountInfoDouble(ACCOUNT_ASSETS), 2) + ",";
    json += "\"liabilities\":" + DoubleToString(AccountInfoDouble(ACCOUNT_LIABILITIES), 2) + ",";
    json += "\"commission_blocked\":" + DoubleToString(AccountInfoDouble(ACCOUNT_COMMISSION_BLOCKED), 2);
    json += "}}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Obter histórico de transações em formato JSON                  |
//+------------------------------------------------------------------+
string GetHistoryJSON(datetime from_date = 0, datetime to_date = 0)
{
    if(from_date == 0) from_date = TimeCurrent() - 86400 * 30; // Últimos 30 dias
    if(to_date == 0) to_date = TimeCurrent();
    
    if(!HistorySelect(from_date, to_date))
    {
        return "{\"action\":\"history\",\"error\":\"Failed to select history\"}";
    }
    
    string json = "{";
    json += "\"action\":\"history\",";
    json += "\"data\":{";
    json += "\"from\":\"" + TimeToString(from_date, TIME_DATE|TIME_SECONDS) + "\",";
    json += "\"to\":\"" + TimeToString(to_date, TIME_DATE|TIME_SECONDS) + "\",";
    json += "\"deals\":[";
    
    int total_deals = HistoryDealsTotal();
    for(int i = 0; i < total_deals && i < 100; i++) // Limitar a 100 deals
    {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if(deal_ticket > 0)
        {
            if(i > 0) json += ",";
            json += "{";
            json += "\"ticket\":" + IntegerToString(deal_ticket) + ",";
            json += "\"order\":" + IntegerToString(HistoryDealGetInteger(deal_ticket, DEAL_ORDER)) + ",";
            json += "\"time\":\"" + TimeToString((datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME), TIME_DATE|TIME_SECONDS) + "\",";
            json += "\"type\":" + IntegerToString(HistoryDealGetInteger(deal_ticket, DEAL_TYPE)) + ",";
            json += "\"entry\":" + IntegerToString(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY)) + ",";
            json += "\"symbol\":\"" + HistoryDealGetString(deal_ticket, DEAL_SYMBOL) + "\",";
            json += "\"volume\":" + DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_VOLUME), 2) + ",";
            json += "\"price\":" + DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_PRICE), Digits()) + ",";
            json += "\"commission\":" + DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION), 2) + ",";
            json += "\"swap\":" + DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_SWAP), 2) + ",";
            json += "\"profit\":" + DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_PROFIT), 2) + ",";
            json += "\"comment\":\"" + HistoryDealGetString(deal_ticket, DEAL_COMMENT) + "\"";
            json += "}";
        }
    }
    
    json += "],";
    json += "\"orders\":[";
    
    int total_orders = HistoryOrdersTotal();
    for(int i = 0; i < total_orders && i < 100; i++) // Limitar a 100 orders
    {
        ulong order_ticket = HistoryOrderGetTicket(i);
        if(order_ticket > 0)
        {
            if(i > 0) json += ",";
            json += "{";
            json += "\"ticket\":" + IntegerToString(order_ticket) + ",";
            json += "\"time_setup\":\"" + TimeToString((datetime)HistoryOrderGetInteger(order_ticket, ORDER_TIME_SETUP), TIME_DATE|TIME_SECONDS) + "\",";
            json += "\"time_done\":\"" + TimeToString((datetime)HistoryOrderGetInteger(order_ticket, ORDER_TIME_DONE), TIME_DATE|TIME_SECONDS) + "\",";
            json += "\"type\":" + IntegerToString(HistoryOrderGetInteger(order_ticket, ORDER_TYPE)) + ",";
            json += "\"state\":" + IntegerToString(HistoryOrderGetInteger(order_ticket, ORDER_STATE)) + ",";
            json += "\"symbol\":\"" + HistoryOrderGetString(order_ticket, ORDER_SYMBOL) + "\",";
            json += "\"volume_initial\":" + DoubleToString(HistoryOrderGetDouble(order_ticket, ORDER_VOLUME_INITIAL), 2) + ",";
            json += "\"volume_current\":" + DoubleToString(HistoryOrderGetDouble(order_ticket, ORDER_VOLUME_CURRENT), 2) + ",";
            json += "\"price_open\":" + DoubleToString(HistoryOrderGetDouble(order_ticket, ORDER_PRICE_OPEN), Digits()) + ",";
            json += "\"sl\":" + DoubleToString(HistoryOrderGetDouble(order_ticket, ORDER_SL), Digits()) + ",";
            json += "\"tp\":" + DoubleToString(HistoryOrderGetDouble(order_ticket, ORDER_TP), Digits()) + ",";
            json += "\"comment\":\"" + HistoryOrderGetString(order_ticket, ORDER_COMMENT) + "\"";
            json += "}";
        }
    }
    
    json += "]}}";
    return json;
}

//+------------------------------------------------------------------+
//| Obter posições em formato JSON                                 |
//+------------------------------------------------------------------+
string GetPositionsJSON()
{
    string json = "{\"action\":\"positions\",\"data\":[";
    
    bool first = true;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position_info.SelectByIndex(i))
        {
            if(!first) json += ",";
            
            json += "{";
            json += "\"ticket\":" + IntegerToString(position_info.Ticket()) + ",";
            json += "\"symbol\":\"" + position_info.Symbol() + "\",";
            json += "\"type\":" + IntegerToString(position_info.PositionType()) + ",";
            json += "\"volume\":" + DoubleToString(position_info.Volume(), 2) + ",";
            json += "\"price_open\":" + DoubleToString(position_info.PriceOpen(), Digits()) + ",";
            json += "\"price_current\":" + DoubleToString(position_info.PriceCurrent(), Digits()) + ",";
            json += "\"profit\":" + DoubleToString(position_info.Profit(), 2) + ",";
            json += "\"swap\":" + DoubleToString(position_info.Swap(), 2) + ",";
            json += "\"comment\":\"" + position_info.Comment() + "\"";
            json += "}";
            
            first = false;
        }
    }
    
    json += "]}";
    return json;
}

//+------------------------------------------------------------------+
//| Obter ordens em formato JSON                                   |
//+------------------------------------------------------------------+
string GetOrdersJSON()
{
    string json = "{\"action\":\"orders\",\"data\":[";
    
    bool first = true;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(order_info.SelectByIndex(i))
        {
            if(!first) json += ",";
            
            json += "{";
            json += "\"ticket\":" + IntegerToString(order_info.Ticket()) + ",";
            json += "\"symbol\":\"" + order_info.Symbol() + "\",";
            json += "\"type\":" + IntegerToString(order_info.OrderType()) + ",";
            json += "\"volume\":" + DoubleToString(order_info.VolumeInitial(), 2) + ",";
            json += "\"price_open\":" + DoubleToString(order_info.PriceOpen(), Digits()) + ",";
            json += "\"price_current\":" + DoubleToString(order_info.PriceCurrent(), Digits()) + ",";
            json += "\"comment\":\"" + order_info.Comment() + "\"";
            json += "}";
            
            first = false;
        }
    }
    
    json += "]}";
    return json;
}

//+------------------------------------------------------------------+
//| Enviar heartbeat para todos os clientes                        |
//+------------------------------------------------------------------+
void SendHeartbeat()
{
    string heartbeat = "{\"action\":\"heartbeat\",\"timestamp\":" + IntegerToString(TimeCurrent()) + ",\"clients\":" + IntegerToString(client_count) + "}";
    
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i] != NULL && clients[i].IsSocketConnected())
        {
            clients[i].Send(heartbeat);
        }
    }
}

//+------------------------------------------------------------------+
//| Fechar todas as conexões de clientes                           |
//+------------------------------------------------------------------+
void CloseAllClients()
{
    for(int i = 0; i < MaxClients; i++)
    {
        if(clients[i] != NULL)
        {
            delete clients[i];
            clients[i] = NULL;
        }
    }
    client_count = 0;
}

//+------------------------------------------------------------------+
//| Processar ordem a mercado                                       |
//+------------------------------------------------------------------+
string ProcessPlaceOrder(string command)
{
    // Extrair parâmetros do comando JSON (implementação simplificada)
    string symbol = "EURUSD"; // Default
    double volume = 0.01;
    ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
    string comment = "MT5 TCP Order";
    
    // Parse básico do JSON (pode ser melhorado)
    if(StringFind(command, "sell") >= 0) order_type = ORDER_TYPE_SELL;
    if(StringFind(command, "GBPUSD") >= 0) symbol = "GBPUSD";
    if(StringFind(command, "USDJPY") >= 0) symbol = "USDJPY";
    if(StringFind(command, "XAUUSD") >= 0) symbol = "XAUUSD";
    
    // Executar ordem
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);
    
    bool result = false;
    if(order_type == ORDER_TYPE_BUY)
    {
        result = trade.Buy(volume, symbol, 0, 0, 0, comment);
    }
    else
    {
        result = trade.Sell(volume, symbol, 0, 0, 0, comment);
    }
    
    string json = "{";
    json += "\"action\":\"place_order\",";
    json += "\"success\":" + (result ? "true" : "false") + ",";
    
    if(result)
    {
        json += "\"ticket\":" + IntegerToString(trade.ResultOrder()) + ",";
        json += "\"price\":" + DoubleToString(trade.ResultPrice(), Digits()) + ",";
        json += "\"volume\":" + DoubleToString(volume, 2) + ",";
        json += "\"symbol\":\"" + symbol + "\"";
    }
    else
    {
        json += "\"error\":\"" + trade.ResultComment() + "\",";
        json += "\"error_code\":" + IntegerToString(trade.ResultRetcode());
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Processar ordem pendente                                        |
//+------------------------------------------------------------------+
string ProcessPlacePendingOrder(string command)
{
    string symbol = "EURUSD";
    double volume = 0.01;
    ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY_LIMIT;
    double price = 0;
    string comment = "MT5 TCP Pending Order";
    
    // Parse básico do JSON
    if(StringFind(command, "sell_limit") >= 0) order_type = ORDER_TYPE_SELL_LIMIT;
    if(StringFind(command, "buy_stop") >= 0) order_type = ORDER_TYPE_BUY_STOP;
    if(StringFind(command, "sell_stop") >= 0) order_type = ORDER_TYPE_SELL_STOP;
    
    // Definir preço baseado no tipo de ordem
    double current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if(order_type == ORDER_TYPE_BUY_LIMIT)
        price = current_price - 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    else if(order_type == ORDER_TYPE_SELL_LIMIT)
        price = current_price + 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    else if(order_type == ORDER_TYPE_BUY_STOP)
        price = current_price + 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    else if(order_type == ORDER_TYPE_SELL_STOP)
        price = current_price - 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    trade.SetExpertMagicNumber(123456);
    bool result = trade.OrderOpen(symbol, order_type, volume, 0, price, 0, 0, ORDER_TIME_GTC, 0, comment);
    
    string json = "{";
    json += "\"action\":\"place_pending_order\",";
    json += "\"success\":" + (result ? "true" : "false") + ",";
    
    if(result)
    {
        json += "\"ticket\":" + IntegerToString(trade.ResultOrder()) + ",";
        json += "\"price\":" + DoubleToString(price, Digits()) + ",";
        json += "\"volume\":" + DoubleToString(volume, 2) + ",";
        json += "\"symbol\":\"" + symbol + "\",";
        json += "\"type\":" + IntegerToString(order_type);
    }
    else
    {
        json += "\"error\":\"" + trade.ResultComment() + "\",";
        json += "\"error_code\":" + IntegerToString(trade.ResultRetcode());
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Processar fechamento de posição                                 |
//+------------------------------------------------------------------+
string ProcessClosePosition(string command)
{
    // Extrair ticket da posição (implementação simplificada)
    ulong ticket = 0;
    
    // Parse básico para extrair ticket
    int start = StringFind(command, "ticket");
    if(start >= 0)
    {
        start = StringFind(command, ":", start) + 1;
        int end = StringFind(command, ",", start);
        if(end < 0) end = StringFind(command, "}", start);
        if(end > start)
        {
            string ticket_str = StringSubstr(command, start, end - start);
            StringTrimLeft(ticket_str);
            StringTrimRight(ticket_str);
            ticket = StringToInteger(ticket_str);
        }
    }
    
    bool result = false;
    double profit = 0;
    
    if(ticket > 0 && position_info.SelectByTicket(ticket))
    {
        profit = position_info.Profit();
        result = trade.PositionClose(ticket);
    }
    
    string json = "{";
    json += "\"action\":\"close_position\",";
    json += "\"success\":" + (result ? "true" : "false") + ",";
    json += "\"ticket\":" + IntegerToString(ticket) + ",";
    
    if(result)
    {
        json += "\"profit\":" + DoubleToString(profit, 2);
    }
    else
    {
        json += "\"error\":\"" + (ticket == 0 ? "Ticket inválido" : trade.ResultComment()) + "\",";
        json += "\"error_code\":" + IntegerToString(trade.ResultRetcode());
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Função de logging                                               |
//+------------------------------------------------------------------+
void LogMessage(string message)
{
    if(EnableLogging)
    {
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
        string log_msg = "[" + timestamp + "] " + message;
        Print(log_msg);
        
        // Salvar em arquivo se especificado
        if(LogFileName != "")
        {
            int file_handle = FileOpen(LogFileName + ".log", FILE_WRITE|FILE_TXT|FILE_ANSI, "\t");
            if(file_handle != INVALID_HANDLE)
            {
                FileSeek(file_handle, 0, SEEK_END);
                FileWriteString(file_handle, log_msg + "\r\n");
                FileClose(file_handle);
            }
        }
    }
}