# MT5 ProScalper EA - Installation & Setup Guide

## Quick Start

### Step 1: Install the EA

1. **Download the files** from: https://github.com/Sadboyug/MT5-ProScalper-EA
2. **Extract to MetaTrader 5 folder:**
   ```
   C:\Users\[YourUsername]\AppData\Roaming\MetaTrader 5\MQL5\Experts\
   ```
3. **Restart MetaTrader 5**
4. In MT5, go to: **File → Open Data Folder** to verify the path

### Step 2: Compile the EA

1. Open MetaTrader 5
2. Press **Ctrl + Shift + B** to open the MetaEditor
3. Navigate to **File → Open** and select `Main.mq5`
4. Press **Ctrl + Shift + F9** to compile
5. Should show: "0 error(s), 0 warning(s)"

### Step 3: Attach to Chart

1. Open a chart (e.g., EURUSD, H1 timeframe)
2. Drag **Main.mq5** onto the chart (or right-click → Expert Advisors → Main)
3. A settings dialog will appear
4. Check **"Allow live trading"** at the bottom
5. Click **OK**

---

## Configuration Guide

Edit `Config.mq5` to customize the EA:

### Risk Management
```mql
RiskPercentPerTrade = 1.0;    // Risk 1% per trade (safe default: 0.5-2%)
MaxDailyLossPercent = 5.0;    // Stop trading if -5% daily loss
RiskRewardRatio = 2.0;        // Only trade if R:R >= 2:1
MaxPositionsPerSymbol = 3;    // Max 3 concurrent trades per pair
```

### Trading Modes
```mql
TradingMode_Setting = HYBRID_MODE;  // Options: SCALP_MODE, SWING_MODE, HYBRID_MODE
ScalpTimeframe = PERIOD_M5;         // 5-min charts for scalping
SwingTimeframe = PERIOD_H1;         // 1-hour charts for swinging
```

### Scalping Parameters
```mql
Scalp_PipTarget = 10;           // Target 10 pips per scalp
Scalp_StopLossPips = 8;         // SL at 8 pips
Scalp_MaxHoldMinutes = 60;      // Close if held > 60 min
Scalp_MinVolatility = 5.0;      // Min ATR to trade
```

### Swing Parameters
```mql
Swing_PipTarget = 100;          // Target 100 pips per swing
Swing_StopLossPips = 50;        // SL at 50 pips
Swing_MaxHoldHours = 168;       // Close if held > 1 week
Swing_MinVolatility = 10.0;     // Min ATR to trade
```

### MSNR Settings
```mql
MSNR_Lookback = 50;             // Scan last 50 bars for levels
MSNR_TouchThreshold = 0.0005;   // 0.05% tolerance for level clustering
MSNR_MinBounces = 2;            // Level must be touched 2+ times
```

### Quasimodo Pattern Settings
```mql
QM_LookbackPeriod = 20;         // Scan last 20 bars for patterns
QM_MinRatio = 0.618;            // Fibonacci ratio threshold
QM_ConfirmationBars = 3;        // Pattern needs 3 bars confirmation
```

### Confluence Settings
```mql
ConfluenceTolerance = 0.0010;   // 0.1% price range for confluence zones
MinConfluenceLevels = 2;        // Need 2+ levels converging
```

### Stop Loss & Take Profit
```mql
UseTrailingStop = true;         // Enable trailing stops
TrailingStopDistance = 15;      // Trail by 15 pips
UseBreakEvenStop = true;        // Move SL to breakeven after profit
BreakEvenProfit = 5;            // Trigger BE at +5 pips profit
```

### Trading Hours
```mql
StartHour = 0;                  // Start trading at 0:00
EndHour = 23;                   // Stop trading at 23:00
TradeMonday = true;
TradeTuesday = true;
TradeWednesday = true;
TradeThursday = true;
TradeFriday = true;
TradeSaturday = false;
TradeSunday = false;
```

### Logging
```mql
EnableLogging = true;           // Log all trades
ShowComments = true;            // Display stats on chart
ShowAlerts = false;             // Alert on new signals
```

---

## Strategy Explanation

### Entry Signals

**MSNR (Malaysian Support & Resistance)**
- Identifies swing highs/lows that are touched multiple times
- Strong levels touched 3+ times
- Weak levels touched 1-2 times

**Quasimodo Pattern (D-C-B-A Structure)**
- Bullish: D (low) → C (high) → B (low, higher than D) → A (high, lower than C)
- Bearish: D (high) → C (low) → B (high, lower than D) → A (low, higher than C)
- Entry at Point D, target at Point A
- Confirmed by Fibonacci ratios

**Example Bullish Setup:**
```
Price Action:  D ↑ C ↓ B ↑ A
              (Low to High Pattern with Retest)
              
Trade Setup:
- Entry: Near Point D (support)
- Stop Loss: Below Point D
- Target 1: Point B (confirmation)
- Target 2: Point A (main target) or opposite MSNR resistance
```

### Exit Rules

**Confluence Exit (PRIMARY)**
- Exit when price reaches opposite side confluence zone
- Confluence = MSNR level + Quasimodo level + Pivot point
- Higher number of converging levels = stronger exit

