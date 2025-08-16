//+------------------------------------------------------------------+
//|                                   MT5_Server_TCP_Functions.mqh |
//|                                    Copyright 2025, PerplexCoder |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, PerplexCoder"
#property link      ""
#property version   "2.00"
#property description "Biblioteca de funções para MT5 TCP Server - Versão de Produção"
#property description "Funções auxiliares para comunicação TCP e processamento de comandos"

//--- Includes necessários
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Objetos globais para trading
CTrade trade;
CSymbolInfo symbol_info;
CPositionInfo position_info;
COrderInfo order_info;

//--- Estruturas auxiliares
struct TradeRequest
{
    string symbol;
    double volume;
    ENUM_ORDER_TYPE order_type;
    double price;
    double sl;
    double tp;
    string comment;
    ulong magic;
};

struct TradeResult
{
    bool success;
    ulong ticket;
    double price;
    string error_message;
    uint error_code;
};

//+------------------------------------------------------------------+
//| Processar comando recebido do cliente                          |
//+------------------------------------------------------------------+
string ProcessCommand(string command, int client_index)
{
    // Remover espaços em branco
    StringTrimLeft(command);
    StringTrimRight(command);
    
    if(StringLen(command) == 0)
        return "";
    
    // Log do comando recebido
    Print("Processando comando: ", command);
    
    // Processar comandos básicos
    if(StringFind(command, "ping") >= 0 || StringFind(command, "PING") >= 0)
    {
        return CreatePongResponse();
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
    else if(StringFind(command, "server_status") >= 0)
    {
        return GetServerStatus();
    }
    else if(StringFind(command, "symbols") >= 0)
    {
        return GetSymbolsJSON();
    }
    else if(StringFind(command, "place_order") >= 0)
    {
        return ProcessPlaceOrderCommand(command);
    }
    else if(StringFind(command, "close_position") >= 0)
    {
        return ProcessClosePositionCommand(command);
    }
    else if(StringFind(command, "modify_position") >= 0)
    {
        return ProcessModifyPositionCommand(command);
    }
    else if(StringFind(command, "cancel_order") >= 0)
    {
        return ProcessCancelOrderCommand(command);
    }
    else if(StringFind(command, "history") >= 0)
    {
        return GetHistoryJSON();
    }
    
    // Comando não reconhecido
    return CreateErrorResponse("Comando não reconhecido", command);
}

//+------------------------------------------------------------------+
//| Criar resposta de pong                                         |
//+------------------------------------------------------------------+
string CreatePongResponse()
{
    string json = "{";
    json += "\"action\":\"pong\",";
    json += "\"timestamp\":\"" + TimeToString(TimeCurrent()) + "\",";
    json += "\"server_time\":" + IntegerToString(TimeCurrent()) + ",";
    json += "\"status\":\"ok\"";
    json += "}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Criar resposta de erro                                         |
//+------------------------------------------------------------------+
string CreateErrorResponse(string error_message, string received_command = "")
{
    string json = "{";
    json += "\"action\":\"error\",";
    json += "\"error\":\"" + error_message + "\",";
    if(StringLen(received_command) > 0)
    {
        json += "\"received\":\"" + received_command + "\",";
    }
    json += "\"timestamp\":\"" + TimeToString(TimeCurrent()) + "\"";
    json += "}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Obter dados de mercado em formato JSON                         |
//+------------------------------------------------------------------+
string GetMarketDataJSON()
{
    extern string current_symbol;
    extern MarketData currentMarketData;
    
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
    json += "\"trade_mode\":" + IntegerToString(AccountInfoInteger(ACCOUNT_TRADE_MODE)) + ",";
    json += "\"margin_so_mode\":" + IntegerToString(AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)) + ",";
    json += "\"margin_so_call\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL), 2) + ",";
    json += "\"margin_so_so\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 2);
    json += "}}";
    
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
            json += "\"sl\":" + DoubleToString(position_info.StopLoss(), Digits()) + ",";
            json += "\"tp\":" + DoubleToString(position_info.TakeProfit(), Digits()) + ",";
            json += "\"time\":\"" + TimeToString(position_info.Time(), TIME_DATE|TIME_SECONDS) + "\",";
            json += "\"magic\":" + IntegerToString(position_info.Magic()) + ",";
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
            json += "\"sl\":" + DoubleToString(order_info.StopLoss(), Digits()) + ",";
            json += "\"tp\":" + DoubleToString(order_info.TakeProfit(), Digits()) + ",";
            json += "\"time_setup\":\"" + TimeToString(order_info.TimeSetup(), TIME_DATE|TIME_SECONDS) + "\",";
            json += "\"expiration\":\"" + TimeToString(order_info.TimeExpiration(), TIME_DATE|TIME_SECONDS) + "\",";
            json += "\"magic\":" + IntegerToString(order_info.Magic()) + ",";
            json += "\"comment\":\"" + order_info.Comment() + "\"";
            json += "}";
            
            first = false;
        }
    }
    
    json += "]}";
    return json;
}

