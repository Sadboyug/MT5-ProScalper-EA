//+------------------------------------------------------------------+
//|                    MT5 ProScalper EA - Main                       |
//|                                                                   |
//| Professional Scalping & Swing Trading EA                         |
//| Strategies: MSNR, Quasimodo, Confluence Exits                   |
//+------------------------------------------------------------------+

#property copyright "Professional Trading Systems"
#property link      "https://github.com/Sadboyug/MT5-ProScalper-EA"
#property version   "1.0.0"
#property strict
#property description "MSNR + Quasimodo + Confluence Trading System"

// Include all modules
#include "Config.mq5"
#include "Utils/Helper.mq5"
#include "Indicators/MSNR.mq5"
#include "Indicators/Quasimodo.mq5"
#include "Indicators/Confluence.mq5"
#include "Modules/RiskManagement.mq5"
#include "Modules/PositionManager.mq5"
#include "Modules/OrderManager.mq5"
#include "Utils/Logger.mq5"

//+------------------------------------------------------------------+
// GLOBAL VARIABLES
//+------------------------------------------------------------------+

RiskParameters riskParams;
int scalpBars = 0;
int swingBars = 0;
bool isFirstRun = true;

//+------------------------------------------------------------------+
// EA INITIALIZATION
//+------------------------------------------------------------------+

