//+------------------------------------------------------------------+
//|                     MT5 ProScalper EA - Configuration             |
//|                                                                   |
//| User-adjustable settings for risk management and strategy params |
//+------------------------------------------------------------------+

#property strict

// ============= RISK MANAGEMENT SETTINGS =============
input double RiskPercentPerTrade = 1.0;              // Risk % per trade (0.5 to 5.0)
input double MaxDailyLossPercent = 5.0;             // Max daily loss in % of account
input double RiskRewardRatio = 2.0;                 // Minimum R:R ratio (1.0 to 5.0)
input int MaxPositionsPerSymbol = 3;                // Max concurrent trades per pair

// ============= TRADING MODE SETTINGS =============
enum TradingMode {
    SCALP_MODE = 1,          // Quick scalps on lower timeframes
    SWING_MODE = 2,          // Medium-term swings
    HYBRID_MODE = 3          // Both scalping and swinging
};
input TradingMode TradingMode_Setting = HYBRID_MODE;

// ============= TIMEFRAME SETTINGS =============
input ENUM_TIMEFRAMES ScalpTimeframe = PERIOD_M5;   // Scalp mode timeframe
input ENUM_TIMEFRAMES SwingTimeframe = PERIOD_H1;   // Swing mode timeframe

// ============= SCALPING PARAMETERS =============
input int Scalp_PipTarget = 10;                     // Pips target for scalps
input int Scalp_StopLossPips = 8;                   // Stop loss in pips
input int Scalp_MaxHoldMinutes = 60;                // Max hold time in minutes
input double Scalp_MinVolatility = 5.0;             // Min ATR value to trade

// ============= SWING PARAMETERS =============
input int Swing_PipTarget = 100;                    // Pips target for swings
input int Swing_StopLossPips = 50;                  // Stop loss in pips
input int Swing_MaxHoldHours = 168;                 // Max hold time in hours (1 week)
input double Swing_MinVolatility = 10.0;            // Min ATR value to trade

// ============= MSNR SETTINGS =============
input int MSNR_Lookback = 50;                       // Bars to lookback for S/R
input double MSNR_TouchThreshold = 0.0005;          // Price proximity to level (in decimals)
input int MSNR_MinBounces = 2;                      // Min touches to confirm level

// ============= QUASIMODO SETTINGS =============
input int QM_LookbackPeriod = 20;                   // Period to detect QM patterns
input double QM_MinRatio = 0.618;                   // Fibonacci ratio threshold
input int QM_ConfirmationBars = 3;                  // Bars to confirm pattern

// ============= CONFLUENCE SETTINGS =============
input double ConfluenceTolerance = 0.0010;          // Price range for confluence zones
input int MinConfluenceLevels = 2;                  // Min levels needed for confluence

// ============= MARKET FILTER SETTINGS =============
input bool UseVolumeFilter = true;                  // Filter trades by volume
input bool UseTrendFilter = true;                   // Filter by market trend
input bool UseSessionFilter = false;                // Filter by trading session
input string AllowedSessions = "London,NewYork";    // Allowed sessions

// ============= STOP LOSS & TAKE PROFIT SETTINGS =============
input bool UseTrailingStop = true;                  // Enable trailing stops
input int TrailingStopDistance = 15;                // Trailing stop distance in pips
input bool UseBreakEvenStop = true;                 // Move SL to BE after profit
input int BreakEvenProfit = 5;                      // Profit level to trigger BE

// ============= TIME SETTINGS =============
input int StartHour = 0;                            // Trading start hour (0-23)
input int EndHour = 23;                             // Trading end hour (0-23)
input bool TradeMonday = true;
input bool TradeTuesday = true;
input bool TradeWednesday = true;
input bool TradeThursday = true;
input bool TradeFriday = true;
input bool TradeSaturday = false;
input bool TradeSunday = false;

// ============= LOGGING & DEBUG SETTINGS =============
input bool EnableLogging = true;                    // Enable trade logging
input bool ShowComments = true;                     // Show EA comments on chart
input bool ShowAlerts = false;                      // Show alerts on signals

// ============= OPTIMIZATION SETTINGS =============
input bool EnableOptimization = false;              // Enable for backtesting optimization
input string OptimizationTarget = "ProfitFactor";   // Target: Drawdown, ProfitFactor, SharpeRatio

// ============= EXPERT ADVISOR INFO =============
#define EA_VERSION "1.0.0"
#define EA_NAME "MT5 ProScalper EA"
#define EA_AUTHOR "Professional Trading Systems"
#define EA_PURPOSE "MSNR + Quasimodo + Confluence Trading"

//+------------------------------------------------------------------+
// CONFIGURATION VALIDATION FUNCTION
//+------------------------------------------------------------------+

bool ValidateConfiguration()
{
    bool valid = true;
    string errorLog = "";
    
    // Validate risk settings
    if(RiskPercentPerTrade < 0.1 || RiskPercentPerTrade > 10.0) {
        errorLog += "Invalid RiskPercentPerTrade: " + DoubleToString(RiskPercentPerTrade, 2) + "\n";
        valid = false;
    }
    
    if(MaxDailyLossPercent < 1.0 || MaxDailyLossPercent > 50.0) {
        errorLog += "Invalid MaxDailyLossPercent: " + DoubleToString(MaxDailyLossPercent, 2) + "\n";
        valid = false;
    }
    
    if(RiskRewardRatio < 0.5 || RiskRewardRatio > 10.0) {
        errorLog += "Invalid RiskRewardRatio: " + DoubleToString(RiskRewardRatio, 2) + "\n";
        valid = false;
    }
    
    // Validate pip targets
    if(Scalp_PipTarget < 1 || Scalp_PipTarget > 100) {
        errorLog += "Invalid Scalp_PipTarget: " + IntegerToString(Scalp_PipTarget) + "\n";
        valid = false;
    }
    
    if(Swing_PipTarget < 10 || Swing_PipTarget > 1000) {
        errorLog += "Invalid Swing_PipTarget: " + IntegerToString(Swing_PipTarget) + "\n";
        valid = false;
    }
    
    if(!valid && EnableLogging) {
        Print("CONFIGURATION ERRORS:\n" + errorLog);
    }
    
    return valid;
}

//+------------------------------------------------------------------+