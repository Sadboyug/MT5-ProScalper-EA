# MT5 ProScalper EA - Customization Guide

## Overview

This guide explains how to modify and customize the EA for your specific trading style.

---

## Adding Custom Entry Signals

### Example: Add Moving Average Filter

**Edit `Main.mq5`, in `ProcessScalpTrading()` function:**

```mql
void ProcessScalpTrading(string symbol)
{
    // ... existing code ...
    
    // ADD THIS: Check moving average
    double ma50 = iMA(symbol, ScalpTimeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // ============= BULLISH SCALP SIGNAL =============
    if(qm.isValid && qm.isBullish) {
        // NEW: Only trade if price is above MA50
        if(currentPrice > ma50) {  // Add this check
            // ... rest of existing code ...
        }
    }
}
```

### Example: Add RSI Confirmation

**In `ProcessScalpTrading()` after Quasimodo detection:**

```mql
// Add RSI indicator
double rsi = iRSI(symbol, ScalpTimeframe, 14, PRICE_CLOSE);

// Only buy if RSI is not overbought
if(qm.isValid && qm.isBullish && rsi < 70) {
    // Execute buy
}

// Only sell if RSI is not oversold
if(qm.isValid && !qm.isBullish && rsi > 30) {
    // Execute sell
}
```

---

## Modifying Position Management

### Change Trailing Stop Behavior

**Edit `Config.mq5`:**

```mql
// Aggressive trailing (closer stops)
UseTrailingStop = true;
TrailingStopDistance = 5;  // Tighter than default 15

// Conservative trailing (wider stops)
UseTrailingStop = true;
TrailingStopDistance = 30;  // Wider than default 15
```

### Modify Breakeven Logic

**Edit `Modules/RiskManagement.mq5`, function `UpdateBreakevenStop()`:**

```mql
bool UpdateBreakevenStop(ulong ticket, RiskParameters& params, string symbol, bool isBuy)
{
    if(!params.useBreakEvenStop) return false;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pipValue = GetPipValue(symbol);
    
    // CUSTOMIZE: Change profit trigger from 5 pips to 10 pips
    double beDistance = 10 * pipValue;  // Was: params.breakEvenProfit
    
    if(isBuy) {
        if(currentPrice >= entryPrice + beDistance && currentSL < entryPrice) {
            // Move to BE + 2 pips instead of 1 pip
            request.sl = entryPrice + (2 * pipValue);
            // ...
        }
    }
    
    return false;
}
```

---

## Creating Multiple Trade Strategies

### Add Support/Resistance Bounce Strategy

**Create new file: `Strategies/SRBounce.mq5`:**

```mql
#property strict

// Detect bounce at strong S/R level
bool IsReadyForSRBounce(string symbol, ENUM_TIMEFRAMES timeframe, double& buyPrice, double& sellPrice)
{
    double support = GetNearestSupport(SymbolInfoDouble(symbol, SYMBOL_BID), 2);
    double resistance = GetNearestResistance(SymbolInfoDouble(symbol, SYMBOL_BID), 2);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Check if price is near support (within 5 pips)
    if(support > 0 && MathAbs(currentPrice - support) <= (0.0005)) {
        if(IsBullishCandle(symbol, timeframe, 0)) {
            buyPrice = currentPrice;
            return true;
        }
    }
    
    // Check if price is near resistance (within 5 pips)
    if(resistance > 0 && MathAbs(currentPrice - resistance) <= (0.0005)) {
        if(IsBearishCandle(symbol, timeframe, 0)) {
            sellPrice = currentPrice;
            return true;
        }
    }
    
    return false;
}
```

**Then include in `Main.mq5`:**

```mql
#include "Strategies/SRBounce.mq5"

// In ProcessScalpTrading():
double buyPrice = 0, sellPrice = 0;
if(IsReadyForSRBounce(symbol, ScalpTimeframe, buyPrice, sellPrice)) {
    if(buyPrice > 0) {
        // Execute buy order
    }
    if(sellPrice > 0) {
        // Execute sell order
    }
}
```

---

## Adjusting Exit Strategies

### Partial Take Profit at Multiple Levels

**Edit `Modules/PositionManager.mq5`, add new function:**

```mql
bool PartialCloseAtTPLevel(ulong ticket, double takeProfit, 
                          string symbol, bool isBuy, double partialPercent = 0.5)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    // Close 50% at TP, move SL to BE on remaining
    if(isBuy && currentPrice >= takeProfit) {
        double partialVolume = volume * partialPercent;
        
        // Close half
        ClosePosition(ticket, 0, "Partial TP");
        
        // Move SL to breakeven on remaining
        double newVolume = volume - partialVolume;
        // Execute remaining with BE SL...
        
        return true;
    }
    
    return false;
}
```

