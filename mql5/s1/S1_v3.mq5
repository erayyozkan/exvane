//+------------------------------------------------------------------+
//| S1_v3.mq5                                                        |
//| Strategy 1: two-period one-sided break, body-pullback entry      |
//|                                                                  |
//| v3 = v2 bug fixes + research switches + CSV research logging.    |
//| Defaults reproduce the original EA's trading logic exactly       |
//| (legacy ladder unit, 8-tick TP shift, $4 sizing commission).     |
//|                                                                  |
//| Fixes carried from v2                                            |
//|  - magic number filtering on every position/order loop           |
//|  - hash key lifetime from PeriodSeconds(HigherTimeframe), not 8h |
//|  - marubozu rescan respects LastCandleNoTrade on longs too       |
//|  - DBL_MAX sentinel (SHORT_MAX broke longs above 32767)          |
//|  - EarlyTrade evaluates once per period                          |
//|  - stale hash keys swept once per period                         |
//| New in v3                                                        |
//|  - EntryTimeframe input: body scan no longer depends on the chart|
//|  - SL_Mode: 0 = trade-period extreme (EA), 1 = bias-period       |
//|    extreme (wider stop, least-bad variant in the research)       |
//|  - LadderUnitIsRisk: true = ladder steps in true risk R (spec);  |
//|    false = legacy (|open - TP| / 2, which inflates r)            |
//|  - TPShiftTicks / SizingCommission inputs (legacy 8 / 4)         |
//|  - SizingBalance > 0: size from a fixed balance (tester checks)  |
//|  - market entries skipped when the stop is already invalid      |
//|  - hedging-account guard (the 2-3 leg design needs hedging)      |
//|  - optional CSV logging of setups and deals (FILE_COMMON)        |
//| Other intentional differences from the original (defaults)       |
//|  - lot size uses the broker tick value (original forced 1.0 for  |
//|    EURUSD/XAUUSD: identical on USD accounts, wrong on EUR ones)  |
//|  - entry/SL/TP are normalised to _Digits before use              |
//|  - marubozu wick test has a half-tick tolerance (the original    |
//|    double comparison missed exact 5-tick wicks: ~7 of 16k setups)|
//|  - MaxLotPerOrder = 0 means no extra cap (broker maximum only)   |
//|                                                                  |
//| Entry models (spec):                                             |
//|  Standard  : long at the lowest M15 body of the trade period,    |
//|              short at the highest body                           |
//|  Mitigation: long at the HIGH of the lowest-body candle, short   |
//|              at the LOW of the highest-body candle               |
//|  EarlyTrade: the forming period breaks the previous period on one|
//|              side only -> order from the previous period's body  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Eray Yozkan"
#property link      "https://github.com/erayyozkan/exvane"
#property version   "3.00"
#property description "S1: two-period one-sided break with body-pullback entry."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Generic\HashMap.mqh>
#include <Generic\ArrayList.mqh>

//+------------------------------------------------------------------+
class FVG
  {
public:
   double            upper;
   double            lower;
   datetime          time;
  };

enum var0
  {
   buys = 0,//only longs
   sells = 1,//only sells
   both = 2//longs & sells
  };

enum ENUM_SL_MODE
  {
   SL_TRADE_PERIOD = 0, // trade-period extreme (original EA)
   SL_BIAS_PERIOD = 1   // bias-period extreme (wider stop)
  };

CTrade mTrade;
COrderInfo mOrder;
CPositionInfo mPos;

input group "Identification"
input int    magicNumber = 24680;               // Magic number (must differ from other EAs on the account)

input group "Signal"
input var0   tradeType = both;
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_H4;   // Bias timeframe
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_M15;   // Body-scan / trailing timeframe

input group "Entry"
input bool   Mitigation = false;
input bool   EarlyTrade = false;
input int    MarubozuTick = 5;
input bool   FVG_NoTrade = true;
input bool   LastCandleNoTrade = true;
input int    EntryOffsetTick = 2;
input int    StoplossOffsetTick = 2;
input ENUM_SL_MODE SL_Mode = SL_TRADE_PERIOD;

input group "Exits"
input double TP_RR = 2;
input bool   trail_profit = true;
input double Trail_RR = 5;
input int    TrailExitBars = 3;                 // EntryTimeframe bars: low0<low1<low2 (spec)
input bool   breakeven_when_tphit = true;       // 2r -> stop to entry
input bool   LadderUnitIsRisk = false;          // true = spec (r = entry-SL); false = legacy
input bool   TP_Version2 = false;
input double TP_Version2_TP = 3;

