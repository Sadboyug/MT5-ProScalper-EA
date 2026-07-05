//+------------------------------------------------------------------+
//|                    Risk Management Module                         |
//|                                                                   |
//| Handles position sizing, risk calculations, and money management |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// RISK MANAGEMENT STRUCTURE
//+------------------------------------------------------------------+

struct RiskParameters {
    double riskPercentPerTrade;      // Risk % per trade
    double maxDailyLossPercent;      // Max daily loss %
    double riskRewardRatio;          // Minimum R:R ratio
    int maxPositionsPerSymbol;       // Max concurrent trades
    bool useTrailingStop;            // Enable trailing stops
    int trailingStopDistance;        // Trailing stop pips
    bool useBreakEvenStop;           // Move SL to breakeven
    int breakEvenProfit;             // Profit pips to trigger BE
};

//+------------------------------------------------------------------+
// GLOBAL TRACKING VARIABLES
//+------------------------------------------------------------------+

double dailyLossAmount = 0;
datetime lastDailyReset = 0;
int openTradesCount = 0;

//+------------------------------------------------------------------+
// INITIALIZE RISK PARAMETERS
//+------------------------------------------------------------------+

RiskParameters InitializeRiskParameters(double riskPercent, double maxDailyLoss, 
                                        double rrRatio, int maxPositions,
                                        bool trailing, int trailingDist,
                                        bool breakeven, int beProfit)
{
    RiskParameters params;
    params.riskPercentPerTrade = riskPercent;
    params.maxDailyLossPercent = maxDailyLoss;
    params.riskRewardRatio = rrRatio;
    params.maxPositionsPerSymbol = maxPositions;
    params.useTrailingStop = trailing;
    params.trailingStopDistance = trailingDist;
    params.useBreakEvenStop = breakeven;
    params.breakEvenProfit = beProfit;
    
    return params;
}

//+------------------------------------------------------------------+
// CALCULATE POSITION SIZE BASED ON RISK
//+------------------------------------------------------------------+

double CalculatePositionSize(RiskParameters& params, double accountBalance, 
                             int stopLossPips, string symbol)
{
    // Calculate how much money we can risk on this trade
    double riskAmount = accountBalance * (params.riskPercentPerTrade / 100.0);
    
    // Get the price movement per pip for this symbol
    double pipValue = GetPipValue(symbol);
    double pointValue = stopLossPips * pipValue;
    
    // Calculate lot size: risk / (pips * pip value)
    if(pointValue <= 0) return 0;
    double lotSize = riskAmount / pointValue;
    
    // Validate against broker limits
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(lotSize, minLot);
    lotSize = MathMin(lotSize, maxLot);
    lotSize = MathRound(lotSize / stepLot) * stepLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
// CHECK IF DAILY LOSS LIMIT EXCEEDED
//+------------------------------------------------------------------+

bool IsDailyLossLimitExceeded(RiskParameters& params, double accountBalance)
{
    // Reset daily loss at start of new day
    if(DayOfYear() != DayOfYear(lastDailyReset)) {
        dailyLossAmount = 0;
        lastDailyReset = TimeCurrent();
    }
    
    double maxDailyLoss = accountBalance * (params.maxDailyLossPercent / 100.0);
    return dailyLossAmount >= maxDailyLoss;
}

//+------------------------------------------------------------------+
// UPDATE DAILY LOSS
//+------------------------------------------------------------------+

void UpdateDailyLoss(double tradeProfit)
{
    if(tradeProfit < 0) {
        dailyLossAmount += MathAbs(tradeProfit);
    }
}

//+------------------------------------------------------------------+
// CHECK IF CAN OPEN NEW TRADE
//+------------------------------------------------------------------+

bool CanOpenNewTrade(RiskParameters& params, string symbol, double accountBalance)
{
    // Check daily loss limit
    if(IsDailyLossLimitExceeded(params, accountBalance)) {
        return false;
    }
    
    // Count open trades for this symbol
    int symbolTradeCount = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            if(PositionGetSymbol(i) == symbol) {
                symbolTradeCount++;
            }
        }
    }
    
    // Check if max positions reached
    if(symbolTradeCount >= params.maxPositionsPerSymbol) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