### Close at Dynamic Levels

**Create exit based on ATR:**

```mql
bool CloseAtATRLevel(ulong ticket, string symbol, bool isBuy, double atrMultiplier = 2.0)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double atr = CalculateATR(symbol, PERIOD_H1, 14);
    
    double exitLevel = isBuy ? entryPrice + (atr * atrMultiplier) :
                              entryPrice - (atr * atrMultiplier);
    
    if(isBuy && currentPrice >= exitLevel) {
        return ClosePosition(ticket, 0, "ATR Exit");
    }
    if(!isBuy && currentPrice <= exitLevel) {
        return ClosePosition(ticket, 0, "ATR Exit");
    }
    
    return false;
}
```

---

## Performance Optimization

### Reduce Computational Load

**Edit `Config.mq5`:**

```mql
// Reduce lookback periods (faster, less accurate)
MSNR_Lookback = 30;        // Was: 50
QM_LookbackPeriod = 15;    // Was: 20
MSNR_MinBounces = 2;       // Require fewer touches

// Reduce update frequency
input int UpdateFrequencyTicks = 5;  // Update every 5 ticks
```

**In `OnTick()`:**

```mql
static int tickCounter = 0;
tickCounter++;

if(tickCounter < UpdateFrequencyTicks) return;  // Skip ticks
tickCounter = 0;

// ... rest of trading logic ...
```

### Cache Indicator Values

**Add to `Main.mq5`:**

```mql
struct CachedData {
    double supportLevel;
    double resistanceLevel;
    QuasimodoPattern qmPattern;
    double atr;
    datetime lastUpdate;
};

CachedData cache;

void UpdateCache(string symbol, ENUM_TIMEFRAMES timeframe)
{
    if(TimeCurrent() - cache.lastUpdate < 60) return;  // Update once per minute
    
    cache.supportLevel = GetNearestSupport(SymbolInfoDouble(symbol, SYMBOL_BID), MSNR_MinBounces);
    cache.resistanceLevel = GetNearestResistance(SymbolInfoDouble(symbol, SYMBOL_BID), MSNR_MinBounces);
    cache.qmPattern = DetectQuasimodo(symbol, timeframe, QM_LookbackPeriod);
    cache.atr = CalculateATR(symbol, timeframe, 14);
    cache.lastUpdate = TimeCurrent();
}
```

---

## Adding Email/Mobile Alerts

### Send Email on Trade

**Edit `Utils/Logger.mq5`:**

```mql
void LogTradeExecution(ulong ticket, string symbol, bool isBuy,
                      double volume, double entryPrice,
                      double stopLoss, double takeProfit,
                      bool isScalp, string reason = "")
{
    // ... existing logging code ...
    
    // ADD: Send email
    string emailBody = "New Trade Signal!\n" +
                      "Symbol: " + symbol + "\n" +
                      "Type: " + (isBuy ? "BUY" : "SELL") + "\n" +
                      "Entry: " + DoubleToString(entryPrice, 5) + "\n" +
                      "SL: " + DoubleToString(stopLoss, 5) + "\n" +
                      "TP: " + DoubleToString(takeProfit, 5);
    
    SendMail("MT5 ProScalper", emailBody);
}
```

### Push Notifications

```mql
// MT5 built-in notification
if(ShowAlerts) {
    SendAlert("New " + (isBuy ? "BUY" : "SELL") + " signal on " + symbol);
}
```

---

## Tips for Customization

✅ **Always:**
- Create a backup before modifying
- Test changes on demo first
- Document your modifications
- Keep original version
- Test thoroughly before live

❌ **Never:**
- Modify without understanding the code
- Remove risk management checks
- Add complexity without backtesting
- Change multiple things at once
- Trust optimization without validation

---

## Common Customizations Checklist

- [ ] Adjust risk per trade
- [ ] Change pip targets
- [ ] Add moving average filter
- [ ] Add RSI confirmation
- [ ] Add volume filter
- [ ] Modify trailing stop
- [ ] Change breakeven trigger
- [ ] Add email alerts
- [ ] Backtest changes
- [ ] Paper trade on demo
- [ ] Monitor performance
- [ ] Document changes

---

**For more help:** Check GitHub Issues or create a new one!
