//+------------------------------------------------------------------+
//| Module: MT5_Server_TCP_Functions.mqh                            |
//| Descrição: Funções complementares para MT5_Server_TCP.mq5       |
//| Autor: Assistant                                                 |
//| Data: 2024                                                       |
//+------------------------------------------------------------------+
#property strict

//--- Imports necessários
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Estruturas para comunicação
struct CommandData
{
    string command;      // Comando (OPEN_BUY, OPEN_SELL, CLOSE_POSITION, GET_MARKET_DATA, etc.)
    double volume;       // Volume da operação
    double price;        // Preço (para ordens pendentes)
    double sl;           // Stop Loss
    double tp;           // Take Profit
    ulong ticket;        // Ticket da posição/ordem
    string symbol;       // Símbolo (opcional, usa o atual se vazio)
    string comment;      // Comentário da operação
    bool realtime;       // Flag para dados em tempo real
};

struct ResponseData
{
    bool success;        // Status da operação
    string message;      // Mensagem de retorno
    ulong ticket;        // Ticket da operação
    double price;        // Preço de execução
    string error_code;   // Código de erro se houver
};

// Declarações de variáveis externas
extern string current_symbol;
extern CTrade trade;
extern CSymbolInfo symbol_info;
extern CPositionInfo position_info;
extern COrderInfo order_info;

// Declarações de funções auxiliares
void LogMessage(string message);
double ValidateVolume(double volume);
bool ExtractDoubleFromJSON(string json, string key, double &value);
bool ExtractStringFromJSON(string json, string key, string &value);
bool ExtractULongFromJSON(string json, string key, ulong &value);
bool ExtractBoolFromJSON(string json, string key, bool &value);

//+------------------------------------------------------------------+
//| Analisar comando JSON                                            |
//+------------------------------------------------------------------+
bool ParseCommand(string json_string, CommandData &cmd)
{
    // Inicializar estrutura
    cmd.command = "";
    cmd.volume = 0.0;
    cmd.price = 0.0;
    cmd.sl = 0.0;
    cmd.tp = 0.0;
    cmd.ticket = 0;
    cmd.symbol = "";
    cmd.comment = "";
    cmd.realtime = false;
    
    LogMessage("Analisando JSON: " + json_string);
    
    // Detectar tipo de comando
    if(StringFind(json_string, "OPEN_BUY") >= 0)
    {
        cmd.command = "OPEN_BUY";
        ExtractDoubleFromJSON(json_string, "volume", cmd.volume);
        ExtractDoubleFromJSON(json_string, "sl", cmd.sl);
        ExtractDoubleFromJSON(json_string, "tp", cmd.tp);
        ExtractStringFromJSON(json_string, "symbol", cmd.symbol);
        ExtractStringFromJSON(json_string, "comment", cmd.comment);
        return true;
    }
    else if(StringFind(json_string, "OPEN_SELL") >= 0)
    {
        cmd.command = "OPEN_SELL";
        ExtractDoubleFromJSON(json_string, "volume", cmd.volume);
        ExtractDoubleFromJSON(json_string, "sl", cmd.sl);
        ExtractDoubleFromJSON(json_string, "tp", cmd.tp);
        ExtractStringFromJSON(json_string, "symbol", cmd.symbol);
        ExtractStringFromJSON(json_string, "comment", cmd.comment);
        return true;
    }
    else if(StringFind(json_string, "CLOSE_POSITION") >= 0)
    {
        cmd.command = "CLOSE_POSITION";
        ExtractULongFromJSON(json_string, "ticket", cmd.ticket);
        ExtractDoubleFromJSON(json_string, "volume", cmd.volume);
        return true;
    }
    else if(StringFind(json_string, "MODIFY_POSITION") >= 0)
    {
        cmd.command = "MODIFY_POSITION";
        ExtractULongFromJSON(json_string, "ticket", cmd.ticket);
        ExtractDoubleFromJSON(json_string, "sl", cmd.sl);
        ExtractDoubleFromJSON(json_string, "tp", cmd.tp);
        return true;
    }
    else if(StringFind(json_string, "GET_POSITIONS") >= 0)
    {
        cmd.command = "GET_POSITIONS";
        return true;
    }
    else if(StringFind(json_string, "GET_MARKET_DATA") >= 0)
    {
        cmd.command = "GET_MARKET_DATA";
        ExtractBoolFromJSON(json_string, "realtime", cmd.realtime);
        return true;
    }
    else if(StringFind(json_string, "GET_ORDERS") >= 0)
    {
        cmd.command = "GET_ORDERS";
        return true;
    }
    else if(StringFind(json_string, "GET_ACCOUNT_INFO") >= 0)
    {
        cmd.command = "GET_ACCOUNT_INFO";
        return true;
    }
    else if(StringFind(json_string, "PING") >= 0)
    {
        cmd.command = "PING";
        return true;
    }
    
    LogMessage("ERRO: Comando não reconhecido no JSON: " + json_string);
    return false;
}