**Take Profit**
- Hit at confluence zone or set pip target

**Stop Loss**
- Below/above recent swing level
- Scalp: 8-10 pips
- Swing: 40-50 pips

**Time-Based Exit**
- Scalp: Max 60 minutes hold
- Swing: Max 1 week hold
- Helps prevent holding losing positions

**Trailing Stop**
- Moves SL up/down as trade goes in our favor
- 15 pip trail (adjustable)

**Breakeven Stop**
- Once trade is +5 pips, move SL to breakeven + 1 pip
- Protects against reversals

---

## Backtesting Setup

### For Optimization:

1. **Strategy Tester Settings:**
   - Symbol: EURUSD (or your pair)
   - Timeframe: H1 (1-hour)
   - Period: Recent 6-12 months
   - Model: Every tick

2. **Enable Optimization:**
   ```mql
   EnableOptimization = true;
   OptimizationTarget = "ProfitFactor";
   ```

3. **Optimize These Parameters:**
   - `RiskPercentPerTrade` (0.5 to 2.0)
   - `Scalp_PipTarget` (5 to 20)
   - `Swing_PipTarget` (50 to 200)
   - `MSNR_Lookback` (30 to 100)

### Expected Results (Demo):
- Win Rate: 55-65%
- Profit Factor: 1.5+
- Drawdown: < 15%
- Sharpe Ratio: > 1.0

---

## Recommended Settings by Account Size

### Micro Accounts ($500-$2,000)
```mql
RiskPercentPerTrade = 0.5;
MaxDailyLossPercent = 2.0;
MaxPositionsPerSymbol = 1;
TradingMode_Setting = SCALP_MODE;  // Focus on scalps
```

### Small Accounts ($2,000-$10,000)
```mql
RiskPercentPerTrade = 1.0;
MaxDailyLossPercent = 3.0;
MaxPositionsPerSymbol = 2;
TradingMode_Setting = HYBRID_MODE;
```

### Medium Accounts ($10,000+)
```mql
RiskPercentPerTrade = 1.5;
MaxDailyLossPercent = 5.0;
MaxPositionsPerSymbol = 3;
TradingMode_Setting = HYBRID_MODE;
```

---

## Risk Management Best Practices

✅ **DO:**
- Start with 0.5% risk per trade
- Test on demo for 2-4 weeks before live
- Use 1:2+ risk/reward ratios
- Trade during liquid sessions (London/NY overlap)
- Monitor daily loss limits
- Keep a trade journal

❌ **DON'T:**
- Risk more than 2% per trade
- Trade illiquid pairs (wide spreads)
- Over-leverage (max 1:50 recommended)
- Trade on news/high volatility without filters
- Change settings mid-session
- Ignore stop losses

---

## Troubleshooting

### EA Won't Open Orders
1. Check **"Allow live trading"** is enabled
2. Verify account has sufficient balance
3. Check spread is not too wide (> 5 pips)
4. Ensure symbol is liquid
5. Review logs for error messages

### Positions Close Immediately
1. Check stop loss is above/below entry (BUY: SL < Entry, SELL: SL > Entry)
2. Verify spread is not causing instant SL hit
3. Reduce `Scalp_StopLossPips` if too tight

### No Trades Opening
1. Check trading hours are enabled
2. Verify current day is tradable (Monday-Friday enabled?)
3. Check max daily loss limit not exceeded
4. Verify MSNR levels are detected (check journal)
5. Increase `MSNR_MinBounces` threshold

### High Drawdown
1. Reduce risk per trade (1% → 0.5%)
2. Increase minimum R:R ratio (2.0 → 3.0)
3. Add volume filter: `UseVolumeFilter = true`
4. Add trend filter: `UseTrendFilter = true`
5. Reduce max positions: `MaxPositionsPerSymbol = 1`

---

## Files Explained

| File | Purpose |
|------|----------|
| `Main.mq5` | Core EA logic - entry/exit signals |
| `Config.mq5` | All user settings in one place |
| `Indicators/MSNR.mq5` | Malaysian Support & Resistance detection |
| `Indicators/Quasimodo.mq5` | Quasimodo pattern recognition |
| `Indicators/Confluence.mq5` | Confluence zone calculation |
| `Modules/RiskManagement.mq5` | Position sizing & risk controls |
| `Modules/PositionManager.mq5` | Trade management & exits |
| `Modules/OrderManager.mq5` | Order execution & validation |
| `Utils/Helper.mq5` | Utility functions |
| `Utils/Logger.mq5` | Trade logging & performance stats |

---

## Support & Updates

- **GitHub:** https://github.com/Sadboyug/MT5-ProScalper-EA
- **Issues:** Report bugs on GitHub Issues
- **Version:** 1.0.0
- **Last Updated:** 2026-07-05

---

## Disclaimer

⚠️ **IMPORTANT:**
- This EA is for **educational purposes** and **backtesting only**
- Past performance does NOT guarantee future results
- **Always test on a demo account first** before live trading
- **Never risk money you can't afford to lose**
- Forex/CFD trading carries substantial risk of loss
- Results depend on market conditions, settings, and account size
- The author is not responsible for losses
- Trade at your own risk with proper risk management

**Happy Trading! 🚀**