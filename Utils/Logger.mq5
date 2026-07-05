//+------------------------------------------------------------------+
//|                    Performance Logger Module                      |
//|                                                                   |
//| Tracks trades, statistics, and performance metrics               |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// PERFORMANCE STATISTICS STRUCTURE
//+------------------------------------------------------------------+

struct PerformanceStats {
    int totalTrades;               // Total trades executed
    int winningTrades;             // Number of winning trades
    int losingTrades;              // Number of losing trades
    double totalProfit;            // Total profit/loss
    double largestWin;             // Largest winning trade
    double largestLoss;            // Largest losing trade
    double winRate;                // Percentage of winning trades
    double profitFactor;           // Ratio of gross profit to gross loss
    double averageWin;             // Average profit per winning trade
    double averageLoss;            // Average loss per losing trade
    double maxDrawdown;            // Maximum drawdown
    double sharpeRatio;            // Sharpe ratio
    datetime startTime;            // Strategy start time
    datetime lastTradeTime;        // Last trade time
    int consecutiveWins;           // Current consecutive wins
    int consecutiveLosses;         // Current consecutive losses
    int maxConsecutiveWins;        // Maximum consecutive wins
    int maxConsecutiveLosses;      // Maximum consecutive losses
};

//+------------------------------------------------------------------+
// GLOBAL PERFORMANCE TRACKER
//+------------------------------------------------------------------+

PerformanceStats performanceStats;
string tradeLog[1000];             // Array to store trade logs
int tradeLogCount = 0;

//+------------------------------------------------------------------+
// INITIALIZE PERFORMANCE TRACKER
//+------------------------------------------------------------------+

void InitializePerformanceStats()
{
    performanceStats.totalTrades = 0;
    performanceStats.winningTrades = 0;
    performanceStats.losingTrades = 0;
    performanceStats.totalProfit = 0;
    performanceStats.largestWin = 0;
    performanceStats.largestLoss = 0;
    performanceStats.winRate = 0;
    performanceStats.profitFactor = 0;
    performanceStats.averageWin = 0;
    performanceStats.averageLoss = 0;
    performanceStats.maxDrawdown = 0;
    performanceStats.sharpeRatio = 0;
    performanceStats.startTime = TimeCurrent();
    performanceStats.lastTradeTime = 0;
    performanceStats.consecutiveWins = 0;
    performanceStats.consecutiveLosses = 0;
    performanceStats.maxConsecutiveWins = 0;
    performanceStats.maxConsecutiveLosses = 0;
}

//+------------------------------------------------------------------+
// LOG TRADE EXECUTION
//+------------------------------------------------------------------+

void LogTradeExecution(ulong ticket, string symbol, bool isBuy,
                      double volume, double entryPrice,
                      double stopLoss, double takeProfit,
                      bool isScalp, string reason = "")
{
    if(tradeLogCount >= 1000) return;  // Prevent overflow
    
    string tradeType = isBuy ? "BUY" : "SELL";
    string tradeMode = isScalp ? "SCALP" : "SWING";
    
    tradeLog[tradeLogCount] = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) +
                              " | Ticket: " + IntegerToString(ticket) +
                              " | Symbol: " + symbol +
                              " | Type: " + tradeType +
                              " | Mode: " + tradeMode +
                              " | Volume: " + DoubleToString(volume, 2) +
                              " | Entry: " + DoubleToString(entryPrice, 5) +
                              " | SL: " + DoubleToString(stopLoss, 5) +
                              " | TP: " + DoubleToString(takeProfit, 5) +
                              " | Reason: " + reason;
    
    tradeLogCount++;
    PrintLog(tradeLog[tradeLogCount - 1]);
}

//+------------------------------------------------------------------+
// LOG TRADE CLOSURE
//+------------------------------------------------------------------+

void LogTradeClosure(ulong ticket, string symbol, double closePrice,
                    double profit, int holdMinutes, string reason = "")
{
    if(tradeLogCount >= 1000) return;
    
    double profitPercent = (profit / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0;
    
    tradeLog[tradeLogCount] = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) +
                              " | Ticket: " + IntegerToString(ticket) +
                              " | Symbol: " + symbol +
                              " | Close: " + DoubleToString(closePrice, 5) +
                              " | Profit: " + DoubleToString(profit, 2) + " (" +
                              DoubleToString(profitPercent, 2) + "%)" +
                              " | Hold: " + IntegerToString(holdMinutes) + "m" +
                              " | Reason: " + reason;
    
    tradeLogCount++;
    PrintLog(tradeLog[tradeLogCount - 1]);
}

//+------------------------------------------------------------------+
// UPDATE STATISTICS AFTER TRADE CLOSE
//+------------------------------------------------------------------+