//+------------------------------------------------------------------+
//| Obter símbolos disponíveis em formato JSON                     |
//+------------------------------------------------------------------+
string GetSymbolsJSON()
{
    string json = "{\"action\":\"symbols\",\"data\":[";
    
    bool first = true;
    int total_symbols = SymbolsTotal(true); // Apenas símbolos selecionados
    
    for(int i = 0; i < total_symbols && i < 50; i++) // Limitar a 50 símbolos
    {
        string symbol_name = SymbolName(i, true);
        if(symbol_name != "")
        {
            if(!first) json += ",";
            
            json += "{";
            json += "\"symbol\":\"" + symbol_name + "\",";
            json += "\"description\":\"" + SymbolInfoString(symbol_name, SYMBOL_DESCRIPTION) + "\",";
            json += "\"digits\":" + IntegerToString(SymbolInfoInteger(symbol_name, SYMBOL_DIGITS)) + ",";
            json += "\"point\":" + DoubleToString(SymbolInfoDouble(symbol_name, SYMBOL_POINT), 8) + ",";
            json += "\"min_lot\":" + DoubleToString(SymbolInfoDouble(symbol_name, SYMBOL_VOLUME_MIN), 2) + ",";
            json += "\"max_lot\":" + DoubleToString(SymbolInfoDouble(symbol_name, SYMBOL_VOLUME_MAX), 2) + ",";
            json += "\"lot_step\":" + DoubleToString(SymbolInfoDouble(symbol_name, SYMBOL_VOLUME_STEP), 2) + ",";
            json += "\"spread\":" + IntegerToString(SymbolInfoInteger(symbol_name, SYMBOL_SPREAD));
            json += "}";
            
            first = false;
        }
    }
    
    json += "]}";
    return json;
}

//+------------------------------------------------------------------+
//| Processar comando de colocação de ordem                        |
//+------------------------------------------------------------------+
string ProcessPlaceOrderCommand(string command)
{
    TradeRequest request;
    
    // Parse básico do comando (pode ser melhorado com parser JSON completo)
    request.symbol = ExtractStringValue(command, "symbol", "EURUSD");
    request.volume = ExtractDoubleValue(command, "volume", 0.01);
    request.price = ExtractDoubleValue(command, "price", 0.0);
    request.sl = ExtractDoubleValue(command, "sl", 0.0);
    request.tp = ExtractDoubleValue(command, "tp", 0.0);
    request.comment = ExtractStringValue(command, "comment", "MT5 TCP Order");
    request.magic = (ulong)ExtractDoubleValue(command, "magic", 123456);
    
    // Determinar tipo de ordem
    string order_type_str = ExtractStringValue(command, "type", "buy");
    if(order_type_str == "buy" || order_type_str == "BUY")
        request.order_type = ORDER_TYPE_BUY;
    else if(order_type_str == "sell" || order_type_str == "SELL")
        request.order_type = ORDER_TYPE_SELL;
    else if(order_type_str == "buy_limit")
        request.order_type = ORDER_TYPE_BUY_LIMIT;
    else if(order_type_str == "sell_limit")
        request.order_type = ORDER_TYPE_SELL_LIMIT;
    else if(order_type_str == "buy_stop")
        request.order_type = ORDER_TYPE_BUY_STOP;
    else if(order_type_str == "sell_stop")
        request.order_type = ORDER_TYPE_SELL_STOP;
    else
        request.order_type = ORDER_TYPE_BUY;
    
    // Executar ordem
    TradeResult result = ExecuteTradeOrder(request);
    
    // Criar resposta JSON
    return CreateTradeResponse("place_order", result, request);
}

