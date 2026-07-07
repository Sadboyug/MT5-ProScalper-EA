//+------------------------------------------------------------------+
//|                                                          Ted.mq5 |
//|                                             © mcking_official7   |
//+------------------------------------------------------------------+
#property copyright "© mcking_official7"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Files\File.mqh>

CTrade         trade;
CPositionInfo  m_position;
CSymbolInfo    m_symbol;
CAccountInfo   m_account;

//--- Enums
enum ENUM_INDICATOR_ROLE {
   ROLE_FILTER,   // Acts as Confluence Gatekeeper
   ROLE_TRIGGER   // Acts as Active Entry Trigger
};

//--- Inputs
input group "=== Bot Identity ==="
input int      InpMagicScalp     = 1000;
input int      InpMagicIntraday  = 2000;

input group "=== Risk Management ==="
input double   InpRiskScalp      = 0.5;       // Scalp Risk % per trade
input double   InpRiskIntraday   = 1.0;       // Intraday Risk % per trade
input bool     InpCounterTrend   = true;      // Allow Counter-Trend Scalps
input double   InpStopLossPips   = 15.0;      // Default Stop Loss in Pips
input double   InpTakeProfitPips = 30.0;      // Default Take Profit in Pips
input double   InpTrailingStop   = 10.0;      // Trailing Stop in Pips

input group "=== Indicator Matrix ==="
input ENUM_INDICATOR_ROLE InpMaRole = ROLE_TRIGGER; 
input int                 InpMaPeriodFast = 9;   
input int                 InpMaPeriodSlow = 21;  
input ENUM_INDICATOR_ROLE InpRsiRole = ROLE_FILTER; 
input int                 InpRsiPeriod = 14;        

input group "=== Institutional Filters ==="
input int      InpNewsPauseMins  = 30;        // Pause trading X mins before/after High Impact News

//--- Global Variables
int ma_fast_handle, ma_slow_handle, rsi_handle;
double ma_fast_buffer[], ma_slow_buffer[], rsi_buffer[];
string bot_status_intraday = "Initializing...";
string bot_status_scalper = "Initializing...";
int macro_bias = 0; // 1 = Bullish, -1 = Bearish, 0 = Chop

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   m_symbol.Name(_Symbol);
   m_symbol.RefreshRates();
   trade.SetExpertMagicNumber(InpMagicIntraday);
   
   //--- Initialize Indicators
   ma_fast_handle = iMA(_Symbol, PERIOD_CURRENT, InpMaPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
   ma_slow_handle = iMA(_Symbol, PERIOD_CURRENT, InpMaPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);
   
   if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
     {
      Print("Error initializing indicator handles!");
      return(INIT_FAILED);
     }
     
   ArraySetAsSeries(ma_fast_buffer, true);
   ArraySetAsSeries(ma_slow_buffer, true);
   ArraySetAsSeries(rsi_buffer, true);

   CreateDashboard();
   EventSetTimer(1);
   
   if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_TO_PHONE))
      Print("WARNING: Push notifications to MQID are disabled.");

   Print("Ted is online. Let's hunt.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   IndicatorRelease(ma_fast_handle);
   IndicatorRelease(ma_slow_handle);
   IndicatorRelease(rsi_handle);
   ObjectsDeleteAll(0, "TED_");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!m_symbol.RefreshRates()) return;

   // 1. UPDATE BUFFERS
   if(CopyBuffer(ma_fast_handle, 0, 0, 3, ma_fast_buffer) < 0) return;
   if(CopyBuffer(ma_slow_handle, 0, 0, 3, ma_slow_buffer) < 0) return;
   if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 0) return;
   
   // 2. CHECK NEWS CALENDAR
   if(IsHighImpactNewsApproaching()) 
     {
      bot_status_intraday = "PAUSED: High Impact News";
      bot_status_scalper = "PAUSED: High Impact News";
      return; 
     }
   
   // 3. MULTI-TIMEFRAME ANALYSIS (H4 Bias)
   macro_bias = GetHTFBias(); 
   
   // 4. TRADE MANAGEMENT (Trailing Stops)
   ManageOpenPositions();
   
   // 5. ENTRY LOGIC - DUAL PROFILES
   CheckSMC_IntradaySetup(macro_bias);
   CheckScalperSetup(macro_bias);
  }