input group "Lifetime / sessions"
input int    Position_SS = 2;
input int    Order_SS = 2;
input bool   EnableTradeTime = true;
input string NoTradeStart = "23:45";
input string NoTradeEnd = "00:45";

input group "Risk / costs"
input double RiskPercentage = 0.5;              // % of balance per leg
input double SizingBalance = 0;                 // >0: size every trade from this fixed balance (tester checks); 0 = current balance
input double SizingCommission = 4;              // money per lot added to risk in sizing (legacy 4)
input int    TPShiftTicks = 8;                  // ticks added to every TP (legacy 4*2)
input double TickValueOverride = 0;             // 0 = broker tick value
input double MaxLotPerOrder = 0;               // 0 = broker maximum only
input double MinRiskSpreadMult = 0;             // skip if risk < k x spread (0 = off)

input group "Research"
input bool   LogCSV = false;                    // write S1_setups_/S1_deals_ CSV to Common\Files
input bool   AllowNetting = false;              // trade on a netting account anyway (not advised)

double tick_size;
CHashMap<string, double> tpHash;   // key -> stored 2R TP price (0 = trailing mode)
CHashMap<string, double> rHash;    // key -> risk distance at placement

datetime time_2, time_1, time_0;
datetime time_close_pos, time_close_order;
double high_2, high_1, high_0;
double low_2, low_1, low_0;
double close_0;
datetime last_candle;
datetime early_done_long, early_done_short;
int fhSetups = INVALID_HANDLE, fhDeals = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!AllowNetting && AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("S1 v3: account is not hedging. The 2R + trail legs would net into one position. Set AllowNetting=true to override.");
      return(INIT_FAILED);
     }
   mTrade.SetExpertMagicNumber(magicNumber);
   tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   UpdatePrice();
   ObjectCreate(0, "Rec_2", OBJ_RECTANGLE, 0, time_2, high_2, time_1, low_2);
   ObjectCreate(0, "Rec_1", OBJ_RECTANGLE, 0, time_1, high_1, time_0, low_1);
   last_candle = time_0;
   early_done_long = 0;
   early_done_short = 0;

   if(LogCSV)
     {
      string sfx = Symbol() + "_" + IntegerToString(magicNumber) + ".csv";
      fhSetups = FileOpen("S1_setups_" + sfx, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
      fhDeals = FileOpen("S1_deals_" + sfx, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
      if(fhSetups != INVALID_HANDLE)
         FileWrite(fhSetups, "time", "key", "dir", "code", "entry", "sl", "tp", "risk_pts", "spread_pts", "bid", "ask", "market");
      if(fhDeals != INVALID_HANDLE)
         FileWrite(fhDeals, "time", "position", "key", "entry", "price", "volume", "profit", "commission", "swap", "reason");
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "Rec");
   FlushDeals();
   if(fhSetups != INVALID_HANDLE) FileClose(fhSetups);
   if(fhDeals != INVALID_HANDLE) FileClose(fhDeals);
  }
//+------------------------------------------------------------------+
bool IsOurPosition() { return (mPos.Magic() == magicNumber && mPos.Symbol() == Symbol()); }
bool IsOurOrder()    { return (mOrder.Magic() == magicNumber && mOrder.Symbol() == Symbol()); }
//+------------------------------------------------------------------+
bool InNoTrade()
  {
   if(!EnableTradeTime) return false;
   datetime s = StringToTime(NoTradeStart), e = StringToTime(NoTradeEnd), now = TimeCurrent();
   if(s < e) return (now >= s && now < e);
   return (now >= s || now < e);
  }
//+------------------------------------------------------------------+
//| Remove hash keys that no longer belong to any position or order  |
//+------------------------------------------------------------------+
void SweepKeys()
  {
   string keys[];
   double vals[];
   ArrayResize(keys, tpHash.Count());
   ArrayResize(vals, tpHash.Count());
   int n = tpHash.CopyTo(keys, vals);
   for(int k = 0; k < n; k++)
     {
      bool used = false;
      for(int i = PositionsTotal() - 1; i >= 0 && !used; i--)
         if(mPos.SelectByIndex(i) && IsOurPosition() && mPos.Comment() == keys[k]) used = true;
      for(int i = OrdersTotal() - 1; i >= 0 && !used; i--)
         if(mOrder.SelectByIndex(i) && IsOurOrder() && mOrder.Comment() == keys[k]) used = true;
      if(!used)
        {
         tpHash.Remove(keys[k]);
         rHash.Remove(keys[k]);
        }
     }
  }
//+------------------------------------------------------------------+
bool TrailExit(int dir, datetime posTime)
  {
   if(iTime(Symbol(), EntryTimeframe, 0) <= posTime) return false;
   for(int k = 0; k < TrailExitBars - 1; k++)
     {
      if(dir > 0 && !(iLow(Symbol(), EntryTimeframe, k) < iLow(Symbol(), EntryTimeframe, k + 1))) return false;
      if(dir < 0 && !(iHigh(Symbol(), EntryTimeframe, k) > iHigh(Symbol(), EntryTimeframe, k + 1))) return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdatePrice();
   static datetime last_flush = 0;
   if(fhDeals != INVALID_HANDLE && iTime(Symbol(), EntryTimeframe, 0) != last_flush)
     {
      last_flush = iTime(Symbol(), EntryTimeframe, 0);
      FlushDeals();
     }
   int ago_2 = FirstBarAtOrAfter(time_2);
   int ago_1 = FirstBarAtOrAfter(time_1);
   int ago_0 = FirstBarAtOrAfter(time_0);
   bool inNoTrade = InNoTrade();

//--- manage positions
   for(int i = PositionsTotal() - 1; i >= 0; i -= 1)
     {
      if(!mPos.SelectByIndex(i) || !IsOurPosition())
         continue;
      if((mPos.Time() < time_close_pos) || inNoTrade)
        {
         mTrade.PositionClose(mPos.Ticket());
         continue;
        }
      if(mPos.TakeProfit() > 0)
         continue;   // fixed-TP legs are left to the server
      double tp;
      if(!tpHash.TryGetValue(mPos.Comment(), tp))
         continue;
      int dir = (mPos.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      if(tp == 0)
        {
         if(TrailExit(dir, mPos.Time()))
            mTrade.PositionClose(mPos.Ticket());
         continue;
        }
      double r = MathAbs(mPos.PriceOpen() - tp) / 2;
      double rr;
      if(LadderUnitIsRisk && rHash.TryGetValue(mPos.Comment(), rr) && rr > 0)
         r = rr;
      double curr_r = MathFloor(dir * (mPos.PriceCurrent() - mPos.PriceOpen()) / r);
      if(dir * (mPos.PriceCurrent() - tp) > 0 && curr_r < TP_RR)
         curr_r = TP_RR;
      if(curr_r >= Trail_RR)
         tpHash.TrySetValue(mPos.Comment(), 0);
      else
         if(breakeven_when_tphit ? curr_r >= TP_RR : curr_r > TP_RR)   // legacy threshold; ladder offsets use 2
           {
            double new_sl = NormalizeDouble(mPos.PriceOpen() + dir * (curr_r - 2) * r, _Digits);
            if(dir * (new_sl - mPos.StopLoss()) > 0)
               mTrade.PositionModify(mPos.Ticket(), new_sl, 0);
           }
     }

//--- manage pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i -= 1)
     {
      if(mOrder.SelectByIndex(i) && IsOurOrder() && (mOrder.TimeSetup() < time_close_order || inNoTrade))
         mTrade.OrderDelete(mOrder.Ticket());
     }

   ObjectCreate(0, "Rec_2", OBJ_RECTANGLE, 0, time_2, high_2, time_1, low_2);
   ObjectCreate(0, "Rec_1", OBJ_RECTANGLE, 0, time_1, high_1, time_0, low_1);

//--- Standard / Mitigation: once at the start of each bias period
   if(time_0 > last_candle && !EarlyTrade && !inNoTrade)
     {
      SweepKeys();
      if((tradeType == buys || tradeType == both) && high_1 > high_2 && low_1 >= low_2)
         Entry(1, ago_0, ago_1, ago_2);
      if((tradeType == sells || tradeType == both) && low_1 < low_2 && high_1 <= high_2)
         Entry(-1, ago_0, ago_1, ago_2);
      last_candle = time_0;
     }

//--- EarlyTrade: once per period and direction, at the break
   if(EarlyTrade && !inNoTrade)
     {
      if(early_done_long != time_0 && (tradeType == buys || tradeType == both) && high_0 > high_1 && low_0 >= low_1)
        {
         early_done_long = time_0;
         SweepKeys();
         Entry(1, ago_0, ago_1, ago_2);
        }
      if(early_done_short != time_0 && (tradeType == sells || tradeType == both) && low_0 < low_1 && high_0 <= high_1)
        {
         early_done_short = time_0;
         SweepKeys();
         Entry(-1, ago_0, ago_1, ago_2);
        }
     }
  }
//+------------------------------------------------------------------+
int FirstBarAtOrAfter(datetime t)
  {
   int a = iBarShift(Symbol(), EntryTimeframe, t);
   while(a > 0 && iTime(Symbol(), EntryTimeframe, a) < t)
      a -= 1;
   return a;
  }
//+------------------------------------------------------------------+
double PositionSize(double risk_pct, double loss)
  {
   double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   if(TickValueOverride > 0)
      tick_value = TickValueOverride;
   double vol_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double balance = SizingBalance > 0 ? SizingBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double pos_size = (balance * risk_pct / 100) / (loss * tick_value / tick_size + SizingCommission);
   double max_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if(MaxLotPerOrder > 0)
      max_vol = MathMin(max_vol, MaxLotPerOrder);
   double min_vol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double round_size = MathFloor(pos_size / vol_step) * vol_step;
   return MathMax(MathMin(max_vol, round_size), min_vol);
  }
//+------------------------------------------------------------------+
void UpdatePrice()
  {
   time_2 = iTime(Symbol(), HigherTimeframe, 2);
   time_1 = iTime(Symbol(), HigherTimeframe, 1);
   time_0 = iTime(Symbol(), HigherTimeframe, 0);
   high_2 = iHigh(Symbol(), HigherTimeframe, 2);
   high_1 = iHigh(Symbol(), HigherTimeframe, 1);
   high_0 = iHigh(Symbol(), HigherTimeframe, 0);
   low_2  = iLow(Symbol(), HigherTimeframe, 2);
   low_1  = iLow(Symbol(), HigherTimeframe, 1);
   low_0  = iLow(Symbol(), HigherTimeframe, 0);
   close_0 = iClose(Symbol(), HigherTimeframe, 0);
   time_close_pos = iTime(Symbol(), HigherTimeframe, Position_SS - 1);
   time_close_order = iTime(Symbol(), HigherTimeframe, Order_SS - 1);
  }
//+------------------------------------------------------------------+
void LogSetup(string key, int dir, int code, double entry, double sl, double tp, bool market)
  {
   if(fhSetups == INVALID_HANDLE) return;
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID), ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   FileWrite(fhSetups, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), key, dir, code,
             DoubleToString(entry, _Digits), DoubleToString(sl, _Digits), DoubleToString(tp, _Digits),
             DoubleToString(MathAbs(entry - sl) / _Point, 1), DoubleToString((ask - bid) / _Point, 1),
             DoubleToString(bid, _Digits), DoubleToString(ask, _Digits), market ? 1 : 0);
  }
//+------------------------------------------------------------------+
//| Entry computation. code: 0 placed, 2 last candle, 3 FVG,         |
//| 4 no bars / no level, 5 stop invalid, 6 risk below spread guard  |
//+------------------------------------------------------------------+
void Entry(int dir, int ago_0, int ago_1, int ago_2)
  {
   string key = (dir > 0 ? "L" : "S") + IntegerToString((long)(time_0 + 2 * PeriodSeconds(HigherTimeframe)));
   double entry_point = 0;
   CArrayList<FVG*> fvgList;

//--- FVGs formed between the bias-period open and now
   for(int i = ago_2; i > ago_0; i--)
     {
      if(dir > 0)
        {
         if(iClose(Symbol(), EntryTimeframe, i + 1) > iOpen(Symbol(), EntryTimeframe, i + 1) &&
            iLow(Symbol(), EntryTimeframe, i) > iHigh(Symbol(), EntryTimeframe, i + 2))
           {
            FVG *f = new FVG;
            f.upper = iLow(Symbol(), EntryTimeframe, i);
            f.lower = iHigh(Symbol(), EntryTimeframe, i + 2);
            f.time = iTime(Symbol(), EntryTimeframe, i);
            fvgList.Add(f);
           }
         for(int j = fvgList.Count() - 1; j >= 0; j--)
           {
            FVG *f;
            fvgList.TryGetValue(j, f);
            if(iLow(Symbol(), EntryTimeframe, i) <= f.upper) f.upper = iLow(Symbol(), EntryTimeframe, i);
           }
        }
      else
        {
         if(iClose(Symbol(), EntryTimeframe, i + 1) < iOpen(Symbol(), EntryTimeframe, i + 1) &&
            iHigh(Symbol(), EntryTimeframe, i) < iLow(Symbol(), EntryTimeframe, i + 2))
           {
            FVG *f = new FVG;
            f.upper = iLow(Symbol(), EntryTimeframe, i + 2);
            f.lower = iHigh(Symbol(), EntryTimeframe, i);
            f.time = iTime(Symbol(), EntryTimeframe, i);
            fvgList.Add(f);
           }
         for(int j = fvgList.Count() - 1; j >= 0; j--)
           {
            FVG *f;
            fvgList.TryGetValue(j, f);
            if(iHigh(Symbol(), EntryTimeframe, i) >= f.lower) f.lower = iHigh(Symbol(), EntryTimeframe, i);
           }
        }
     }

//--- extreme body of the trade period (with marubozu rule)
   double best = (dir > 0) ? DBL_MAX : -DBL_MAX;
   int maru_idx = -1;
   for(int pass = 0; pass < 2; pass++)
     {
      if(pass == 1)
        {
         if(maru_idx < 0) break;
         best = (dir > 0) ? DBL_MAX : -DBL_MAX;
        }
      int skip = (pass == 1) ? maru_idx : -1;
      for(int i = ago_1; i > ago_0; i--)
        {
         if(i == skip) continue;
         double o = iOpen(Symbol(), EntryTimeframe, i), c = iClose(Symbol(), EntryTimeframe, i);
         double body = (dir > 0) ? MathMin(o, c) : MathMax(o, c);
         if(dir * (best - body) > 0)   // strictly lower body (long) / higher body (short)
           {
            if(pass == 0)
              {
               double wick = (dir > 0) ? body - iLow(Symbol(), EntryTimeframe, i) : iHigh(Symbol(), EntryTimeframe, i) - body;
               maru_idx = (wick <= (MarubozuTick + 0.5) * tick_size) ? i : -1;
              }
            if(i == ago_0 + 1 && LastCandleNoTrade)
              {
               LogSetup(key, dir, 2, 0, 0, 0, false);
               DeleteFVG(fvgList);
               return;
              }
            if(dir > 0) entry_point = (Mitigation ? iHigh(Symbol(), EntryTimeframe, i) : body) + tick_size * EntryOffsetTick;
            else        entry_point = (Mitigation ? iLow(Symbol(), EntryTimeframe, i) : body) - tick_size * EntryOffsetTick;
            best = body;
           }
        }
     }
   if(entry_point <= 0)
     {
      LogSetup(key, dir, 4, 0, 0, 0, false);
      DeleteFVG(fvgList);
      return;
     }

   double sl;
   if(SL_Mode == SL_BIAS_PERIOD) sl = (dir > 0) ? low_2 - tick_size * StoplossOffsetTick : high_2 + tick_size * StoplossOffsetTick;
   else                          sl = (dir > 0) ? low_1 - tick_size * StoplossOffsetTick : high_1 + tick_size * StoplossOffsetTick;

   if(FVG_NoTrade)
      for(int j = 0; j < fvgList.Count(); j++)
        {
         FVG *f;
         fvgList.TryGetValue(j, f);
         if(sl >= f.lower && sl <= f.upper)
           {
            LogSetup(key, dir, 3, entry_point, sl, 0, false);
            DeleteFVG(fvgList);
            return;
           }
        }
   DeleteFVG(fvgList);

   double risk = dir * (entry_point - sl);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID), ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   if(risk <= 0 || (MinRiskSpreadMult > 0 && risk < MinRiskSpreadMult * (ask - bid)))
     {
      LogSetup(key, dir, 6, entry_point, sl, 0, false);
      return;
     }
   double shift = TPShiftTicks * tick_size;
   double tp  = NormalizeDouble(entry_point + dir * (risk * TP_RR + shift), _Digits);
   double tp2 = NormalizeDouble(entry_point + dir * (risk * TP_Version2_TP + shift), _Digits);
   entry_point = NormalizeDouble(entry_point, _Digits);
   sl = NormalizeDouble(sl, _Digits);

   bool market = (dir > 0) ? (close_0 <= entry_point) : (close_0 >= entry_point);
   if(market && ((dir > 0 && bid <= sl) || (dir < 0 && ask >= sl)))
     {
      LogSetup(key, dir, 5, entry_point, sl, tp, true);
      return;
     }
   if(!tpHash.Add(key, tp)) tpHash.TrySetValue(key, tp);
   if(!rHash.Add(key, risk)) rHash.TrySetValue(key, risk);
   LogSetup(key, dir, 0, entry_point, sl, tp, market);

   if(market)
     {
      double lots = PositionSize(RiskPercentage, dir > 0 ? ask - sl : sl - bid);
      if(dir > 0)
        {
         mTrade.Buy(lots, Symbol(), 0, sl, tp, key);
         if(trail_profit) mTrade.Buy(lots, Symbol(), 0, sl, 0, key);
         if(TP_Version2)  mTrade.Buy(lots, Symbol(), 0, sl, tp2, key);
        }
      else
        {
         mTrade.Sell(lots, Symbol(), 0, sl, tp, key);
         if(trail_profit) mTrade.Sell(lots, Symbol(), 0, sl, 0, key);
         if(TP_Version2)  mTrade.Sell(lots, Symbol(), 0, sl, tp2, key);
        }
     }
   else
     {
      double lots = PositionSize(RiskPercentage, risk);
      if(dir > 0)
        {
         mTrade.BuyLimit(lots, entry_point, Symbol(), sl, tp, ORDER_TIME_GTC, 0, key);
         if(trail_profit) mTrade.BuyLimit(lots, entry_point, Symbol(), sl, 0, ORDER_TIME_GTC, 0, key);
         if(TP_Version2)  mTrade.BuyLimit(lots, entry_point, Symbol(), sl, tp2, ORDER_TIME_GTC, 0, key);
        }
      else
        {
         mTrade.SellLimit(lots, entry_point, Symbol(), sl, tp, ORDER_TIME_GTC, 0, key);
         if(trail_profit) mTrade.SellLimit(lots, entry_point, Symbol(), sl, 0, ORDER_TIME_GTC, 0, key);
         if(TP_Version2)  mTrade.SellLimit(lots, entry_point, Symbol(), sl, tp2, ORDER_TIME_GTC, 0, key);
        }
     }
  }