//+------------------------------------------------------------------+
//| Executar abertura de posição de compra                          |
//+------------------------------------------------------------------+
ResponseData ExecuteOpenBuy(CommandData &cmd)
{
    ResponseData response;
    response.success = false;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    string symbol_to_use = (cmd.symbol != "" && cmd.symbol != current_symbol) ? cmd.symbol : current_symbol;
    
    // Atualizar informações do símbolo se necessário
    if(symbol_to_use != current_symbol)
    {
        if(!symbol_info.Name(symbol_to_use))
        {
            response.message = "Símbolo inválido: " + symbol_to_use;
            response.error_code = "INVALID_SYMBOL";
            return response;
        }
    }
    
    double volume = ValidateVolume(cmd.volume);
    if(volume <= 0)
    {
        response.message = "Volume inválido: " + DoubleToString(cmd.volume, 2);
        response.error_code = "INVALID_VOLUME";
        return response;
    }
    
    double price = symbol_info.Ask();
    double sl = (cmd.sl > 0) ? cmd.sl : 0;
    double tp = (cmd.tp > 0) ? cmd.tp : 0;
    
    string comment = (cmd.comment != "") ? cmd.comment : "Python EA TCP";
    
    if(trade.Buy(volume, symbol_to_use, price, sl, tp, comment))
    {
        response.success = true;
        response.ticket = trade.ResultOrder();
        response.price = trade.ResultPrice();
        response.message = "Posição de compra aberta com sucesso";
        LogMessage("Compra executada - Ticket: " + IntegerToString(response.ticket) + 
                  " Volume: " + DoubleToString(volume, 2) + 
                  " Preço: " + DoubleToString(response.price, 5));
    }
    else
    {
        response.message = "Falha ao abrir posição de compra: " + trade.ResultComment();
        response.error_code = IntegerToString(trade.ResultRetcode());
        LogMessage("ERRO na compra: " + response.message + " Código: " + response.error_code);
    }
    
    return response;
}

//+------------------------------------------------------------------+
//| Executar abertura de posição de venda                           |
//+------------------------------------------------------------------+
ResponseData ExecuteOpenSell(CommandData &cmd)
{
    ResponseData response;
    response.success = false;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    string symbol_to_use = (cmd.symbol != "" && cmd.symbol != current_symbol) ? cmd.symbol : current_symbol;
    
    // Atualizar informações do símbolo se necessário
    if(symbol_to_use != current_symbol)
    {
        if(!symbol_info.Name(symbol_to_use))
        {
            response.message = "Símbolo inválido: " + symbol_to_use;
            response.error_code = "INVALID_SYMBOL";
            return response;
        }
    }
    
    double volume = ValidateVolume(cmd.volume);
    if(volume <= 0)
    {
        response.message = "Volume inválido: " + DoubleToString(cmd.volume, 2);
        response.error_code = "INVALID_VOLUME";
        return response;
    }
    
    double price = symbol_info.Bid();
    double sl = (cmd.sl > 0) ? cmd.sl : 0;
    double tp = (cmd.tp > 0) ? cmd.tp : 0;
    
    string comment = (cmd.comment != "") ? cmd.comment : "Python EA TCP";
    
    if(trade.Sell(volume, symbol_to_use, price, sl, tp, comment))
    {
        response.success = true;
        response.ticket = trade.ResultOrder();
        response.price = trade.ResultPrice();
        response.message = "Posição de venda aberta com sucesso";
        LogMessage("Venda executada - Ticket: " + IntegerToString(response.ticket) + 
                  " Volume: " + DoubleToString(volume, 2) + 
                  " Preço: " + DoubleToString(response.price, 5));
    }
    else
    {
        response.message = "Falha ao abrir posição de venda: " + trade.ResultComment();
        response.error_code = IntegerToString(trade.ResultRetcode());
        LogMessage("ERRO na venda: " + response.message + " Código: " + response.error_code);
    }
    
    return response;
}

