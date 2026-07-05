# MT5 ProScalper EA - Professional Trading System

A sophisticated MetaTrader 5 Expert Advisor combining **Malaysian Support & Resistance (MSNR)**, **Quasimodo (QM)** patterns, and **Confluence-based exits** for professional scalping and swing trading.

## Features

✅ **Dual Trading Modes**
- Scalping Mode: Quick entries/exits on lower timeframes
- Swing Mode: Trend-following on higher timeframes

✅ **Advanced Strategy Indicators**
- Malaysian Support & Resistance detection
- Quasimodo pattern recognition
- Multi-level confluence analysis
- Price action analysis

✅ **Professional Risk Management**
- User-adjustable risk per trade (%)
- Dynamic position sizing
- Maximum daily loss limits
- Trailing stop management

✅ **Multi-Asset Support**
- Works on Forex pairs (EURUSD, GBPUSD, etc.)
- Cryptocurrency pairs
- Commodities
- Indices
- Any chart with candle/line data

✅ **Advanced Features**
- Backtesting optimization
- Real-time performance tracking
- Customizable timeframe settings
- Trade logging and statistics

## Installation

1. Copy all `.mq5` files to: `C:\Users\[YourUsername]\AppData\Roaming\MetaTrader 5\MQL5\Experts\`
2. Restart MetaTrader 5
3. Drag the EA onto your chart
4. Enable "Allow live trading" in the EA settings

## Configuration

Edit `Config.mq5` to customize:
- Risk percentage per trade
- Scalping vs Swing mode
- Timeframe settings
- Max daily loss limit
- Position management rules

## Strategy Logic

### Entry Signals
1. **MSNR Detection**: Identify key support and resistance levels
2. **Quasimodo Pattern**: Detect reversal patterns at confluence zones
3. **Price Action**: Confirm with candle patterns and momentum

### Exit Rules
- **Primary Exit**: Opposite side confluence (MSNR + Quasimodo levels)
- **Stop Loss**: Below recent swing low (scalp) or structural level (swing)
- **Take Profit**: Opposite side confluence zone
- **Trailing Stop**: Activated after breakeven

## Performance Targets

- **Scalping Mode**: 5-15 pips per trade (EUR/USD)
- **Swing Mode**: 50-200 pips per trade
- **Win Rate Target**: 55-65%
- **Risk/Reward**: 1:2 minimum

## Files Structure

```
MT5-ProScalper-EA/
├── Main.mq5                 # Main EA file
├── Config.mq5              # User settings
├── Indicators/
│   ├── MSNR.mq5           # Malaysian Support & Resistance
│   ├── Quasimodo.mq5      # Quasimodo pattern detector
│   └── Confluence.mq5     # Confluence calculator
├── Modules/
│   ├── RiskManagement.mq5  # Position sizing & risk logic
│   ├── PositionManager.mq5 # Trade management
│   └── OrderManager.mq5    # Order execution
└── Utils/
    ├── Logger.mq5          # Performance logging
    └── Helper.mq5          # Utility functions
```

## Disclaimer

This EA is for educational and backtesting purposes. Always test thoroughly on a demo account before live trading. Past performance does not guarantee future results. Trade responsibly and never risk more than you can afford to lose.

---

**Version**: 1.0  
**Last Updated**: 2026-07-04  
**Author**: Professional Trading Systems