//+------------------------------------------------------------------+
void DeleteFVG(CArrayList<FVG*> &fvgList)
  {
   for(int j = fvgList.Count() - 1; j >= 0; j--)
     {
      FVG *f;
      fvgList.TryGetValue(j, f);
      delete f;
     }
   fvgList.Clear();
  }
//+------------------------------------------------------------------+
//| Research log of this EA's deals (polled from deal history)      |
//+------------------------------------------------------------------+
ulong last_deal_logged = 0;
datetime last_deal_time = 0;
CHashMap<long, string> posKey;   // position id -> setup key (from the entry deal comment)

void FlushDeals()
  {
   if(fhDeals == INVALID_HANDLE)
      return;
   if(!HistorySelect(last_deal_time, TimeCurrent() + 60))
      return;
   int n = HistoryDealsTotal();
   for(int k = 0; k < n; k++)
     {
      ulong d = HistoryDealGetTicket(k);
      if(d == 0 || d <= last_deal_logged)
         continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != magicNumber || HistoryDealGetString(d, DEAL_SYMBOL) != Symbol())
         continue;
      long pos = HistoryDealGetInteger(d, DEAL_POSITION_ID);
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      string key = "";
      if(entry == DEAL_ENTRY_IN)
        {
         key = HistoryDealGetString(d, DEAL_COMMENT);
         if(!posKey.Add(pos, key)) posKey.TrySetValue(pos, key);
        }
      else
         posKey.TryGetValue(pos, key);
      FileWrite(fhDeals, TimeToString((datetime)HistoryDealGetInteger(d, DEAL_TIME), TIME_DATE | TIME_SECONDS),
                pos, key, entry, DoubleToString(HistoryDealGetDouble(d, DEAL_PRICE), _Digits),
                DoubleToString(HistoryDealGetDouble(d, DEAL_VOLUME), 2), DoubleToString(HistoryDealGetDouble(d, DEAL_PROFIT), 2),
                DoubleToString(HistoryDealGetDouble(d, DEAL_COMMISSION), 2), DoubleToString(HistoryDealGetDouble(d, DEAL_SWAP), 2),
                HistoryDealGetInteger(d, DEAL_REASON));
      last_deal_logged = d;
      last_deal_time = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
     }
  }
//+------------------------------------------------------------------+