//+------------------------------------------------------------------+
//| Timer function for Dashboard Updates                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//| CORE LOGIC FUNCTIONS                                             |
//+------------------------------------------------------------------+

// Checks MT5 Economic Calendar for High Impact News
bool IsHighImpactNewsApproaching()
  {
   MqlCalendarValue values[];
   datetime now = TimeCurrent();
   datetime end = now + (InpNewsPauseMins * 60);
   
   if(CalendarValueHistoryByEvent(values, now, end))
     {
      for(int i=0; i<ArraySize(values); i++)
        {
         // Assuming importance 3 is High Impact
         if(values[i].importance == 3) return true; 
        }
     }
   return false;
  }

// Determines Institutional Bias based on H4 50 EMA
int GetHTFBias()
  {
   double h4_ema[];
   int handle = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   ArraySetAsSeries(h4_ema, true);
   if(CopyBuffer(handle, 0, 0, 1, h4_ema) > 0)
     {
      IndicatorRelease(handle);
      if(m_symbol.Ask() > h4_ema[0]) return 1;  // Bullish
      if(m_symbol.Bid() < h4_ema[0]) return -1; // Bearish
     }
   IndicatorRelease(handle);
   return 0; // Chop
  }

// Calculates dynamic lot size based on account balance and risk %
double CalculateLotSize(double risk_percent, double sl_pips)
  {
   double balance = m_account.Balance();
   double risk_amount = balance * (risk_percent / 100.0);
   double tick_value = m_symbol.TickValue();
   double tick_size = m_symbol.TickSize();
   
   if(sl_pips <= 0 || tick_value <= 0) return m_symbol.LotsMin();
   
   double step_vol = m_symbol.LotsStep();
   double lot = risk_amount / (sl_pips * 10 * tick_value); // Assuming standard 5-digit broker
   lot = MathFloor(lot / step_vol) * step_vol;
   
   if(lot < m_symbol.LotsMin()) lot = m_symbol.LotsMin();
   if(lot > m_symbol.LotsMax()) lot = m_symbol.LotsMax();
   return lot;
  }

// Active Trade Manager
void ManageOpenPositions()
  {
   double point = m_symbol.Point();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol)
           {
            double current_sl = m_position.StopLoss();
            double current_price = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
            
            // Basic Trailing Stop Logic
            if(m_position.PositionType() == POSITION_TYPE_BUY)
              {
               if(current_price - m_position.PriceOpen() > InpTrailingStop * point * 10)
                 {
                  double new_sl = current_price - (InpTrailingStop * point * 10);
                  if(new_sl > current_sl) trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
                 }
              }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
              {
               if(m_position.PriceOpen() - current_price > InpTrailingStop * point * 10)
                 {
                  double new_sl = current_price + (InpTrailingStop * point * 10);
                  if(new_sl < current_sl || current_sl == 0) trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
                 }
              }
           }
        }
     }
  }

//--- INTRADAY ENGINE (Pro-Trend Only)
void CheckSMC_IntradaySetup(int bias)
  {
   bot_status_intraday = "Scanning for SMC POI...";
   if(PositionsTotal() > 0) return; // Wait for flat book for this example

   double point = m_symbol.Point();
   
   // Simplistic Fair Value Gap (FVG) Check on the last 3 candles
   double c1_high = iHigh(_Symbol, PERIOD_CURRENT, 3);
   double c3_low = iLow(_Symbol, PERIOD_CURRENT, 1);
   bool is_bullish_fvg = (c3_low > c1_high);
   
   if(bias == 1 && is_bullish_fvg)
     {
      // Confluence Check: RSI Filter
      if(InpRsiRole == ROLE_FILTER && rsi_buffer[0] > 70) 
        {
         bot_status_intraday = "RSI Overbought - Entry Denied";
         return; 
        }

      bot_status_intraday = "FVG Detected. Executing Long.";
      double lot = CalculateLotSize(InpRiskIntraday, InpStopLossPips);
      double sl = m_symbol.Ask() - (InpStopLossPips * 10 * point);
      double tp = m_symbol.Ask() + (InpTakeProfitPips * 10 * point);
      
      trade.SetExpertMagicNumber(InpMagicIntraday);
      if(trade.Buy(lot, _Symbol, m_symbol.Ask(), sl, tp, "Ted Intraday Long"))
        {
         LogTradeData("SMC_FVG", "Long", "Intraday");
         SendNotification("Ted: Intraday Long Executed on FVG.");
        }
     }
  }