//+------------------------------------------------------------------+
//| Processar comando de fechamento de posição                     |
//+------------------------------------------------------------------+
string ProcessClosePositionCommand(string command)
{
    ulong ticket = (ulong)ExtractDoubleValue(command, "ticket", 0);
    double volume = ExtractDoubleValue(command, "volume", 0.0); // 0 = fechar tudo
    
    TradeResult result;
    result.success = false;
    result.ticket = ticket;
    result.error_message = "";
    result.error_code = 0;
    
    if(ticket > 0 && position_info.SelectByTicket(ticket))
    {
        trade.SetExpertMagicNumber(123456);
        
        if(volume <= 0.0)
        {
            // Fechar posição completa
            result.success = trade.PositionClose(ticket);
        }
        else
        {
            // Fechar volume parcial
            result.success = trade.PositionClosePartial(ticket, volume);
        }
        
        if(result.success)
        {
            result.price = trade.ResultPrice();
        }
        else
        {
            result.error_message = trade.ResultComment();
            result.error_code = trade.ResultRetcode();
        }
    }
    else
    {
        result.error_message = "Posição não encontrada";
        result.error_code = 10004;
    }
    
    // Criar resposta
    string json = "{";
    json += "\"action\":\"close_position\",";
    json += "\"success\":" + (result.success ? "true" : "false") + ",";
    json += "\"ticket\":" + IntegerToString(ticket) + ",";
    
    if(result.success)
    {
        json += "\"price\":" + DoubleToString(result.price, Digits());
    }
    else
    {
        json += "\"error\":\"" + result.error_message + "\",";
        json += "\"error_code\":" + IntegerToString(result.error_code);
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Processar comando de modificação de posição                    |
//+------------------------------------------------------------------+
string ProcessModifyPositionCommand(string command)
{
    ulong ticket = (ulong)ExtractDoubleValue(command, "ticket", 0);
    double sl = ExtractDoubleValue(command, "sl", 0.0);
    double tp = ExtractDoubleValue(command, "tp", 0.0);
    
    TradeResult result;
    result.success = false;
    result.ticket = ticket;
    
    if(ticket > 0 && position_info.SelectByTicket(ticket))
    {
        trade.SetExpertMagicNumber(123456);
        result.success = trade.PositionModify(ticket, sl, tp);
        
        if(!result.success)
        {
            result.error_message = trade.ResultComment();
            result.error_code = trade.ResultRetcode();
        }
    }
    else
    {
        result.error_message = "Posição não encontrada";
        result.error_code = 10004;
    }
    
    string json = "{";
    json += "\"action\":\"modify_position\",";
    json += "\"success\":" + (result.success ? "true" : "false") + ",";
    json += "\"ticket\":" + IntegerToString(ticket) + ",";
    
    if(!result.success)
    {
        json += "\"error\":\"" + result.error_message + "\",";
        json += "\"error_code\":" + IntegerToString(result.error_code);
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Processar comando de cancelamento de ordem                     |
//+------------------------------------------------------------------+
string ProcessCancelOrderCommand(string command)
{
    ulong ticket = (ulong)ExtractDoubleValue(command, "ticket", 0);
    
    TradeResult result;
    result.success = false;
    result.ticket = ticket;
    
    if(ticket > 0)
    {
        trade.SetExpertMagicNumber(123456);
        result.success = trade.OrderDelete(ticket);
        
        if(!result.success)
        {
            result.error_message = trade.ResultComment();
            result.error_code = trade.ResultRetcode();
        }
    }
    else
    {
        result.error_message = "Ticket inválido";
        result.error_code = 10004;
    }
    
    string json = "{";
    json += "\"action\":\"cancel_order\",";
    json += "\"success\":" + (result.success ? "true" : "false") + ",";
    json += "\"ticket\":" + IntegerToString(ticket) + ",";
    
    if(!result.success)
    {
        json += "\"error\":\"" + result.error_message + "\",";
        json += "\"error_code\":" + IntegerToString(result.error_code);
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Executar ordem de trading                                      |
//+------------------------------------------------------------------+
TradeResult ExecuteTradeOrder(TradeRequest &request)
{
    TradeResult result;
    result.success = false;
    result.ticket = 0;
    result.price = 0.0;
    result.error_message = "";
    result.error_code = 0;
    
    // Configurar objeto de trading
    trade.SetExpertMagicNumber(request.magic);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Validar símbolo
    if(!SymbolSelect(request.symbol, true))
    {
        result.error_message = "Símbolo não disponível: " + request.symbol;
        result.error_code = 4106;
        return result;
    }
    
    // Executar ordem baseada no tipo
    if(request.order_type == ORDER_TYPE_BUY)
    {
        result.success = trade.Buy(request.volume, request.symbol, 0, request.sl, request.tp, request.comment);
    }
    else if(request.order_type == ORDER_TYPE_SELL)
    {
        result.success = trade.Sell(request.volume, request.symbol, 0, request.sl, request.tp, request.comment);
    }
    else
    {
        // Ordem pendente
        result.success = trade.OrderOpen(request.symbol, request.order_type, request.volume, 0, request.price, request.sl, request.tp, ORDER_TIME_GTC, 0, request.comment);
    }
    
    if(result.success)
    {
        result.ticket = trade.ResultOrder();
        result.price = trade.ResultPrice();
    }
    else
    {
        result.error_message = trade.ResultComment();
        result.error_code = trade.ResultRetcode();
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Criar resposta de trading em JSON                              |
//+------------------------------------------------------------------+
string CreateTradeResponse(string action, TradeResult &result, TradeRequest &request)
{
    string json = "{";
    json += "\"action\":\"" + action + "\",";
    json += "\"success\":" + (result.success ? "true" : "false") + ",";
    
    if(result.success)
    {
        json += "\"ticket\":" + IntegerToString(result.ticket) + ",";
        json += "\"price\":" + DoubleToString(result.price, Digits()) + ",";
        json += "\"volume\":" + DoubleToString(request.volume, 2) + ",";
        json += "\"symbol\":\"" + request.symbol + "\",";
        json += "\"type\":" + IntegerToString(request.order_type);
    }
    else
    {
        json += "\"error\":\"" + result.error_message + "\",";
        json += "\"error_code\":" + IntegerToString(result.error_code);
    }
    
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Obter histórico de transações                                  |
//+------------------------------------------------------------------+
string GetHistoryJSON(datetime from_date = 0, datetime to_date = 0)
{
    if(from_date == 0) from_date = TimeCurrent() - 86400 * 7; // Últimos 7 dias
    if(to_date == 0) to_date = TimeCurrent();
    
    if(!HistorySelect(from_date, to_date))
    {
        return CreateErrorResponse("Falha ao selecionar histórico");
    }
    
    string json = "{";
    json += "\"action\":\"history\",";
    json += "\"data\":{";
    json += "\"from\":\"" + TimeToString(from_date, TIME_DATE|TIME_SECONDS) + "\",";
    json += "\"to\":\"" + TimeToString(to_date, TIME_DATE|TIME_SECONDS) + "\",";
    json += "\"deals\":[";
    
    // Obter deals
    int total_deals = HistoryDealsTotal();
    bool first = true;
    
    for(int i = 0; i < total_deals && i < 100; i++) // Limitar a 100 deals
    {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if(deal_ticket > 0)
        {
            if(!first) json += ",";
            
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
            json += "\"magic\":" + IntegerToString(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC)) + ",";
            json += "\"comment\":\"" + HistoryDealGetString(deal_ticket, DEAL_COMMENT) + "\"";
            json += "}";
            
            first = false;
        }
    }
    
    json += "]}}";
    return json;
}

//+------------------------------------------------------------------+
//| Extrair valor string de comando JSON                           |
//+------------------------------------------------------------------+
string ExtractStringValue(string command, string key, string default_value)
{
    string search_key = "\"" + key + "\":";
    int start_pos = StringFind(command, search_key);
    
    if(start_pos < 0) return default_value;
    
    start_pos += StringLen(search_key);
    
    // Pular espaços
    while(start_pos < StringLen(command) && (StringGetCharacter(command, start_pos) == ' ' || StringGetCharacter(command, start_pos) == '\t'))
        start_pos++;
    
    // Verificar se é string (começa com aspas)
    if(start_pos < StringLen(command) && StringGetCharacter(command, start_pos) == '"')
    {
        start_pos++; // Pular primeira aspa
        int end_pos = StringFind(command, "\"", start_pos);
        if(end_pos > start_pos)
        {
            return StringSubstr(command, start_pos, end_pos - start_pos);
        }
    }
    
    return default_value;
}

//+------------------------------------------------------------------+
//| Extrair valor double de comando JSON                           |
//+------------------------------------------------------------------+
double ExtractDoubleValue(string command, string key, double default_value)
{
    string search_key = "\"" + key + "\":";
    int start_pos = StringFind(command, search_key);
    
    if(start_pos < 0) return default_value;
    
    start_pos += StringLen(search_key);
    
    // Pular espaços
    while(start_pos < StringLen(command) && (StringGetCharacter(command, start_pos) == ' ' || StringGetCharacter(command, start_pos) == '\t'))
        start_pos++;
    
    // Encontrar fim do número
    int end_pos = start_pos;
    while(end_pos < StringLen(command))
    {
        ushort char_code = StringGetCharacter(command, end_pos);
        if(char_code == ',' || char_code == '}' || char_code == ' ' || char_code == '\t' || char_code == '\n' || char_code == '\r')
            break;
        end_pos++;
    }
    
    if(end_pos > start_pos)
    {
        string value_str = StringSubstr(command, start_pos, end_pos - start_pos);
        return StringToDouble(value_str);
    }
    
    return default_value;
}

//+------------------------------------------------------------------+
//| Validar parâmetros de trading                                  |
//+------------------------------------------------------------------+
bool ValidateTradeParameters(TradeRequest &request, string &error_message)
{
    // Validar símbolo
    if(!SymbolSelect(request.symbol, true))
    {
        error_message = "Símbolo não disponível: " + request.symbol;
        return false;
    }
    
    // Validar volume
    double min_lot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);
    
    if(request.volume < min_lot)
    {
        error_message = "Volume muito pequeno. Mínimo: " + DoubleToString(min_lot, 2);
        return false;
    }
    
    if(request.volume > max_lot)
    {
        error_message = "Volume muito grande. Máximo: " + DoubleToString(max_lot, 2);
        return false;
    }
    
    // Verificar se o volume está em múltiplos do lot_step
    double remainder = MathMod(request.volume, lot_step);
    if(remainder > 0.0001) // Tolerância para erros de ponto flutuante
    {
        error_message = "Volume deve ser múltiplo de " + DoubleToString(lot_step, 2);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+