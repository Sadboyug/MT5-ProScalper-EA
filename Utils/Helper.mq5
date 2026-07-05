//+------------------------------------------------------------------+
//|                    Helper Functions Module                        |
//|                                                                   |
//| Utility functions for calculations and common operations         |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// SYMBOL AND PRICE UTILITIES
//+------------------------------------------------------------------+

// Get pip value for a symbol
double GetPipValue(string symbol)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipValue = digits == 5 || digits == 3 ? 0.0001 : 0.01;
    return pipValue;
}

// Convert pips to price value
double PipsToPrice(int pips, string symbol)
{
    return pips * GetPipValue(symbol);
}

// Convert price to pips
int PriceToPips(double price, string symbol)
{
    return (int)(price / GetPipValue(symbol));
}

// Get current bid/ask spread in pips
double GetSpreadPips(string symbol)
{
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double pipValue = GetPipValue(symbol);
    return (ask - bid) / pipValue;
}

// Check if symbol is tradable
bool IsSymbolTradable(string symbol)
{
    if(!SymbolSelect(symbol, true)) return false;
    long mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
    return mode == SYMBOL_TRADE_MODE_FULL || mode == SYMBOL_TRADE_MODE_SHORTONLY || mode == SYMBOL_TRADE_MODE_LONGONLY;
}

// Get symbol contract size
double GetContractSize(string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
}

//+------------------------------------------------------------------+
// POSITION SIZING
//+------------------------------------------------------------------+

// Calculate lot size based on risk percentage
double CalculateLotSize(double accountBalance, double riskPercent, int stopLossPips, string symbol)
{
    double riskAmount = accountBalance * (riskPercent / 100.0);
    double pipValue = GetPipValue(symbol);
    double priceRisk = stopLossPips * pipValue;
    
    if(priceRisk <= 0) return 0;
    
    double lotSize = riskAmount / priceRisk;
    
    // Validate minimum/maximum lots
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    // Round to step
    lotSize = MathRound(lotSize / stepLot) * stepLot;
    
    return lotSize;
}

// Calculate risk/reward ratio
double CalculateRiskRewardRatio(double entryPrice, double stopLoss, double takeProfit, bool isBuy)
{
    if(isBuy) {
        double risk = entryPrice - stopLoss;
        double reward = takeProfit - entryPrice;
        if(risk <= 0) return 0;
        return reward / risk;
    } else {
        double risk = stopLoss - entryPrice;
        double reward = entryPrice - takeProfit;
        if(risk <= 0) return 0;
        return reward / risk;
    }
}

//+------------------------------------------------------------------+
// TIME UTILITIES
//+------------------------------------------------------------------+

// Check if current time is within trading hours
bool IsWithinTradingHours(int startHour, int endHour)
{
    int currentHour = Hour();
    
    if(startHour < endHour) {
        return currentHour >= startHour && currentHour < endHour;
    } else {
        return currentHour >= startHour || currentHour < endHour;
    }
}

// Check if today is a tradable day
bool IsTradableDay(bool mon, bool tue, bool wed, bool thu, bool fri, bool sat, bool sun)
{
    int dayOfWeek = DayOfWeek();
    
    switch(dayOfWeek) {
        case 1: return mon;  // Monday
        case 2: return tue;  // Tuesday
        case 3: return wed;  // Wednesday
        case 4: return thu;  // Thursday
        case 5: return fri;  // Friday
        case 6: return sat;  // Saturday
        case 0: return sun;  // Sunday
        default: return false;
    }
}

// Get minutes held for a position
int GetMinutesHeld(datetime entryTime)
{
    return (int)((TimeCurrent() - entryTime) / 60);
}

// Get hours held for a position
int GetHoursHeld(datetime entryTime)
{
    return (int)((TimeCurrent() - entryTime) / 3600);
}

//+------------------------------------------------------------------+
// VOLATILITY CALCULATIONS
//+------------------------------------------------------------------+

// Calculate ATR (Average True Range)
double CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
    double atr = 0;
    double high, low, close;
    double trueRange = 0;
    double sumTR = 0;
    
    for(int i = 1; i <= period; i++) {
        high = iHigh(symbol, timeframe, i);
        low = iLow(symbol, timeframe, i);
        close = iClose(symbol, timeframe, i + 1);
        
        double tr1 = high - low;
        double tr2 = MathAbs(high - close);
        double tr3 = MathAbs(low - close);
        
        trueRange = MathMax(MathMax(tr1, tr2), tr3);
        sumTR += trueRange;
    }
    
    atr = sumTR / period;
    return atr;
}

// Calculate standard deviation (volatility)
double CalculateStdDev(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
    double sum = 0;
    double mean = 0;
    
    // Calculate mean
    for(int i = 0; i < period; i++) {
        mean += iClose(symbol, timeframe, i);
    }
    mean = mean / period;
    
    // Calculate standard deviation
    for(int i = 0; i < period; i++) {
        double diff = iClose(symbol, timeframe, i) - mean;
        sum += diff * diff;
    }
    
    return MathSqrt(sum / period);
}

