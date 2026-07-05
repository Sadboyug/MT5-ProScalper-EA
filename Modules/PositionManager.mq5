//+------------------------------------------------------------------+
//|                    Position Manager Module                        |
//|                                                                   |  
//| Manages open positions, exits, and position tracking            |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// POSITION DATA STRUCTURE
//+------------------------------------------------------------------+

struct TradePosition {
    ulong ticket;                    // Position ticket
    string symbol;                   // Trading symbol
    double entryPrice;              // Entry price
    double stopLoss;                // Stop loss level
    double takeProfit;              // Take profit level
    double volume;                  // Position volume (lots)
    datetime entryTime;             // Entry time
    double entryProfit;             // Initial risk/reward ratio
    bool isScalp;                   // Is this a scalp trade?
    double confluenceZone;          // Target confluence zone
};

//+------------------------------------------------------------------+
// CLOSE POSITION AT CONFLUENCE ZONE
//+------------------------------------------------------------------+

bool ClosePositionAtConfluence(ulong ticket, string symbol, 
                               ConfluenceLevel& confluenceZone,
                               ENUM_TIMEFRAMES timeframe)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double confluencePrice = confluenceZone.price;
    double tolerance = 0.001; // 0.1% tolerance
    
    // Check if we've reached the confluence zone
    if(MathAbs(currentPrice - confluencePrice) <= (currentPrice * tolerance)) {
        return ClosePosition(ticket, 0, "Confluence Exit");
    }
    
    return false;
}

//+------------------------------------------------------------------+
// CLOSE POSITION AT TAKE PROFIT
//+------------------------------------------------------------------+

bool ClosePositionAtTakeProfit(ulong ticket, double takeProfit, 
                               string symbol, bool isBuy)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(isBuy && currentPrice >= takeProfit) {
        return ClosePosition(ticket, 0, "TP Hit");
    } else if(!isBuy && currentPrice <= takeProfit) {
        return ClosePosition(ticket, 0, "TP Hit");
    }
    
    return false;
}

//+------------------------------------------------------------------+
// CLOSE POSITION AT STOP LOSS
//+------------------------------------------------------------------+

bool ClosePositionAtStopLoss(ulong ticket, double stopLoss,
                            string symbol, bool isBuy)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(isBuy && currentPrice <= stopLoss) {
        return ClosePosition(ticket, 0, "SL Hit");
    } else if(!isBuy && currentPrice >= stopLoss) {
        return ClosePosition(ticket, 0, "SL Hit");
    }
    
    return false;
}

//+------------------------------------------------------------------+
// CLOSE POSITION BY TIME (MAX HOLD TIME)
//+------------------------------------------------------------------+

bool ClosePositionByTime(ulong ticket, datetime entryTime, int maxHoldSeconds,
                        string symbol, bool isBuy)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    int secondsHeld = (int)(TimeCurrent() - entryTime);
    
    if(secondsHeld >= maxHoldSeconds) {
        return ClosePosition(ticket, 0, "Max Hold Time Exceeded");
    }
    
    return false;
}

//+------------------------------------------------------------------+
// GENERIC CLOSE POSITION FUNCTION
//+------------------------------------------------------------------+

bool ClosePosition(ulong ticket, double price = 0, string comment = "")
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    
    string symbol = PositionGetSymbol(ticket);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    if(price == 0) {
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if(posType == POSITION_TYPE_BUY) {
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
        } else {
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        }
    }
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = symbol;
    request.volume = volume;
    request.price = price;
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.type_filling = ORDER_FILLING_IOC;
    request.comment = comment;
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
// GET POSITION PROFIT IN PIPS
//+------------------------------------------------------------------+

double GetPositionProfitInPips(ulong ticket, string symbol)
{
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pipValue = GetPipValue(symbol);
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    if(posType == POSITION_TYPE_BUY) {
        return (currentPrice - entryPrice) / pipValue;
    } else {
        return (entryPrice - currentPrice) / pipValue;
    }
}

//+------------------------------------------------------------------+
// GET POSITION PROFIT IN MONEY
//+------------------------------------------------------------------+

double GetPositionProfitInMoney(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return 0;
    return PositionGetDouble(POSITION_PROFIT);
}

//+------------------------------------------------------------------+
// GET ALL OPEN POSITIONS COUNT
//+------------------------------------------------------------------+

int GetOpenPositionsCount(string symbol = "")
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(symbol == "" || PositionGetSymbol(i) == symbol) {
                count++;
            }
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
// GET TOTAL OPEN POSITION VOLUME
//+------------------------------------------------------------------+

double GetTotalOpenVolume(string symbol)
{
    double totalVolume = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(PositionGetSymbol(i) == symbol) {
                totalVolume += PositionGetDouble(POSITION_VOLUME);
            }
        }
    }
    
    return totalVolume;
}

//+------------------------------------------------------------------+
// GET AVERAGE ENTRY PRICE
//+------------------------------------------------------------------+

double GetAverageEntryPrice(string symbol)
{
    double totalCost = 0;
    double totalVolume = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(PositionGetSymbol(i) == symbol) {
                double price = PositionGetDouble(POSITION_PRICE_OPEN);
                double volume = PositionGetDouble(POSITION_VOLUME);
                
                totalCost += price * volume;
                totalVolume += volume;
            }
        }
    }
    
    if(totalVolume == 0) return 0;
    return totalCost / totalVolume;
}

//+------------------------------------------------------------------+
// GET TOTAL UNREALIZED PROFIT
//+------------------------------------------------------------------+

double GetTotalUnrealizedProfit(string symbol = "")
{
    double totalProfit = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(symbol == "" || PositionGetSymbol(i) == symbol) {
                totalProfit += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
// MODIFY POSITION SL/TP
//+------------------------------------------------------------------+

bool ModifyPositionSLTP(ulong ticket, double newSL, double newTP)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = newSL;
    request.tp = newTP;
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
// CHECK IF POSITION EXISTS
//+------------------------------------------------------------------+

bool PositionExists(ulong ticket)
{
    return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
// GET POSITION BY SYMBOL (FIRST FOUND)
//+------------------------------------------------------------------+

ulong GetPositionBySymbol(string symbol)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(PositionGetSymbol(i) == symbol) {
                return PositionGetTicket(i);
            }
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
// CLOSE ALL POSITIONS FOR SYMBOL
//+------------------------------------------------------------------+

int CloseAllPositionsForSymbol(string symbol, string comment = "Close All")
{
    int closedCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(PositionGetSymbol(i) == symbol) {
                if(ClosePosition(PositionGetTicket(i), 0, comment)) {
                    closedCount++;
                }
            }
        }
    }
    
    return closedCount;
}

//+------------------------------------------------------------------+
// GET LATEST TRADE TIME
//+------------------------------------------------------------------+

datetime GetLatestTradeTime(string symbol)
{
    datetime latestTime = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(PositionGetSymbol(i) == symbol) {
                datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
                if(openTime > latestTime) {
                    latestTime = openTime;
                }
            }
        }
    }
    
    return latestTime;
}

//+------------------------------------------------------------------+