// VALIDATE RISK/REWARD RATIO
//+------------------------------------------------------------------+

bool IsRiskRewardRatioValid(RiskParameters& params, double entryPrice, 
                           double stopLoss, double takeProfit, bool isBuy)
{
    double rr = CalculateRiskRewardRatio(entryPrice, stopLoss, takeProfit, isBuy);
    return rr >= params.riskRewardRatio;
}

//+------------------------------------------------------------------+
// GET CURRENT ACCOUNT RISK EXPOSURE
//+------------------------------------------------------------------+

double GetAccountRiskExposure()
{
    double totalRisk = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            double pipValue = GetPipValue(PositionGetSymbol(i));
            double loss = MathAbs(currentPrice - entryPrice) / pipValue;
            
            totalRisk += loss * volume * pipValue;
        }
    }
    
    return totalRisk;
}

//+------------------------------------------------------------------+
// APPLY TRAILING STOP
//+------------------------------------------------------------------+

bool UpdateTrailingStop(ulong ticket, RiskParameters& params, string symbol, bool isBuy)
{
    if(!params.useTrailingStop) return false;
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pipValue = GetPipValue(symbol);
    double trailingDistance = params.trailingStopDistance * pipValue;
    
    double newSL = 0;
    
    if(isBuy) {
        newSL = currentPrice - trailingDistance;
        
        // Only move SL up, never down
        if(newSL > currentSL) {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.sl = newSL;
            request.tp = PositionGetDouble(POSITION_TP);
            
            return OrderSend(request, result);
        }
    } else {
        newSL = currentPrice + trailingDistance;
        
        // Only move SL down, never up
        if(newSL < currentSL) {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.sl = newSL;
            request.tp = PositionGetDouble(POSITION_TP);
            
            return OrderSend(request, result);
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
// APPLY BREAKEVEN STOP
//+------------------------------------------------------------------+

bool UpdateBreakevenStop(ulong ticket, RiskParameters& params, string symbol, bool isBuy)
{
    if(!params.useBreakEvenStop) return false;
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double currentSL = PositionGetDouble(POSITION_SL);
    double pipValue = GetPipValue(symbol);
    double beDistance = params.breakEvenProfit * pipValue;
    
    if(isBuy) {
        // If profit is greater than BE trigger level and SL hasn't been moved yet
        if(currentPrice >= entryPrice + beDistance && currentSL < entryPrice) {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.sl = entryPrice + (1 * pipValue); // Add 1 pip for safety
            request.tp = PositionGetDouble(POSITION_TP);
            
            return OrderSend(request, result);
        }
    } else {
        // If profit is greater than BE trigger level and SL hasn't been moved yet
        if(currentPrice <= entryPrice - beDistance && currentSL > entryPrice) {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.sl = entryPrice - (1 * pipValue); // Subtract 1 pip for safety
            request.tp = PositionGetDouble(POSITION_TP);
            
            return OrderSend(request, result);
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
// GET MAXIMUM POSITION SIZE FOR ACCOUNT
//+------------------------------------------------------------------+

double GetMaxPositionSize(string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
}

//+------------------------------------------------------------------+
// GET MINIMUM POSITION SIZE FOR ACCOUNT
//+------------------------------------------------------------------+

double GetMinPositionSize(string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
}

//+------------------------------------------------------------------+
// CALCULATE TOTAL ACCOUNT DRAWDOWN
//+------------------------------------------------------------------+

double GetAccountDrawdown(double initialBalance, double currentBalance)
{
    if(initialBalance <= 0) return 0;
    return ((initialBalance - currentBalance) / initialBalance) * 100.0;
}

//+------------------------------------------------------------------+
// GET CURRENT WINNING RATE
//+------------------------------------------------------------------+

double GetWinningRate()
{
    int winningTrades = 0;
    int totalTrades = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelect(i)) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            totalTrades++;
            
            if(profit > 0) {
                winningTrades++;
            }
        }
    }
    
    if(totalTrades == 0) return 0;
    return (double)winningTrades / totalTrades * 100.0;
}

//+------------------------------------------------------------------+