//+------------------------------------------------------------------+
// TREND ANALYSIS
//+------------------------------------------------------------------+

// Determine trend direction
enum TREND_DIRECTION {
    TREND_UP = 1,
    TREND_DOWN = -1,
    TREND_FLAT = 0
};

TREND_DIRECTION GetTrend(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
    double sma = iMA(symbol, timeframe, period, 0, MODE_SMA, PRICE_CLOSE);
    double currentPrice = iClose(symbol, timeframe, 0);
    double previousPrice = iClose(symbol, timeframe, 1);
    
    if(currentPrice > sma && previousPrice > sma) return TREND_UP;
    if(currentPrice < sma && previousPrice < sma) return TREND_DOWN;
    
    return TREND_FLAT;
}

//+------------------------------------------------------------------+
// LEVEL CALCULATIONS
//+------------------------------------------------------------------+

// Calculate pivot points
struct PivotPoints {
    double support1;
    double support2;
    double resistance1;
    double resistance2;
    double pivot;
};

PivotPoints CalculatePivots(string symbol, ENUM_TIMEFRAMES timeframe)
{
    PivotPoints pp;
    
    double high = iHigh(symbol, timeframe, 1);
    double low = iLow(symbol, timeframe, 1);
    double close = iClose(symbol, timeframe, 1);
    
    pp.pivot = (high + low + close) / 3;
    pp.resistance1 = (2 * pp.pivot) - low;
    pp.support1 = (2 * pp.pivot) - high;
    pp.resistance2 = pp.pivot + (high - low);
    pp.support2 = pp.pivot - (high - low);
    
    return pp;
}

//+------------------------------------------------------------------+
// VOLUME ANALYSIS
//+------------------------------------------------------------------+

// Get current bar volume
double GetBarVolume(string symbol, ENUM_TIMEFRAMES timeframe)
{
    return (double)iVolume(symbol, timeframe, 0);
}

// Get average volume over period
double GetAverageVolume(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
    double sumVolume = 0;
    for(int i = 0; i < period; i++) {
        sumVolume += (double)iVolume(symbol, timeframe, i);
    }
    return sumVolume / period;
}

// Check if volume is above average
bool IsVolumeAboveAverage(string symbol, ENUM_TIMEFRAMES timeframe, int period, double threshold)
{
    double currentVolume = GetBarVolume(symbol, timeframe);
    double avgVolume = GetAverageVolume(symbol, timeframe, period);
    
    return currentVolume > (avgVolume * threshold);
}

//+------------------------------------------------------------------+
// PRICE ACTION ANALYSIS
//+------------------------------------------------------------------+

// Check for bullish candle
bool IsBullishCandle(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 0)
{
    double open = iOpen(symbol, timeframe, barIndex);
    double close = iClose(symbol, timeframe, barIndex);
    return close > open;
}

// Check for bearish candle
bool IsBearishCandle(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 0)
{
    double open = iOpen(symbol, timeframe, barIndex);
    double close = iClose(symbol, timeframe, barIndex);
    return close < open;
}

// Get candle body size in pips
double GetCandleBodyPips(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 0)
{
    double open = iOpen(symbol, timeframe, barIndex);
    double close = iClose(symbol, timeframe, barIndex);
    double pipValue = GetPipValue(symbol);
    
    return MathAbs(close - open) / pipValue;
}

// Get candle wick size in pips
double GetCandleWickPips(string symbol, ENUM_TIMEFRAMES timeframe, int barIndex = 0)
{
    double high = iHigh(symbol, timeframe, barIndex);
    double low = iLow(symbol, timeframe, barIndex);
    double pipValue = GetPipValue(symbol);
    
    return (high - low) / pipValue;
}

//+------------------------------------------------------------------+
// STRING AND FORMATTING UTILITIES
//+------------------------------------------------------------------+

// Format double to price format
string FormatPrice(double price, int digits)
{
    return DoubleToString(price, digits);
}

// Get readable time format
string FormatTime(datetime time)
{
    return TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
}

// Convert seconds to readable format
string SecondsToTimeString(int seconds)
{
    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;
    int secs = seconds % 60;
    
    return IntegerToString(hours) + "h " + IntegerToString(minutes) + "m " + IntegerToString(secs) + "s";
}

//+------------------------------------------------------------------+
// LOGGING AND DEBUG
//+------------------------------------------------------------------+

// Print with timestamp
void PrintLog(string message)
{
    Print("[" + FormatTime(TimeCurrent()) + "] " + message);
}

// Send alert
void SendAlert(string message)
{
    Alert("[MT5 ProScalper] " + message);
}

// Print formatted order info
void PrintOrderInfo(ulong ticket, string symbol, double volume, double openPrice, double stopLoss, double takeProfit)
{
    PrintLog("ORDER OPENED: " + symbol + 
             " | Ticket: " + IntegerToString(ticket) + 
             " | Volume: " + DoubleToString(volume, 2) + 
             " | Price: " + FormatPrice(openPrice, 5) + 
             " | SL: " + FormatPrice(stopLoss, 5) + 
             " | TP: " + FormatPrice(takeProfit, 5));
}

//+------------------------------------------------------------------+