//+------------------------------------------------------------------+
//| Executar fechamento de posição                                  |
//+------------------------------------------------------------------+
ResponseData ExecuteClosePosition(CommandData &cmd)
{
    ResponseData response;
    response.success = false;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    if(cmd.ticket == 0)
    {
        response.message = "Ticket inválido";
        response.error_code = "INVALID_TICKET";
        return response;
    }
    
    if(position_info.SelectByTicket(cmd.ticket))
    {
        double volume = (cmd.volume > 0) ? cmd.volume : position_info.Volume();
        
        bool close_result = false;
        if(volume >= position_info.Volume())
        {
            close_result = trade.PositionClose(cmd.ticket);
        }
        else
        {
            close_result = trade.PositionClosePartial(cmd.ticket, volume);
        }
        
        if(close_result)
        {
            response.success = true;
            response.ticket = cmd.ticket;
            response.price = trade.ResultPrice();
            response.message = "Posição fechada com sucesso";
            LogMessage("Posição fechada - Ticket: " + IntegerToString(cmd.ticket) + 
                      " Volume: " + DoubleToString(volume, 2) + 
                      " Preço: " + DoubleToString(response.price, 5));
        }
        else
        {
            response.message = "Falha ao fechar posição: " + trade.ResultComment();
            response.error_code = IntegerToString(trade.ResultRetcode());
            LogMessage("ERRO ao fechar posição: " + response.message + " Código: " + response.error_code);
        }
    }
    else
    {
        response.message = "Posição não encontrada: " + IntegerToString(cmd.ticket);
        response.error_code = "POSITION_NOT_FOUND";
    }
    
    return response;
}

//+------------------------------------------------------------------+
//| Executar modificação de posição                                 |
//+------------------------------------------------------------------+
ResponseData ExecuteModifyPosition(CommandData &cmd)
{
    ResponseData response;
    response.success = false;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    if(cmd.ticket == 0)
    {
        response.message = "Ticket inválido";
        response.error_code = "INVALID_TICKET";
        return response;
    }
    
    if(position_info.SelectByTicket(cmd.ticket))
    {
        double sl = (cmd.sl > 0) ? cmd.sl : position_info.StopLoss();
        double tp = (cmd.tp > 0) ? cmd.tp : position_info.TakeProfit();
        
        if(trade.PositionModify(cmd.ticket, sl, tp))
        {
            response.success = true;
            response.ticket = cmd.ticket;
            response.message = "Posição modificada com sucesso";
            LogMessage("Posição modificada - Ticket: " + IntegerToString(cmd.ticket) + 
                      " SL: " + DoubleToString(sl, 5) + 
                      " TP: " + DoubleToString(tp, 5));
        }
        else
        {
            response.message = "Falha ao modificar posição: " + trade.ResultComment();
            response.error_code = IntegerToString(trade.ResultRetcode());
            LogMessage("ERRO ao modificar posição: " + response.message + " Código: " + response.error_code);
        }
    }
    else
    {
        response.message = "Posição não encontrada: " + IntegerToString(cmd.ticket);
        response.error_code = "POSITION_NOT_FOUND";
    }
    
    return response;
}

