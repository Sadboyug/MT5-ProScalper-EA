//+------------------------------------------------------------------+
//|                    Order Manager Module                           |
//|                                                                   |
//| Handles order placement, validation, and execution               |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// ORDER STRUCTURE
//+------------------------------------------------------------------+

struct OrderData {
    string symbol;
    ENUM_ORDER_TYPE orderType;      // BUY or SELL
    double volume;                  // Lot size
    double entryPrice;              // Entry price
    double stopLoss;                // Stop loss
    double takeProfit;              // Take profit
    string comment;                 // Order comment
    ulong ticket;                   // Order ticket (assigned after execution)
    bool isScalp;                   // Scalp trade flag
};

//+------------------------------------------------------------------+
// VALIDATE ORDER BEFORE EXECUTION
//+------------------------------------------------------------------+

bool ValidateOrder(OrderData& order, RiskParameters& riskParams, 
                   double accountBalance)
{
    // Check if symbol is tradable
    if(!IsSymbolTradable(order.symbol)) {
        PrintLog("ERROR: Symbol " + order.symbol + " is not tradable");
        return false;
    }
    
    // Check volume limits
    double minVol = SymbolInfoDouble(order.symbol, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(order.symbol, SYMBOL_VOLUME_MAX);
    
    if(order.volume < minVol || order.volume > maxVol) {
        PrintLog("ERROR: Invalid volume " + DoubleToString(order.volume, 2) + 
                 " for " + order.symbol);
        return false;
    }
    
    // Check stop loss is set
    if(order.stopLoss == 0) {
        PrintLog("ERROR: Stop loss not set for order");
        return false;
    }
    
    // Check take profit is set
    if(order.takeProfit == 0) {
        PrintLog("ERROR: Take profit not set for order");
        return false;
    }
    
    // Check R:R ratio
    bool isBuy = order.orderType == ORDER_TYPE_BUY;
    if(!IsRiskRewardRatioValid(riskParams, order.entryPrice, 
                               order.stopLoss, order.takeProfit, isBuy)) {
        PrintLog("ERROR: Risk/Reward ratio below minimum " + 
                 DoubleToString(riskParams.riskRewardRatio, 2));
        return false;
    }
    
    // Check daily loss limit
    if(IsDailyLossLimitExceeded(riskParams, accountBalance)) {
        PrintLog("ERROR: Daily loss limit exceeded");
        return false;
    }
    
    // Check max positions per symbol
    int currentPositions = GetOpenPositionsCount(order.symbol);
    if(currentPositions >= riskParams.maxPositionsPerSymbol) {
        PrintLog("ERROR: Max positions per symbol reached");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
// EXECUTE BUY ORDER
//+------------------------------------------------------------------+

ulong ExecuteBuyOrder(OrderData& order, string reason = "")
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = order.symbol;
    request.volume = order.volume;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(order.symbol, SYMBOL_ASK);
    request.sl = order.stopLoss;
    request.tp = order.takeProfit;
    request.deviation = 50;
    request.type_filling = ORDER_FILLING_IOC;
    request.comment = order.comment + " | " + reason;
    
    if(OrderSend(request, result)) {
        order.ticket = result.order;
        PrintOrderInfo(result.order, order.symbol, order.volume, 
                      request.price, order.stopLoss, order.takeProfit);
        return result.order;
    } else {
        PrintLog("Buy Order Failed: " + result.comment + " Code: " + 
                IntegerToString(result.retcode));
        return 0;
    }
}

//+------------------------------------------------------------------+
// EXECUTE SELL ORDER
//+------------------------------------------------------------------+

ulong ExecuteSellOrder(OrderData& order, string reason = "")
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = order.symbol;
    request.volume = order.volume;
    request.type = ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(order.symbol, SYMBOL_BID);
    request.sl = order.stopLoss;
    request.tp = order.takeProfit;
    request.deviation = 50;
    request.type_filling = ORDER_FILLING_IOC;
    request.comment = order.comment + " | " + reason;
    
    if(OrderSend(request, result)) {
        order.ticket = result.order;
        PrintOrderInfo(result.order, order.symbol, order.volume, 
                      request.price, order.stopLoss, order.takeProfit);
        return result.order;
    } else {
        PrintLog("Sell Order Failed: " + result.comment + " Code: " + 
                IntegerToString(result.retcode));
        return 0;
    }
}

//+------------------------------------------------------------------+
// EXECUTE ORDER (AUTO BUY/SELL)
//+------------------------------------------------------------------+

ulong ExecuteOrder(OrderData& order, string reason = "")
{
    if(order.orderType == ORDER_TYPE_BUY) {
        return ExecuteBuyOrder(order, reason);
    } else if(order.orderType == ORDER_TYPE_SELL) {
        return ExecuteSellOrder(order, reason);
    }
    
    return 0;
}

//+------------------------------------------------------------------+
// CREATE BUY ORDER DATA STRUCTURE
//+------------------------------------------------------------------+

OrderData CreateBuyOrder(string symbol, double volume, 
                        double entryPrice, double stopLoss, 
                        double takeProfit, string comment = "", 
                        bool isScalp = false)
{
    OrderData order;
    order.symbol = symbol;
    order.orderType = ORDER_TYPE_BUY;
    order.volume = volume;
    order.entryPrice = entryPrice;
    order.stopLoss = stopLoss;
    order.takeProfit = takeProfit;
    order.comment = comment;
    order.ticket = 0;
    order.isScalp = isScalp;
    
    return order;
}

//+------------------------------------------------------------------+
// CREATE SELL ORDER DATA STRUCTURE
//+------------------------------------------------------------------+

OrderData CreateSellOrder(string symbol, double volume,
                         double entryPrice, double stopLoss,
                         double takeProfit, string comment = "",
                         bool isScalp = false)
{
    OrderData order;
    order.symbol = symbol;
    order.orderType = ORDER_TYPE_SELL;
    order.volume = volume;
    order.entryPrice = entryPrice;
    order.stopLoss = stopLoss;
    order.takeProfit = takeProfit;
    order.comment = comment;
    order.ticket = 0;
    order.isScalp = isScalp;
    
    return order;
}

//+------------------------------------------------------------------+
// CHECK ORDER EXECUTION STATUS
//+------------------------------------------------------------------+

bool IsOrderExecuted(ulong ticket)
{
    return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
// GET ORDER ERROR DESCRIPTION
//+------------------------------------------------------------------+

string GetOrderErrorDescription(int errorCode)
{
    switch(errorCode) {
        case 10004: return "TRADE_RETCODE_OK_DONE";
        case 10006: return "TRADE_RETCODE_NO_MONEY";
        case 10014: return "TRADE_RETCODE_INVALID_VOLUME";
        case 10015: return "TRADE_RETCODE_MARKET_CLOSED";
        case 10016: return "TRADE_RETCODE_TRADE_DISABLED";
        case 10018: return "TRADE_RETCODE_FROZEN";
        case 10019: return "TRADE_RETCODE_INVALID_EXPIRATION";
        case 10020: return "TRADE_RETCODE_INVALID_PRICE";
        case 10021: return "TRADE_RETCODE_INVALID_SL";
        case 10022: return "TRADE_RETCODE_INVALID_TP";
        default: return "UNKNOWN_ERROR: " + IntegerToString(errorCode);
    }
}

//+------------------------------------------------------------------+
// CANCEL PENDING ORDER
//+------------------------------------------------------------------+

bool CancelPendingOrder(ulong ticket)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    
    request.action = TRADE_ACTION_REMOVE;
    request.order = ticket;
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
// GET LAST ORDER ERROR
//+------------------------------------------------------------------+

int GetLastOrderError()
{
    return (int)GetLastError();
}

//+------------------------------------------------------------------+