int OnInit()
{
    // Validate configuration
    if(!ValidateConfiguration()) {
        Alert("Configuration validation failed. Check logs.");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialize risk parameters
    riskParams = InitializeRiskParameters(
        RiskPercentPerTrade,
        MaxDailyLossPercent,
        RiskRewardRatio,
        MaxPositionsPerSymbol,
        UseTrailingStop,
        TrailingStopDistance,
        UseBreakEvenStop,
        BreakEvenProfit
    );
    
    // Initialize performance tracker
    InitializePerformanceStats();
    
    // Display EA info
    PrintLog(EA_NAME + " v" + EA_VERSION + " initialized");
    PrintLog("Trading Mode: " + EnumToString(TradingMode_Setting));
    PrintLog("Risk Per Trade: " + DoubleToString(RiskPercentPerTrade, 1) + "%");
    PrintLog("Max Daily Loss: " + DoubleToString(MaxDailyLossPercent, 1) + "%");
    
    if(ShowAlerts) {
        SendAlert(EA_NAME + " started successfully!");
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// EA DEINITIALIZATION
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
    PrintLog(EA_NAME + " stopped. Reason: " + IntegerToString(reason));
    
    // Save trade log
    if(EnableLogging) {
        SaveTradeLogToFile("MT5ProScalper_" + TimeToString(TimeCurrent(), TIME_DATE) + ".txt");
    }
    
    // Display final statistics
    PrintLog(GetPerformanceReport());
    
    Comment("");
}

//+------------------------------------------------------------------+
// EA MAIN TICK FUNCTION
//+------------------------------------------------------------------+

void OnTick()
{
    // Check if we can trade
    if(!IsWithinTradingHours(StartHour, EndHour)) return;
    if(!IsTradableDay(TradeMonday, TradeTuesday, TradeWednesday, TradeThursday, 
                      TradeFriday, TradeSaturday, TradeSunday)) return;
    
    string symbol = Symbol();
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Update MSNR levels
    IdentifySupportLevels(symbol, ScalpTimeframe, MSNR_Lookback, MSNR_TouchThreshold);
    IdentifyResistanceLevels(symbol, ScalpTimeframe, MSNR_Lookback, MSNR_TouchThreshold);
    
    // ============= SCALP MODE =============
    if(TradingMode_Setting == SCALP_MODE || TradingMode_Setting == HYBRID_MODE) {
        ProcessScalpTrading(symbol);
    }
    
    // ============= SWING MODE =============
    if(TradingMode_Setting == SWING_MODE || TradingMode_Setting == HYBRID_MODE) {
        ProcessSwingTrading(symbol);
    }
    
    // ============= MANAGE OPEN POSITIONS =============
    ManageOpenPositions(symbol);
    
    // ============= UPDATE DISPLAY =============
    if(ShowComments) {
        DisplayPerformanceOnChart(EA_NAME);
    }
}

//+------------------------------------------------------------------+
// PROCESS SCALP TRADING
//+------------------------------------------------------------------+

void ProcessScalpTrading(string symbol)
{
    // Check volatility filter
    double atr = CalculateATR(symbol, ScalpTimeframe, 14);
    if(atr < Scalp_MinVolatility) return;
    
    // Check if we can trade
    if(!CanOpenNewTrade(riskParams, symbol, AccountInfoDouble(ACCOUNT_BALANCE))) {
        return;
    }
    
    // Get Quasimodo pattern
    QuasimodoPattern qm = DetectQuasimodo(symbol, ScalpTimeframe, QM_LookbackPeriod);
    
    // Check MSNR levels
    double nearestSupport = GetNearestSupport(SymbolInfoDouble(symbol, SYMBOL_BID), MSNR_MinBounces);
    double nearestResistance = GetNearestResistance(SymbolInfoDouble(symbol, SYMBOL_BID), MSNR_MinBounces);
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // ============= BULLISH SCALP SIGNAL =============
    if(qm.isValid && qm.isBullish) {
        // Entry at Quasimodo Point D (or support bounce)
        if(MathAbs(currentPrice - qm.pointD) <= (currentPrice * 0.001)) {
            // Confirm with price action
            if(IsBullishCandle(symbol, ScalpTimeframe, 0)) {
                // Calculate stop loss and take profit
                double stopLoss = qm.pointD - (Scalp_StopLossPips * GetPipValue(symbol));
                double targetConfluence = GetNearestResistance(currentPrice, MSNR_MinBounces);
                double takeProfit = targetConfluence > 0 ? targetConfluence : 
                                   currentPrice + (Scalp_PipTarget * GetPipValue(symbol));
                
                // Validate R:R ratio
                if(IsRiskRewardRatioValid(riskParams, currentPrice, stopLoss, takeProfit, true)) {
                    // Calculate position size
                    double lotSize = CalculatePositionSize(riskParams, 
                                    AccountInfoDouble(ACCOUNT_BALANCE),
                                    Scalp_StopLossPips, symbol);
                    
                    if(lotSize > 0) {
                        // Execute buy order
                        OrderData order = CreateBuyOrder(symbol, lotSize, currentPrice, 
                                                        stopLoss, takeProfit,
                                                        "MSNR_QM_Scalp_Buy", true);
                        
                        if(ValidateOrder(order, riskParams, AccountInfoDouble(ACCOUNT_BALANCE))) {
                            ulong ticket = ExecuteOrder(order, "Bullish Quasimodo Pattern");
                            if(ticket > 0) {
                                LogTradeExecution(ticket, symbol, true, lotSize, currentPrice,
                                                stopLoss, takeProfit, true, "QM Bullish");
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ============= BEARISH SCALP SIGNAL =============
    if(qm.isValid && !qm.isBullish) {
        // Entry at Quasimodo Point D (or resistance bounce)
        if(MathAbs(currentPrice - qm.pointD) <= (currentPrice * 0.001)) {
            // Confirm with price action
            if(IsBearishCandle(symbol, ScalpTimeframe, 0)) {
                // Calculate stop loss and take profit
                double stopLoss = qm.pointD + (Scalp_StopLossPips * GetPipValue(symbol));
                double targetConfluence = GetNearestSupport(currentPrice, MSNR_MinBounces);
                double takeProfit = targetConfluence > 0 ? targetConfluence :
                                   currentPrice - (Scalp_PipTarget * GetPipValue(symbol));
                
                // Validate R:R ratio
                if(IsRiskRewardRatioValid(riskParams, currentPrice, stopLoss, takeProfit, false)) {
                    // Calculate position size
                    double lotSize = CalculatePositionSize(riskParams,
                                    AccountInfoDouble(ACCOUNT_BALANCE),
                                    Scalp_StopLossPips, symbol);
                    
                    if(lotSize > 0) {
                        // Execute sell order
                        OrderData order = CreateSellOrder(symbol, lotSize, currentPrice,
                                                         stopLoss, takeProfit,
                                                         "MSNR_QM_Scalp_Sell", true);
                        
                        if(ValidateOrder(order, riskParams, AccountInfoDouble(ACCOUNT_BALANCE))) {
                            ulong ticket = ExecuteOrder(order, "Bearish Quasimodo Pattern");
                            if(ticket > 0) {
                                LogTradeExecution(ticket, symbol, false, lotSize, currentPrice,
                                                stopLoss, takeProfit, true, "QM Bearish");
                            }
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// PROCESS SWING TRADING
//+------------------------------------------------------------------+

void ProcessSwingTrading(string symbol)
{
    // Check volatility filter
    double atr = CalculateATR(symbol, SwingTimeframe, 14);
    if(atr < Swing_MinVolatility) return;
    
    // Check if we can trade
    if(!CanOpenNewTrade(riskParams, symbol, AccountInfoDouble(ACCOUNT_BALANCE))) {
        return;
    }
    
    // Detect trend
    TREND_DIRECTION trend = GetTrend(symbol, SwingTimeframe, 50);
    
    // Get Quasimodo pattern on swing timeframe
    QuasimodoPattern qm = DetectQuasimodo(symbol, SwingTimeframe, QM_LookbackPeriod);
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pipValue = GetPipValue(symbol);
    
    // ============= BULLISH SWING SIGNAL =============
    if(trend == TREND_UP || (qm.isValid && qm.isBullish)) {
        // Look for support bounce in uptrend
        double support = GetNearestSupport(currentPrice, MSNR_MinBounces);
        
        if(support > 0 && MathAbs(currentPrice - support) <= (currentPrice * 0.002)) {
            double resistance = GetNearestResistance(currentPrice, MSNR_MinBounces);
            double stopLoss = support - (Swing_StopLossPips * pipValue);
            double takeProfit = resistance > 0 ? resistance :
                               currentPrice + (Swing_PipTarget * pipValue);
            
            if(IsRiskRewardRatioValid(riskParams, currentPrice, stopLoss, takeProfit, true)) {
                double lotSize = CalculatePositionSize(riskParams,
                                AccountInfoDouble(ACCOUNT_BALANCE),
                                Swing_StopLossPips, symbol);
                
                if(lotSize > 0) {
                    OrderData order = CreateBuyOrder(symbol, lotSize, currentPrice,
                                                    stopLoss, takeProfit,
                                                    "MSNR_Swing_Buy", false);
                    
                    if(ValidateOrder(order, riskParams, AccountInfoDouble(ACCOUNT_BALANCE))) {
                        ulong ticket = ExecuteOrder(order, "Bullish Swing Setup");
                        if(ticket > 0) {
                            LogTradeExecution(ticket, symbol, true, lotSize, currentPrice,
                                            stopLoss, takeProfit, false, "Swing Bullish");
                        }
                    }
                }
            }
        }
    }
    
    // ============= BEARISH SWING SIGNAL =============
    if(trend == TREND_DOWN || (qm.isValid && !qm.isBullish)) {
        // Look for resistance bounce in downtrend
        double resistance = GetNearestResistance(currentPrice, MSNR_MinBounces);
        
        if(resistance > 0 && MathAbs(currentPrice - resistance) <= (currentPrice * 0.002)) {
            double support = GetNearestSupport(currentPrice, MSNR_MinBounces);
            double stopLoss = resistance + (Swing_StopLossPips * pipValue);
            double takeProfit = support > 0 ? support :
                               currentPrice - (Swing_PipTarget * pipValue);
            
            if(IsRiskRewardRatioValid(riskParams, currentPrice, stopLoss, takeProfit, false)) {
                double lotSize = CalculatePositionSize(riskParams,
                                AccountInfoDouble(ACCOUNT_BALANCE),
                                Swing_StopLossPips, symbol);
                
                if(lotSize > 0) {
                    OrderData order = CreateSellOrder(symbol, lotSize, currentPrice,
                                                     stopLoss, takeProfit,
                                                     "MSNR_Swing_Sell", false);
                    
                    if(ValidateOrder(order, riskParams, AccountInfoDouble(ACCOUNT_BALANCE))) {
                        ulong ticket = ExecuteOrder(order, "Bearish Swing Setup");
                        if(ticket > 0) {
                            LogTradeExecution(ticket, symbol, false, lotSize, currentPrice,
                                            stopLoss, takeProfit, false, "Swing Bearish");
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// MANAGE OPEN POSITIONS
//+------------------------------------------------------------------+

void ManageOpenPositions(string symbol)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(!PositionSelect(i)) continue;
        
        if(PositionGetSymbol(i) != symbol) continue;
        
        ulong ticket = PositionGetTicket(i);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double pipValue = GetPipValue(symbol);
        double profit = PositionGetDouble(POSITION_PROFIT);
        datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);
        bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
        
        // Update trailing stop
        if(UseTrailingStop) {
            UpdateTrailingStop(ticket, riskParams, symbol, isBuy);
        }
        
        // Update breakeven stop
        if(UseBreakEvenStop) {
            UpdateBreakevenStop(ticket, riskParams, symbol, isBuy);
        }
        
        // Check max hold time
        int holdMinutes = GetMinutesHeld(entryTime);
        double stopLoss = PositionGetDouble(POSITION_SL);
        double takeProfit = PositionGetDouble(POSITION_TP);
        
        // Scalp trades
        if(holdMinutes > Scalp_MaxHoldMinutes) {
            ClosePosition(ticket, 0, "Max Hold Time Scalp");
            LogTradeClosure(ticket, symbol, currentPrice, profit, holdMinutes, "Timeout");
            UpdateStatistics(profit, holdMinutes, profit > 0);
            continue;
        }
        
        // Swing trades
        int holdHours = GetHoursHeld(entryTime);
        if(holdHours > Swing_MaxHoldHours) {
            ClosePosition(ticket, 0, "Max Hold Time Swing");
            LogTradeClosure(ticket, symbol, currentPrice, profit, holdMinutes, "Timeout");
            UpdateStatistics(profit, holdMinutes, profit > 0);
            continue;
        }
        
        // Check for confluence exit
        ConfluenceLevel confluenceZone = GetNearestConfluenceZone(symbol, SwingTimeframe,
                                                                  currentPrice,
                                                                  ConfluenceTolerance,
                                                                  MinConfluenceLevels,
                                                                  !isBuy);
        
        if(confluenceZone.price > 0) {
            if(isBuy && currentPrice >= confluenceZone.price) {
                ClosePosition(ticket, 0, "Confluence Exit Buy");
                LogTradeClosure(ticket, symbol, currentPrice, profit, holdMinutes, "Confluence");
                UpdateStatistics(profit, holdMinutes, profit > 0);
            } else if(!isBuy && currentPrice <= confluenceZone.price) {
                ClosePosition(ticket, 0, "Confluence Exit Sell");
                LogTradeClosure(ticket, symbol, currentPrice, profit, holdMinutes, "Confluence");
                UpdateStatistics(profit, holdMinutes, profit > 0);
            }
        }
    }
}

//+------------------------------------------------------------------+