//+------------------------------------------------------------------+
//| Obter dados de mercado                                          |
//+------------------------------------------------------------------+
ResponseData GetMarketData(CommandData &cmd)
{
    ResponseData response;
    response.success = true;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    // Atualizar dados se necessário
    if(cmd.realtime)
    {
        UpdateMarketData();
    }
    
    // Construir JSON com dados de mercado
    string market_json = "{";
    market_json += "\"symbol\":\"" + current_symbol + "\",";
    market_json += "\"bid\":" + DoubleToString(currentMarketData.bid, _Digits) + ",";
    market_json += "\"ask\":" + DoubleToString(currentMarketData.ask, _Digits) + ",";
    market_json += "\"spread\":" + DoubleToString(currentMarketData.spread, 1) + ",";
    market_json += "\"timestamp\":" + IntegerToString(currentMarketData.timestamp) + ",";
    market_json += "\"last_price\":" + DoubleToString(currentMarketData.last_price, _Digits);
    market_json += "}";
    
    response.message = market_json;
    return response;
}

//+------------------------------------------------------------------+
//| Obter posições                                                   |
//+------------------------------------------------------------------+
ResponseData GetPositions()
{
    ResponseData response;
    response.success = true;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    string positions_json = "{\"positions\":[";
    bool first = true;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(position_info.SelectByIndex(i))
        {
            if(!first) positions_json += ",";
            first = false;
            
            positions_json += "{";
            positions_json += "\"ticket\":" + IntegerToString(position_info.Ticket()) + ",";
            positions_json += "\"symbol\":\"" + position_info.Symbol() + "\",";
            positions_json += "\"type\":" + IntegerToString(position_info.PositionType()) + ",";
            positions_json += "\"volume\":" + DoubleToString(position_info.Volume(), 2) + ",";
            positions_json += "\"price_open\":" + DoubleToString(position_info.PriceOpen(), _Digits) + ",";
            positions_json += "\"price_current\":" + DoubleToString(position_info.PriceCurrent(), _Digits) + ",";
            positions_json += "\"sl\":" + DoubleToString(position_info.StopLoss(), _Digits) + ",";
            positions_json += "\"tp\":" + DoubleToString(position_info.TakeProfit(), _Digits) + ",";
            positions_json += "\"profit\":" + DoubleToString(position_info.Profit(), 2) + ",";
            positions_json += "\"comment\":\"" + position_info.Comment() + "\"";
            positions_json += "}";
        }
    }
    
    positions_json += "]}";
    response.message = positions_json;
    return response;
}

//+------------------------------------------------------------------+
//| Obter ordens                                                     |
//+------------------------------------------------------------------+
ResponseData GetOrders()
{
    ResponseData response;
    response.success = true;
    response.message = "";
    response.ticket = 0;
    response.price = 0.0;
    response.error_code = "";
    
    string orders_json = "{\"orders\":[";
    bool first = true;
    
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(order_info.SelectByIndex(i))
        {
            if(!first) orders_json += ",";
            first = false;
            
            orders_json += "{";
            orders_json += "\"ticket\":" + IntegerToString(order_info.Ticket()) + ",";
            orders_json += "\"symbol\":\"" + order_info.Symbol() + "\",";
            orders_json += "\"type\":" + IntegerToString(order_info.OrderType()) + ",";
            orders_json += "\"volume\":" + DoubleToString(order_info.VolumeInitial(), 2) + ",";
            orders_json += "\"price_open\":" + DoubleToString(order_info.PriceOpen(), _Digits) + ",";
            orders_json += "\"sl\":" + DoubleToString(order_info.StopLoss(), _Digits) + ",";
            orders_json += "\"tp\":" + DoubleToString(order_info.TakeProfit(), _Digits) + ",";
            orders_json += "\"comment\":\"" + order_info.Comment() + "\"";
            orders_json += "}";
        }
    }
    
    orders_json += "]}";
    response.message = orders_json;
    return response;
}

//+------------------------------------------------------------------+
//| Formatar resposta                                               |
//+------------------------------------------------------------------+
string FormatResponse(ResponseData &response)
{
    string json_response = "{";
    json_response += "\"success\":" + (response.success ? "true" : "false") + ",";
    json_response += "\"message\":\"" + response.message + "\",";
    json_response += "\"ticket\":" + IntegerToString(response.ticket) + ",";
    json_response += "\"price\":" + DoubleToString(response.price, _Digits) + ",";
    json_response += "\"error_code\":\"" + response.error_code + "\"";
    json_response += "}";
    
    return json_response;
}

// ValidateVolume implementada em MT5_Server_TCP.mq5

// Funções Extract implementadas em MT5_Server_TCP.mq5