void UpdateStatistics(double tradeProfit, int holdTime, bool isWinningTrade)
{
    performanceStats.totalTrades++;
    performanceStats.totalProfit += tradeProfit;
    performanceStats.lastTradeTime = TimeCurrent();
    
    if(isWinningTrade) {
        performanceStats.winningTrades++;
        performanceStats.consecutiveWins++;
        performanceStats.consecutiveLosses = 0;
        
        if(performanceStats.consecutiveWins > performanceStats.maxConsecutiveWins) {
            performanceStats.maxConsecutiveWins = performanceStats.consecutiveWins;
        }
        
        if(tradeProfit > performanceStats.largestWin) {
            performanceStats.largestWin = tradeProfit;
        }
        
        performanceStats.averageWin = performanceStats.totalProfit > 0 ?
                                      performanceStats.totalProfit / performanceStats.winningTrades : 0;
    } else {
        performanceStats.losingTrades++;
        performanceStats.consecutiveLosses++;
        performanceStats.consecutiveWins = 0;
        
        if(performanceStats.consecutiveLosses > performanceStats.maxConsecutiveLosses) {
            performanceStats.maxConsecutiveLosses = performanceStats.consecutiveLosses;
        }
        
        if(tradeProfit < performanceStats.largestLoss) {
            performanceStats.largestLoss = tradeProfit;
        }
        
        performanceStats.averageLoss = performanceStats.losingTrades > 0 ?
                                       MathAbs(performanceStats.totalProfit) / performanceStats.losingTrades : 0;
    }
    
    // Calculate win rate
    if(performanceStats.totalTrades > 0) {
        performanceStats.winRate = (double)performanceStats.winningTrades / 
                                   performanceStats.totalTrades * 100.0;
    }
}

//+------------------------------------------------------------------+
// CALCULATE PROFIT FACTOR
//+------------------------------------------------------------------+

double CalculateProfitFactor()
{
    double grossProfit = 0;
    double grossLoss = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelect(i)) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit > 0) {
                grossProfit += profit;
            } else {
                grossLoss += MathAbs(profit);
            }
        }
    }
    
    if(grossLoss == 0) return 0;
    return grossProfit / grossLoss;
}

//+------------------------------------------------------------------+
// GET PERFORMANCE REPORT
//+------------------------------------------------------------------+

string GetPerformanceReport()
{
    string report = "";
    report += "\n=== PERFORMANCE SUMMARY ===\n";
    report += "Total Trades: " + IntegerToString(performanceStats.totalTrades) + "\n";
    report += "Winning Trades: " + IntegerToString(performanceStats.winningTrades) + "\n";
    report += "Losing Trades: " + IntegerToString(performanceStats.losingTrades) + "\n";
    report += "Win Rate: " + DoubleToString(performanceStats.winRate, 2) + "%\n";
    report += "Total Profit: " + DoubleToString(performanceStats.totalProfit, 2) + "\n";
    report += "Average Win: " + DoubleToString(performanceStats.averageWin, 2) + "\n";
    report += "Average Loss: " + DoubleToString(performanceStats.averageLoss, 2) + "\n";
    report += "Largest Win: " + DoubleToString(performanceStats.largestWin, 2) + "\n";
    report += "Largest Loss: " + DoubleToString(performanceStats.largestLoss, 2) + "\n";
    report += "Max Consecutive Wins: " + IntegerToString(performanceStats.maxConsecutiveWins) + "\n";
    report += "Max Consecutive Losses: " + IntegerToString(performanceStats.maxConsecutiveLosses) + "\n";
    report += "Profit Factor: " + DoubleToString(performanceStats.profitFactor, 2) + "\n";
    report += "================================\n";
    
    return report;
}

//+------------------------------------------------------------------+
// SAVE TRADE LOG TO FILE
//+------------------------------------------------------------------+

bool SaveTradeLogToFile(string filename)
{
    int handle = FileOpen(filename, FILE_WRITE | FILE_TXT);
    
    if(handle == INVALID_HANDLE) {
        PrintLog("Failed to open file: " + filename);
        return false;
    }
    
    // Write header
    FileWrite(handle, "MT5 ProScalper EA - Trade Log");
    FileWrite(handle, "Generated: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
    FileWrite(handle, GetPerformanceReport());
    FileWrite(handle, "");
    
    // Write all trades
    for(int i = 0; i < tradeLogCount; i++) {
        FileWrite(handle, tradeLog[i]);
    }
    
    FileClose(handle);
    PrintLog("Trade log saved to: " + filename);
    
    return true;
}

//+------------------------------------------------------------------+
// DISPLAY PERFORMANCE ON CHART
//+------------------------------------------------------------------+

void DisplayPerformanceOnChart(string comment)
{
    string display = "MT5 ProScalper EA\n";
    display += "Trades: " + IntegerToString(performanceStats.totalTrades) + 
              " | Win Rate: " + DoubleToString(performanceStats.winRate, 1) + "%\n";
    display += "Profit: " + DoubleToString(performanceStats.totalProfit, 2) + 
              " | Factor: " + DoubleToString(performanceStats.profitFactor, 2) + "\n";
    
    Comment(display);
}

//+------------------------------------------------------------------+
// CLEAR TRADE LOG
//+------------------------------------------------------------------+

void ClearTradeLog()
{
    tradeLogCount = 0;
    for(int i = 0; i < 1000; i++) {
        tradeLog[i] = "";
    }
}

//+------------------------------------------------------------------+