//--- SCALPER ENGINE (Allows Counter-Trend)
void CheckScalperSetup(int bias)
  {
   bot_status_scalper = "Hunting MA/RSI Triggers...";
   if(PositionsTotal() > 0) return;

   double point = m_symbol.Point();
   bool ma_cross_up = (ma_fast_buffer[1] <= ma_slow_buffer[1] && ma_fast_buffer[0] > ma_slow_buffer[0]);
   bool ma_cross_down = (ma_fast_buffer[1] >= ma_slow_buffer[1] && ma_fast_buffer[0] < ma_slow_buffer[0]);
   
   // Trade Logic: MA Trigger with RSI confirmation
   if(InpMaRole == ROLE_TRIGGER && ma_cross_down && InpCounterTrend)
     {
      if(bias == 1) bot_status_scalper = "Counter-Trend Short Triggered!";
      else bot_status_scalper = "Pro-Trend Short Triggered!";
      
      // Cut risk in half if counter-trend
      double active_risk = (bias == 1) ? (InpRiskScalp / 2.0) : InpRiskScalp;
      double lot = CalculateLotSize(active_risk, InpStopLossPips / 2.0); // Tighter stop for scalps
      double sl = m_symbol.Bid() + ((InpStopLossPips / 2.0) * 10 * point);
      double tp = m_symbol.Bid() - ((InpTakeProfitPips / 2.0) * 10 * point);
      
      trade.SetExpertMagicNumber(InpMagicScalp);
      if(trade.Sell(lot, _Symbol, m_symbol.Bid(), sl, tp, "Ted Scalp Short"))
        {
         LogTradeData("MA_Cross", "Short", "Scalp");
         SendNotification("Ted: Scalp Short Executed.");
        }
     }
  }

//--- CSV LOGGING (The Learning Matrix)
void LogTradeData(string trigger, string direction, string profile)
  {
   int file_handle = FileOpen("Ted_Trade_Scorecard.csv", FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(file_handle != INVALID_HANDLE)
     {
      FileSeek(file_handle, 0, SEEK_END);
      FileWrite(file_handle, TimeToString(TimeCurrent()), profile, trigger, direction, macro_bias);
      FileClose(file_handle);
     }
  }

//+------------------------------------------------------------------+
//| UI / DASHBOARD FUNCTIONS                                         |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   ObjectCreate(0, "TED_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "TED_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "TED_BG", OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, "TED_BG", OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, "TED_BG", OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, "TED_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "TED_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   
   CreateLabel("TED_TITLE", "=== TED ALGORITHMIC SYSTEM ===", 15, 15, clrWhite);
   CreateLabel("TED_BIAS", "H4 Macro Bias: ", 15, 35, clrSilver);
   CreateLabel("TED_STATUS_1", "Intraday: ", 15, 60, clrSilver);
   CreateLabel("TED_STATUS_2", "Scalper: ", 15, 80, clrSilver);
  }

void CreateLabel(string name, string text, int x, int y, color clr)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
  }

void UpdateDashboard()
  {
   string bias_text = (macro_bias == 1) ? "BULLISH" : (macro_bias == -1) ? "BEARISH" : "CHOP/FLAT";
   color bias_color = (macro_bias == 1) ? clrLimeGreen : (macro_bias == -1) ? clrRed : clrYellow;
   
   ObjectSetString(0, "TED_BIAS", OBJPROP_TEXT, "H4 Macro Bias: " + bias_text);
   ObjectSetInteger(0, "TED_BIAS", OBJPROP_COLOR, bias_color);
   
   ObjectSetString(0, "TED_STATUS_1", OBJPROP_TEXT, "Intraday: " + bot_status_intraday);
   ObjectSetString(0, "TED_STATUS_2", OBJPROP_TEXT, "Scalper: " + bot_status_scalper);
  }
//+------------------------------------------------------------------+