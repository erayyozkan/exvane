//+------------------------------------------------------------------+
//|                                             DSR_Ensemble_v6.mq5  |
//|                                                                  |
//|  DONCHIAN STOP-AND-REVERSE ENSEMBLE                              |
//|                                                                  |
//|  Hypothesis: price direction exhibits serial persistence. Hold    |
//|  the current direction until the market proves otherwise by       |
//|  breaking the opposite N-bar extreme, then reverse.               |
//|                                                                  |
//|  Design principle: ZERO FITTED PARAMETERS.                        |
//|    - Channel length N is never selected. Four lengths run at      |
//|      equal risk weight in a geometric ladder, converting          |
//|      parameter-selection risk into diversification.               |
//|    - Size is volatility-targeted: a scale input that multiplies   |
//|      the equity curve but cannot change WHICH trades are taken,   |
//|      therefore consumes no degrees of freedom.                    |
//|    - There is no entry signal. The exit IS the entry.             |
//|                                                                  |
//+------------------------------------------------------------------+
//|  CHANGES FROM v5:                                                 |
//|                                                                  |
//|  AC. HEDGING RESIDUAL RE-READ THE POSITION CACHE (live, hedging   |
//|     accounts only). GoToTarget() reduced opposing volume, then    |
//|     called CurrentNetLots() again to size the remainder. That is  |
//|     exactly the defect fixed in Reconcile() at v3 - the terminal  |
//|     cache lags the close requests, so the re-read reports MORE    |
//|     exposure than actually remains and the residual order is      |
//|     oversized, leaving a position larger than target. It survived |
//|     three review passes because the hedging branch is dead code   |
//|     on a netting account and never executes in the tester.        |
//|     v6 derives the residual arithmetically from the volume        |
//|     actually closed, so no cache read is involved.                |
//|                                                                   |
//|  AD. ReduceExposure() now returns the volume it actually closed   |
//|     rather than a bare success flag, which is what makes AC       |
//|     computable without touching the cache.                        |
//|                                                                  |
//+------------------------------------------------------------------+
//|  CHANGES FROM v4:                                                 |
//|                                                                  |
//|  Z. SWAP MISSING FROM THE RESEARCH FILE (material, and biased in  |
//|     the most dangerous direction). net_move_atr charged only      |
//|     spread and commission. An always-in system pays financing on  |
//|     every night it holds, and holding time scales with N: the     |
//|     N=20 rung turns over in days while N=160 can hold for months. |
//|     Omitting swap therefore did not add noise - it systematically |
//|     flattered exactly the slow rungs that were most likely to     |
//|     look profitable, and would have pushed the conclusion toward  |
//|     the answer one most wants to believe. v5 estimates financing  |
//|     from the symbol's swap rate and logs swap_atr as a separate   |
//|     column, so it can be inspected rather than trusted.           |
//|                                                                  |
//|  AA. REBALANCE BAND UNCLAMPED. A flip moves net exposure by       |
//|     2/activeCount of full size. Setting InpRebalanceBand above    |
//|     1/activeCount would have silently suppressed flips themselves |
//|     rather than only volatility drift - the strategy would stop   |
//|     reversing with no error anywhere. Now clamped at init.        |
//|                                                                  |
//|  AB. Population variance replaced with sample variance (n-1) in   |
//|     the per-rung t-statistic.                                     |
//|                                                                  |
//+------------------------------------------------------------------+
//|  CHANGES FROM v3:                                                 |
//|                                                                  |
//|  W. WALL-CLOCK THROTTLE DESTROYED EVERY BACKTEST (critical).      |
//|     The v3 retry throttle used GetTickCount(), which returns REAL |
//|     milliseconds since system start - it is NOT simulated by the  |
//|     Strategy Tester. A six-year backtest completes in seconds of  |
//|     wall time, so consecutive reversals separated by weeks of     |
//|     simulated time arrive milliseconds apart in real time and     |
//|     were throttled away. The EA would have executed roughly one   |
//|     trade per three real seconds instead of hundreds, silently,   |
//|     with no error and a plausible-looking equity curve. v4 uses   |
//|     TimeCurrent(), which the tester simulates correctly and which |
//|     is server time when live. This defect was introduced by the   |
//|     v3 fix itself - a guard added for live safety broke research. |
//|                                                                  |
//|  X. CSV FLOOD UNDER OPTIMISATION. OnInit opened two timestamped   |
//|     CSVs per pass. A walk-forward optimisation is hundreds of     |
//|     across parallel agents, so this produced hundreds of files    |
//|     and, because the tag derives from simulated start time,       |
//|     filename collisions between agents. Logging and the summary   |
//|     print are now suppressed during optimisation and active for   |
//|     single runs, which is when they are actually read.            |
//|                                                                  |
//|  Y. Throttle input clamped at zero (a negative value cast to      |
//|     unsigned would have blocked all trading permanently).         |
//|                                                                  |
//+------------------------------------------------------------------+
//|  CHANGES FROM v2:                                                 |
//|                                                                  |
//|  A. DOUBLE-ORDER RACE (critical, LIVE ONLY - invisible in the     |
//|     tester). v2 cleared the reconcile flag only after verifying   |
//|     CurrentNetLots() matched target. In the Strategy Tester the   |
//|     position cache updates synchronously, so this always passed.  |
//|     On a live server the terminal's position cache lags OrderSend |
//|     by some milliseconds, so the check would fail, the flag would |
//|     stay set, and the NEXT TICK would send a second order for the |
//|     same intent - repeatedly. That is a runaway position builder  |
//|     that no amount of backtesting would ever reveal. v3 clears    |
//|     the flag on a confirmed successful send and lets the next bar |
//|     correct any residual, with a retry throttle on failures.      |
//|                                                                  |
//|  B. CORRUPT QUANTISATION COUNTER. NormalizeSigned() incremented   |
//|     g_quantOverrides as a side effect, and was called from        |
//|     Reconcile() on every tick plus once more for verification.    |
//|     The count was inflated by orders of magnitude, so its         |
//|     "run is invalid" warning would fire on healthy runs. The      |
//|     function is now pure; the override is detected once, at the   |
//|     point of execution.                                           |
//|                                                                  |
//|  C. SILENT BAR SKIP. If a CopyHigh/Low/Close/Open call failed,    |
//|     AdvanceStates() returned after g_barCounter had already been  |
//|     incremented. That bar's signal was dropped permanently and    |
//|     holding periods drifted. v3 rolls back the bar marker so the  |
//|     bar is re-processed on the next tick.                         |
//|                                                                  |
//|  D. COST MEASURED AT EXIT ONLY. cost_atr used the spread at the   |
//|     moment of the flip. v3 averages entry and exit spread, which  |
//|     matters on gold where session spread varies severalfold.      |
//|                                                                  |
//+------------------------------------------------------------------+
//|  CHANGES FROM v1 - all six were defects, not preferences:         |
//|                                                                  |
//|  1. STATE/EXECUTION DESYNC (critical). v1 adjusted the position   |
//|     only on a flip. If the spread guard deferred that flip, or    |
//|     the order was rejected, the virtual states advanced while     |
//|     the real position did not - and nothing retried until the     |
//|     next flip, potentially months later on the N=160 rung. v2     |
//|     reconciles target vs actual on every bar and retries until    |
//|     the deviation clears.                                         |
//|                                                                  |
//|  2. NO VOLATILITY REBALANCING. Size is set from ATR at the moment |
//|     of a flip and then frozen. When ATR halves during a long      |
//|     hold, realised exposure silently drifts to double the target. |
//|     v2 rebalances through a deadband.                             |
//|                                                                  |
//|  3. NO COST ACCOUNTING IN THE RESEARCH FILE. v1 logged gross      |
//|     move in ATR units. Gross expectancy is not the question -     |
//|     net is. v2 logs cost_atr and net_move_atr per virtual trade.  |
//|                                                                  |
//|  4. WRONG ATR ON REBUILT STATES. v1 stamped historical entries    |
//|     with today's ATR, corrupting the first logged trade on every  |
//|     rung. v2 reads the D1 ATR as of the actual entry bar.         |
//|                                                                  |
//|  5. AMBIGUOUS net_signal_after. v1 wrote it mid-loop, so the      |
//|     value depended on ladder iteration order. v2 resolves all     |
//|     states first, then logs.                                      |
//|                                                                  |
//|  6. INFLATED bars_held ON REBUILT STATES (entryBar forced to 0).  |
//|     v2 back-dates the bar counter so holding periods are correct. |
//|                                                                  |
//|  Added: per-rung t-statistic on net ATR return, so the journal    |
//|  itself reports whether the effect is separable from zero.        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Eray Yozkan"
#property link      "https://github.com/erayyozkan/exvane"
#property version   "6.00"
#property description "Donchian stop-and-reverse ensemble. Always in the market. Zero fitted parameters."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_BREAK_MODE
  {
   BREAK_CLOSE    = 0,  // Close beyond channel (default - fewer flips, no wick noise)
   BREAK_EXTREME  = 1   // Intrabar high/low beyond channel (classic Donchian)
  };

enum ENUM_CAPITAL_BASE
  {
   CAP_FIXED      = 0,  // Fixed base (non-compounding - additive research statistics)
   CAP_EQUITY     = 1   // Live equity (compounding)
  };

//+------------------------------------------------------------------+
//| INPUTS - STRUCTURAL                                              |
//| Set by logic. FROZEN. Never place these in an optimisation pass.  |
//| They define the hypothesis; they are not where the edge lives.    |
//+------------------------------------------------------------------+
input group "=== STRUCTURAL (frozen - do not optimise) ==="
input ENUM_TIMEFRAMES   InpSignalTF       = PERIOD_H1;   // Signal timeframe (bar clock)
input ENUM_BREAK_MODE   InpBreakMode      = BREAK_CLOSE; // Reversal trigger definition
input int               InpN1             = 20;          // Channel length 1
input int               InpN2             = 40;          // Channel length 2
input int               InpN3             = 80;          // Channel length 3
input int               InpN4             = 160;         // Channel length 4
input bool              InpUseN1          = true;        // Enable ladder rung 1
input bool              InpUseN2          = true;        // Enable ladder rung 2
input bool              InpUseN3          = true;        // Enable ladder rung 3
input bool              InpUseN4          = true;        // Enable ladder rung 4

//+------------------------------------------------------------------+
//| INPUTS - EXECUTION                                                |
//| Set from the cost/tracking-error tradeoff, not from the equity    |
//| curve. Does not change trade direction, only rebalance frequency. |
//+------------------------------------------------------------------+
input group "=== EXECUTION (set by cost logic - frozen) ==="
input double            InpRebalanceBand  = 0.25;        // Rebalance deadband, fraction of full size
input int               InpRetryThrottleSec = 3;         // Min seconds between reconcile retries

//+------------------------------------------------------------------+
//| INPUTS - SCALE                                                   |
//| These multiply the equity curve linearly. They cannot change      |
//| which trades are taken, so they consume no degrees of freedom.    |
//+------------------------------------------------------------------+
input group "=== SCALE (free - cannot overfit) ==="
input double            InpVolTargetPct   = 1.0;         // Daily volatility target, % of capital
input int               InpPortfolioSlots = 1;           // Instruments sharing this capital (divides target)
input int               InpATRPeriodD1    = 20;          // ATR period on D1 (volatility estimator)
input ENUM_CAPITAL_BASE InpCapitalBase    = CAP_FIXED;   // Capital base for sizing
input double            InpFixedCapital   = 0;           // Fixed capital (0 = use initial balance)

//+------------------------------------------------------------------+
//| INPUTS - COSTS                                                   |
//| Broker facts, not parameters. Set honestly from the account spec  |
//| or every number below is fiction.                                 |
//+------------------------------------------------------------------+
input group "=== COSTS (broker facts - set honestly) ==="
input double            InpCommPerLotSide = 3.50;        // Commission, account ccy per lot PER SIDE
input int               InpSlippagePoints = 50;          // Max deviation, points

//+------------------------------------------------------------------+
//| INPUTS - SAFETY                                                  |
//| Live guards. Defaults OFF so research runs stay clean.            |
//+------------------------------------------------------------------+
input group "=== SAFETY (live guards - default off) ==="
input int               InpMaxSpreadPoints = 0;          // Defer trade if spread exceeds this (0 = off)
input double            InpKillSwitchDD    = 0;          // Flatten & halt at this % drawdown (0 = off)

//+------------------------------------------------------------------+
//| INPUTS - HOUSEKEEPING                                            |
//+------------------------------------------------------------------+
input group "=== HOUSEKEEPING ==="
input long              InpMagic          = 20260817;    // Magic number
input bool              InpLogVirtual     = true;        // Write per-subsystem virtual trade CSV
input bool              InpLogDeals       = true;        // Write executed deal CSV
input bool              InpShowPanel      = true;        // On-chart status panel

//+------------------------------------------------------------------+
//| Sub-system                                                       |
//+------------------------------------------------------------------+
struct SubSystem
  {
   int      n;                // channel length
   bool     active;
   int      state;            // -1 short, 0 uninitialised, +1 long
   datetime entryTime;
   double   entryPrice;
   double   entryATR;
   long     entryBar;
   int      entrySpreadPts;
   bool     synthetic;        // entry reconstructed at init rather than observed live
   int      flips;
   double   sumGrossATR;
   double   sumNetATR;
   double   sumNetATRSq;      // for the t-statistic
   double   wins;
   double   losses;
  };

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CTrade         mTrade;
CPositionInfo  mPos;

SubSystem      g_sub[4];
int            g_activeCount     = 0;
int            g_maxN            = 0;

int            g_atrHandle       = INVALID_HANDLE;
double         g_valuePerPrice   = 0;    // account ccy per 1.0 price move per 1.0 lot
double         g_volStep         = 0;
double         g_minVol          = 0;
double         g_maxVol          = 0;
int            g_volDigits       = 2;
double         g_capitalBase     = 0;
double         g_effVolTarget    = 0;    // after portfolio-slot division

datetime       g_lastBarTime     = 0;
long           g_barCounter      = 0;
bool           g_halted          = false;
bool           g_needReconcile   = true; // true at start: establish opening exposure
double         g_peakEquity      = 0;

int            g_quantOverrides  = 0;
datetime       g_lastSendTime    = 0;    // server time of last order sent
bool           g_isOptimising    = false;
double         g_band            = 0.25;  // clamped rebalance deadband
bool           g_swapModelled    = false;
int            g_sendFailures    = 0;
int            g_execCount       = 0;
int            g_deferCount      = 0;
int            g_rebalanceCount  = 0;
double         g_turnoverLots    = 0;
double         g_commReported    = 0;
double         g_commModelled    = 0;

int            g_fhVirtual       = INVALID_HANDLE;
int            g_fhDeals         = INVALID_HANDLE;
string         g_runTag          = "";
bool           g_hedging         = false;

//+------------------------------------------------------------------+
//| Expert initialisation                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- symbol facts --------------------------------------------------
   g_volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_minVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_maxVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(g_volStep <= 0)
     {
      Print("FATAL: SYMBOL_VOLUME_STEP is zero.");
      return(INIT_FAILED);
     }

   g_volDigits = 0;
   if(g_volStep * 10   >= 1) g_volDigits = 1;
   if(g_volStep * 100  >= 1) g_volDigits = 2;
   if(g_volStep * 1000 >= 1) g_volDigits = 3;
   if(g_volStep >= 1)        g_volDigits = 0;

//--- Contract value derived from the symbol spec.
//    (The earlier EAs hardcoded tick_value = 1 for XAUUSD, which is
//     broker-specific and silently wrong on most feeds.)
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickValue <= 0)
     {
      PrintFormat("FATAL: bad tick spec. tickValue=%.6f tickSize=%.6f", tickValue, tickSize);
      return(INIT_FAILED);
     }
   g_valuePerPrice = tickValue / tickSize;

//--- account mode --------------------------------------------------
   g_hedging = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
                == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(g_hedging)
      Print("NOTE: hedging account detected. Netting is preferred here - delta "
            "adjustments become close+reopen, which overstates transaction costs.");

//--- capital and volatility budget ---------------------------------
   g_isOptimising = (bool)MQLInfoInteger(MQL_OPTIMIZATION);

//--- Only the points-per-night swap mode can be modelled reliably
//    across brokers. Anything else is reported as unmodelled rather
//    than guessed, because a wrong financing figure is worse than a
//    visibly missing one.
   g_swapModelled = (SymbolInfoInteger(_Symbol, SYMBOL_SWAP_MODE)
                     == SYMBOL_SWAP_MODE_POINTS);

   g_capitalBase = (InpFixedCapital > 0) ? InpFixedCapital
                                         : AccountInfoDouble(ACCOUNT_BALANCE);
   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);

   int slots = (InpPortfolioSlots < 1) ? 1 : InpPortfolioSlots;
   g_effVolTarget = InpVolTargetPct / (double)slots;
   if(slots > 1)
      PrintFormat("Portfolio mode: %d slots -> effective vol target %.4f%% on this symbol.",
                  slots, g_effVolTarget);

//--- ladder --------------------------------------------------------
   int  nArr[4];
   bool useArr[4];
   nArr[0] = InpN1;  useArr[0] = InpUseN1;
   nArr[1] = InpN2;  useArr[1] = InpUseN2;
   nArr[2] = InpN3;  useArr[2] = InpUseN3;
   nArr[3] = InpN4;  useArr[3] = InpUseN4;

   g_activeCount = 0;
   g_maxN        = 0;
   for(int i = 0; i < 4; i++)
     {
      g_sub[i].n              = nArr[i];
      g_sub[i].active         = (useArr[i] && nArr[i] >= 2);
      g_sub[i].state          = 0;
      g_sub[i].entryTime      = 0;
      g_sub[i].entryPrice     = 0;
      g_sub[i].entryATR       = 0;
      g_sub[i].entryBar       = 0;
      g_sub[i].entrySpreadPts = 0;
      g_sub[i].synthetic      = false;
      g_sub[i].flips          = 0;
      g_sub[i].sumGrossATR    = 0;
      g_sub[i].sumNetATR      = 0;
      g_sub[i].sumNetATRSq    = 0;
      g_sub[i].wins           = 0;
      g_sub[i].losses         = 0;
      if(g_sub[i].active)
        {
         g_activeCount++;
         if(nArr[i] > g_maxN) g_maxN = nArr[i];
        }
     }

   if(g_activeCount == 0)
     {
      Print("FATAL: no active ladder rungs.");
      return(INIT_FAILED);
     }

//--- Clamp the rebalance deadband. A flip moves net exposure by
//    2/activeCount of full size; a band at or above 1/activeCount
//    would start swallowing flips rather than only volatility drift,
//    and the strategy would quietly stop reversing.
   g_band = InpRebalanceBand;
   double maxBand = 1.0 / (double)g_activeCount;
   if(g_band > maxBand)
     {
      PrintFormat("WARNING: InpRebalanceBand %.3f exceeds the safe maximum %.3f for "
                  "%d active rungs - it would suppress flips. Clamped to %.3f.",
                  g_band, maxBand, g_activeCount, maxBand);
      g_band = maxBand;
     }
   if(g_band < 0) g_band = 0;

//--- ATR handle ----------------------------------------------------
   g_atrHandle = iATR(_Symbol, PERIOD_D1, InpATRPeriodD1);
   if(g_atrHandle == INVALID_HANDLE)
     {
      Print("FATAL: could not create D1 ATR handle.");
      return(INIT_FAILED);
     }

   ConfigureTrade();

//--- wait for data -------------------------------------------------
   int guard = 0;
   while(!IsStopped() && guard < 200)
     {
      if(SymbolIsSynchronized(_Symbol) && Bars(_Symbol, InpSignalTF) > g_maxN + 5)
         break;
      Sleep(50);
      guard++;
     }

//--- rebuild sub-system states from history (restart-safe) ---------
   RebuildStates();

//--- diagnostics ---------------------------------------------------
   RunDiagnostics();

//--- CSV files -----------------------------------------------------
   g_runTag = StringFormat("%s_%s_%s", _Symbol, TFToStr(InpSignalTF),
                           TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   StringReplace(g_runTag, ".", "");
   StringReplace(g_runTag, ":", "");
   StringReplace(g_runTag, " ", "_");
   OpenLogs();

   PrintFormat("DSR Ensemble v6 init OK | rungs=%d maxN=%d valuePerPrice=%.4f hedging=%s",
               g_activeCount, g_maxN, g_valuePerPrice, (g_hedging ? "yes" : "no"));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialisation                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   PrintSummary();
   CloseLogs();
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(g_halted)
      return;

   CheckKillSwitch();
   if(g_halted)
      return;

//--- On a new bar: advance the virtual states, then flag for
//    reconciliation. State advance and execution are deliberately
//    decoupled so a deferred or failed order cannot leave the real
//    position permanently out of step with the model.
   datetime prevBarMark = g_lastBarTime;
   if(IsNewSignalBar())
     {
      if(AdvanceStates())
         g_needReconcile = true;
      else
         g_lastBarTime = prevBarMark;   // data not ready - retry this bar
     }

//--- Reconcile on every tick while a deviation is outstanding. This
//    covers flips, volatility drift, rejected orders, restarts and
//    manual interference with a single code path.
   if(g_needReconcile)
      Reconcile();

   if(InpShowPanel && !MQLInfoInteger(MQL_TESTER))
      DrawPanel();
  }

//+------------------------------------------------------------------+
//| Advance all sub-system states on the just-closed bar             |
//|                                                                  |
//| Two passes: resolve every state first, then log. This makes       |
//| net_signal_after independent of ladder iteration order.           |
//+------------------------------------------------------------------+
bool AdvanceStates()
  {
   int need = g_maxN + 4;
   double H[], L[], C[], O[];
   ArraySetAsSeries(H, true);
   ArraySetAsSeries(L, true);
   ArraySetAsSeries(C, true);
   ArraySetAsSeries(O, true);

//--- Any data failure must abort WITHOUT consuming the bar, otherwise
//    the signal is dropped permanently and holding periods drift.
   if(CopyHigh (_Symbol, InpSignalTF, 0, need, H) < need) return(false);
   if(CopyLow  (_Symbol, InpSignalTF, 0, need, L) < need) return(false);
   if(CopyClose(_Symbol, InpSignalTF, 0, need, C) < need) return(false);
   if(CopyOpen (_Symbol, InpSignalTF, 0, need, O) < need) return(false);

   double atr = GetATR();
   if(atr <= 0)
      return(false);

   g_barCounter++;

   datetime barTime  = iTime(_Symbol, InpSignalTF, 1);
   double   refPrice = C[1];
   int      spreadPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

//--- pass 1: resolve --------------------------------------------
   int  newState[4];
   bool changed[4];
   for(int i = 0; i < 4; i++)
     {
      newState[i] = g_sub[i].state;
      changed[i]  = false;
      if(!g_sub[i].active)
         continue;
      newState[i] = EvaluateState(H, L, C, O, g_sub[i].n, 1, g_sub[i].state);
      changed[i]  = (newState[i] != g_sub[i].state);
     }

   int netAfter = 0;
   for(int i = 0; i < 4; i++)
      if(g_sub[i].active)
         netAfter += newState[i];

//--- pass 2: book and log ---------------------------------------
   for(int i = 0; i < 4; i++)
     {
      if(!g_sub[i].active || !changed[i])
         continue;

      if(g_sub[i].state != 0)
        {
         double move = (g_sub[i].state > 0)
                       ? (refPrice - g_sub[i].entryPrice)
                       : (g_sub[i].entryPrice - refPrice);

         double denom    = (g_sub[i].entryATR > 0) ? g_sub[i].entryATR : atr;
         double grossATR = move / denom;

         //--- Average the entry and exit spread. On gold the session
         //    spread varies severalfold; charging the exit spread to
         //    the whole trade misprices every reversal.
         int es  = g_sub[i].entrySpreadPts;
         int avg = (es > 0) ? (int)((es + spreadPts) / 2) : spreadPts;
         double costATR  = RoundTripCostPrice(avg) / denom;

         //--- Financing scales with holding time, so omitting it does
         //    not add noise - it flatters the slow rungs specifically.
         double swapATR  = SwapCostPrice(g_sub[i].state,
                                         g_sub[i].entryTime, barTime) / denom;

         double netATR   = grossATR - costATR - swapATR;

         g_sub[i].sumGrossATR += grossATR;
         g_sub[i].sumNetATR   += netATR;
         g_sub[i].sumNetATRSq += netATR * netATR;
         if(netATR >= 0) g_sub[i].wins   += 1.0;
         else            g_sub[i].losses += 1.0;
         g_sub[i].flips++;

         if(InpLogVirtual)
            LogVirtualTrade(i, barTime, refPrice, move, grossATR, costATR, swapATR,
                            netATR, spreadPts, netAfter);
        }

      g_sub[i].state          = newState[i];
      g_sub[i].entryTime      = barTime;
      g_sub[i].entryPrice     = refPrice;
      g_sub[i].entryATR       = atr;
      g_sub[i].entryBar       = g_barCounter;
      g_sub[i].entrySpreadPts = spreadPts;
      g_sub[i].synthetic      = false;
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Reconcile actual exposure to target                              |
//|                                                                  |
//| Deadband suppresses churn from small volatility drift while       |
//| always allowing a flip through (a flip moves net exposure by      |
//| 2/activeCount of full size, comfortably above the band).          |
//| A target of exactly zero always reconciles - genuine ladder       |
//| disagreement must produce a flat book, not a residual position.   |
//+------------------------------------------------------------------+
void Reconcile()
  {
   double atr = GetATR();
   if(atr <= 0)
      return;

   double target = TargetNetLots(atr);
   double cur    = CurrentNetLots();
   double dev    = MathAbs(target - cur);

   if(dev < g_volStep * 0.5)
     {
      g_needReconcile = false;
      return;
     }

   double full = FullSizeLotsRaw(atr);
   double band = MathMax(g_volStep, full * g_band);

   bool mustFlatten = (MathAbs(target) < g_volStep * 0.5 && MathAbs(cur) >= g_volStep * 0.5);

   if(dev < band && !mustFlatten)
     {
      g_needReconcile = false;
      return;
     }

//--- Retry throttle, measured in SERVER time.
//    GetTickCount() must never be used here: it returns real wall-clock
//    milliseconds even inside the Strategy Tester, so a backtest that
//    compresses years into seconds would throttle away nearly every
//    legitimate reversal - silently, and with a plausible equity curve.
//    TimeCurrent() is simulated correctly by the tester and is server
//    time when live, so the same code is correct in both.
   int throttle = (InpRetryThrottleSec > 0) ? InpRetryThrottleSec : 0;
   if(g_lastSendTime != 0 && throttle > 0
      && (TimeCurrent() - g_lastSendTime) < throttle)
      return;

//--- Spread guard defers the TRADE, never the state. The flag stays
//    set, so exposure is corrected as soon as spread normalises.
   if(InpMaxSpreadPoints > 0)
     {
      long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(sp > InpMaxSpreadPoints)
        {
         g_deferCount++;
         return;
        }
     }

//--- Count a quantisation override exactly once, here, at the point of
//    execution - never inside the per-tick sizing helper.
   double rawTarget = full * (double)NetSignal() / (double)g_activeCount;
   if(MathAbs(rawTarget) > 0.0 && MathAbs(rawTarget) < g_minVol)
      g_quantOverrides++;

   if(cur * target > 0)
      g_rebalanceCount++;

   bool sent = GoToTarget(target);
   g_lastSendTime = TimeCurrent();

//--- CRITICAL: clear the flag on a confirmed send, NOT on a verified
//    position match. The terminal's position cache lags OrderSend on a
//    live server, so re-reading it here would report a mismatch and
//    fire a duplicate order on the next tick. Any genuine residual is
//    picked up by the next bar's reconciliation, which is safe.
   if(sent)
      g_needReconcile = false;
   else
      g_sendFailures++;
  }

//+------------------------------------------------------------------+
//| Sum of active sub-system states                                  |
//+------------------------------------------------------------------+
int NetSignal()
  {
   int net = 0;
   for(int i = 0; i < 4; i++)
      if(g_sub[i].active)
         net += g_sub[i].state;
   return(net);
  }

//+------------------------------------------------------------------+
//| Signal evaluation for one channel length                         |
//|                                                                  |
//| The channel spans bars [shift+1 .. shift+n] and EXCLUDES the bar  |
//| under test. Including it would be degenerate.                     |
//+------------------------------------------------------------------+
int EvaluateState(const double &H[], const double &L[], const double &C[],
                  const double &O[], int n, int shift, int prevState)
  {
   int hiIdx = ArrayMaximum(H, shift + 1, n);
   int loIdx = ArrayMinimum(L, shift + 1, n);
   if(hiIdx < 0 || loIdx < 0)
      return(prevState);

   double upper = H[hiIdx];
   double lower = L[loIdx];

   bool up = false, dn = false;
   if(InpBreakMode == BREAK_CLOSE)
     {
      up = (C[shift] > upper);
      dn = (C[shift] < lower);
     }
   else
     {
      up = (H[shift] > upper);
      dn = (L[shift] < lower);
     }

//--- An outside bar can trigger both in BREAK_EXTREME mode.
//    Deterministic tiebreak: follow the bar's own close direction.
   if(up && dn)
      return((C[shift] >= O[shift]) ? 1 : -1);

   if(up) return(1);
   if(dn) return(-1);
   return(prevState);
  }

//+------------------------------------------------------------------+
//| Rebuild sub-system states by replaying history                   |
//|                                                                  |
//| Restart-safe: after a reboot the EA resumes the states it would   |
//| have held had it run continuously. Entries are stamped with the   |
//| D1 ATR AS OF that bar and back-dated on the bar counter, so the   |
//| first logged trade per rung carries honest numbers.               |
//+------------------------------------------------------------------+
void RebuildStates()
  {
   int replay = g_maxN * 4 + 20;
   int need   = replay + g_maxN + 5;
   int avail  = Bars(_Symbol, InpSignalTF);

   if(avail < g_maxN + 10)
     {
      Print("RebuildStates: insufficient history, starting cold.");
      return;
     }
   if(need > avail)
      need = avail;
   replay = need - g_maxN - 2;
   if(replay < 1)
     {
      Print("RebuildStates: insufficient history, starting cold.");
      return;
     }

   double H[], L[], C[], O[];
   ArraySetAsSeries(H, true);
   ArraySetAsSeries(L, true);
   ArraySetAsSeries(C, true);
   ArraySetAsSeries(O, true);

   if(CopyHigh (_Symbol, InpSignalTF, 0, need, H) < need) return;
   if(CopyLow  (_Symbol, InpSignalTF, 0, need, L) < need) return;
   if(CopyClose(_Symbol, InpSignalTF, 0, need, C) < need) return;
   if(CopyOpen (_Symbol, InpSignalTF, 0, need, O) < need) return;

   for(int shift = replay; shift >= 1; shift--)
      for(int i = 0; i < 4; i++)
        {
         if(!g_sub[i].active)
            continue;
         int ns = EvaluateState(H, L, C, O, g_sub[i].n, shift, g_sub[i].state);
         if(ns == g_sub[i].state)
            continue;

         datetime t = iTime(_Symbol, InpSignalTF, shift);
         g_sub[i].state          = ns;
         g_sub[i].entryTime      = t;
         g_sub[i].entryPrice     = C[shift];
         g_sub[i].entryATR       = GetATRAt(t);
         g_sub[i].entryBar       = -(long)shift;   // back-dated: bars_held stays correct
         g_sub[i].entrySpreadPts = 0;
         g_sub[i].synthetic      = true;
        }

   string s = "RebuildStates ->";
   for(int i = 0; i < 4; i++)
      if(g_sub[i].active)
         s += StringFormat(" N%d=%+d", g_sub[i].n, g_sub[i].state);
   Print(s);
  }

//+------------------------------------------------------------------+
//| Round-trip transaction cost in PRICE units                       |
//|                                                                  |
//| One full spread crossing plus commission on both fills.           |
//| Commission is converted to price via the contract value so it is  |
//| directly comparable to an ATR-denominated move.                   |
//+------------------------------------------------------------------+
double RoundTripCostPrice(int spreadPts)
  {
   double spreadPrice = (double)spreadPts * _Point;
   double commPrice   = (g_valuePerPrice > 0)
                        ? (InpCommPerLotSide * 2.0) / g_valuePerPrice
                        : 0.0;
   return(spreadPrice + commPrice);
  }

//+------------------------------------------------------------------+
//| Estimated financing cost in PRICE units for one virtual trade    |
//|                                                                  |
//| Returns a positive number when financing is a COST. Only the      |
//| points-per-night swap mode is modelled; other modes return 0 and  |
//| are flagged at init, because a wrong number here is worse than a  |
//| visibly absent one. Nights are approximated as calendar days,     |
//| which ignores triple-swap Wednesday and broker holidays - the     |
//| figure is an order-of-magnitude check, not an accounting entry.   |
//+------------------------------------------------------------------+
double SwapCostPrice(int direction, datetime tEntry, datetime tExit)
  {
   if(!g_swapModelled || tExit <= tEntry)
      return(0.0);

   double rate = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);

   double nights = (double)(tExit - tEntry) / 86400.0;
   return(-(rate * nights * _Point));   // negative rate -> positive cost
  }

//+------------------------------------------------------------------+
//| Volatility-targeted full size, unrounded                         |
//|                                                                  |
//| full = (capital * volTarget%) / (ATR_D1 * valuePerPricePerLot)    |
//|                                                                  |
//| Anchored to D1 ATR, so changing the signal timeframe does not     |
//| change sizing and the EA ports across instruments untuned.        |
//+------------------------------------------------------------------+
double FullSizeLotsRaw(double atr)
  {
   if(atr <= 0 || g_valuePerPrice <= 0)
      return(0.0);

   double capital = (InpCapitalBase == CAP_EQUITY)
                    ? AccountInfoDouble(ACCOUNT_EQUITY)
                    : g_capitalBase;
   if(capital <= 0)
      return(0.0);

   return((capital * g_effVolTarget / 100.0) / (atr * g_valuePerPrice));
  }

//+------------------------------------------------------------------+
//| Net target exposure in lots (signed)                             |
//+------------------------------------------------------------------+
double TargetNetLots(double atr)
  {
   int netSignal = NetSignal();
   if(netSignal == 0)
      return(0.0);

   double raw = FullSizeLotsRaw(atr) * (double)netSignal / (double)g_activeCount;
   return(NormalizeSigned(raw));
  }

//+------------------------------------------------------------------+
//| Round a signed lot figure to broker granularity                  |
//+------------------------------------------------------------------+
double NormalizeSigned(double lots)
  {
   double a = MathAbs(lots);
   if(a <= 0)
      return(0.0);

   double r = NormalizeDouble(MathRound(a / g_volStep) * g_volStep, g_volDigits);

   if(r < g_minVol)
     {
      //--- Intended size is below the broker minimum. Trading minVol
      //    takes MORE risk than the model asked for. This function is
      //    PURE - the override is counted once at execution time in
      //    Reconcile(), not here, because this is called every tick.
      r = g_minVol;
     }
   if(r > g_maxVol)
      r = g_maxVol;

   return((lots < 0) ? -r : r);
  }

//+------------------------------------------------------------------+
//| Current net exposure from magic-filtered positions (signed)      |
//+------------------------------------------------------------------+
double CurrentNetLots()
  {
   double net = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)                                    continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double v = PositionGetDouble(POSITION_VOLUME);
      net += (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? v : -v;
     }
   return(NormalizeDouble(net, g_volDigits));
  }

//+------------------------------------------------------------------+
//| Move net exposure to target                                      |
//|                                                                  |
//| Netting: send the delta; the server aggregates.                   |
//| Hedging: reduce opposing volume first, then open the remainder.   |
//+------------------------------------------------------------------+
bool GoToTarget(double target)
  {
   double cur   = CurrentNetLots();
   double delta = NormalizeDouble(target - cur, g_volDigits);

   if(MathAbs(delta) < g_volStep * 0.5)
      return(true);          // already there - nothing to send

   if(!g_hedging)
      return(SendMarket(delta));

//--- hedging path --------------------------------------------------
   bool   reduceLongs = (delta < 0);
   double toReduce    = 0.0;

   if(cur > 0 && delta < 0) toReduce = MathMin(cur,  -delta);
   if(cur < 0 && delta > 0) toReduce = MathMin(-cur,  delta);

   if(toReduce < g_volStep * 0.5)
      return(SendMarket(delta));

   double reduced = ReduceExposure(toReduce, reduceLongs);
   bool   ok      = (reduced >= toReduce - g_volStep * 0.5);

//--- Derive the post-reduction exposure arithmetically. Re-reading
//    CurrentNetLots() here would repeat the v3 cache-lag defect: the
//    terminal reports stale (larger) exposure, the residual comes out
//    oversized, and the book ends up above target.
   double newCur   = cur + (reduceLongs ? -reduced : reduced);
   double residual = NormalizeDouble(target - newCur, g_volDigits);

   if(MathAbs(residual) >= g_volStep * 0.5)
      ok = SendMarket(residual) && ok;

   return(ok);
  }

//+------------------------------------------------------------------+
//| Reduce exposure on one side by partial/full closes               |
//+------------------------------------------------------------------+
double ReduceExposure(double volume, bool reduceLongs)
  {
   double remaining = volume;

   for(int i = PositionsTotal() - 1; i >= 0 && remaining >= g_volStep * 0.5; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)                                    continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(isLong != reduceLongs)
         continue;

      double vol  = PositionGetDouble(POSITION_VOLUME);
      double take = MathMin(vol, remaining);
      take = NormalizeDouble(MathRound(take / g_volStep) * g_volStep, g_volDigits);
      if(take < g_volStep * 0.5)
         continue;

      bool ok = (take >= vol - g_volStep * 0.5)
                ? mTrade.PositionClose(ticket, InpSlippagePoints)
                : mTrade.PositionClosePartial(ticket, take, InpSlippagePoints);

      if(ok)
        {
         remaining      -= take;
         g_turnoverLots += take;
         g_execCount++;
        }
      else
         PrintFormat("ReduceExposure failed on #%I64u ret=%d", ticket, mTrade.ResultRetcode());
     }

//--- Return what was actually closed. The caller needs this figure to
//    derive remaining exposure WITHOUT re-reading the position cache,
//    which lags the close requests on a live server.
   return(volume - remaining);
  }

//+------------------------------------------------------------------+
//| Send a signed market order                                       |
//+------------------------------------------------------------------+
bool SendMarket(double signedLots)
  {
   double vol = NormalizeDouble(MathAbs(signedLots), g_volDigits);
   if(vol < g_volStep * 0.5)
      return(true);
   if(vol > g_maxVol)
      vol = g_maxVol;

   string cm = "DSR";
   bool   ok = (signedLots > 0) ? mTrade.Buy (vol, _Symbol, 0.0, 0.0, 0.0, cm)
                                : mTrade.Sell(vol, _Symbol, 0.0, 0.0, 0.0, cm);

   if(!ok)
      PrintFormat("Order failed: %s %.2f | ret=%d %s",
                  (signedLots > 0 ? "BUY" : "SELL"), vol,
                  mTrade.ResultRetcode(), mTrade.ResultRetcodeDescription());
   else
     {
      g_execCount++;
      g_turnoverLots += vol;
     }

   return(ok);
  }

//+------------------------------------------------------------------+
//| Flatten everything under this magic                              |
//+------------------------------------------------------------------+
void FlattenAll()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)                                    continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)  continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      mTrade.PositionClose(ticket, InpSlippagePoints);
     }
  }

//+------------------------------------------------------------------+
//| Drawdown kill switch                                             |
//+------------------------------------------------------------------+
void CheckKillSwitch()
  {
   if(InpKillSwitchDD <= 0)
      return;

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity)
      g_peakEquity = eq;
   if(g_peakEquity <= 0)
      return;

   double dd = (g_peakEquity - eq) / g_peakEquity * 100.0;
   if(dd >= InpKillSwitchDD)
     {
      PrintFormat("KILL SWITCH: drawdown %.2f%% >= %.2f%%. Flattening and halting.",
                  dd, InpKillSwitchDD);
      FlattenAll();
      g_halted        = true;
      g_needReconcile = false;
     }
  }

//+------------------------------------------------------------------+
//| ATR(D1), last COMPLETED daily bar (no look-ahead)                |
//+------------------------------------------------------------------+
double GetATR()
  {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 2, buf) < 2)
      return(0.0);
   return(buf[1] > 0 ? buf[1] : buf[0]);
  }

//+------------------------------------------------------------------+
//| ATR(D1) as of a given time, using the prior completed day        |
//+------------------------------------------------------------------+
double GetATRAt(datetime t)
  {
   int d1shift = iBarShift(_Symbol, PERIOD_D1, t, false);
   if(d1shift < 0)
      return(GetATR());

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, d1shift + 1, 1, buf) < 1)
      return(GetATR());

   return(buf[0] > 0 ? buf[0] : GetATR());
  }

//+------------------------------------------------------------------+
//| New bar on the signal timeframe                                  |
//+------------------------------------------------------------------+
bool IsNewSignalBar()
  {
   datetime t = (datetime)SeriesInfoInteger(_Symbol, InpSignalTF, SERIES_LASTBAR_DATE);
   if(t == 0)
      return(false);
   if(g_lastBarTime == 0)
     {
      g_lastBarTime = t;
      return(false);
     }
   if(t != g_lastBarTime)
     {
      g_lastBarTime = t;
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Trade object configuration                                       |
//+------------------------------------------------------------------+
void ConfigureTrade()
  {
   ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_RETURN;
   long modes = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);

   if((modes & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      filling = ORDER_FILLING_FOK;
   else if((modes & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      filling = ORDER_FILLING_IOC;

   mTrade.SetExpertMagicNumber(InpMagic);
   mTrade.SetTypeFilling(filling);
   mTrade.SetDeviationInPoints(InpSlippagePoints);
   mTrade.SetAsyncMode(false);
   mTrade.LogLevel(LOG_LEVEL_ERRORS);
  }

//+------------------------------------------------------------------+
//| Startup diagnostics                                              |
//|                                                                  |
//| Two failure modes kill this strategy silently. Surface both       |
//| before a single bar is processed.                                 |
//+------------------------------------------------------------------+
void RunDiagnostics()
  {
   if(g_isOptimising)
      return;

   double atr = GetATR();
   if(atr <= 0)
     {
      Print("DIAGNOSTIC: D1 ATR not yet available - skipping checks.");
      return;
     }

//--- 1. Lot granularity. On a small account the per-rung size can
//    collapse below one volume step, turning the ensemble into an
//    on/off switch and invalidating every result.
   double full = FullSizeLotsRaw(atr);
   double rung = full / (double)g_activeCount;
   PrintFormat("DIAGNOSTIC sizing | ATR(D1,%d)=%.5f  full=%.4f lots  per-rung=%.4f  min=%.4f  step=%.4f",
               InpATRPeriodD1, atr, full, rung, g_minVol, g_volStep);
   if(rung < g_volStep * 2.0)
      PrintFormat("  *** WARNING: per-rung size %.4f is under 2x volume step %.4f. "
                  "Ensemble resolution is degraded. Raise capital base or InpVolTargetPct.",
                  rung, g_volStep);

//--- 2. Cost hurdle. This is the number that decides the strategy.
//    A Donchian reversal must capture more than this in ATR terms
//    just to break even, before any edge exists at all.
   double costPrice = RoundTripCostPrice((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   double costATR   = costPrice / atr;
   PrintFormat("DIAGNOSTIC cost | round-trip = %.5f price = %.4f ATR "
               "(spread %d pts + %.2f/lot/side commission)",
               costPrice, costATR,
               (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), InpCommPerLotSide);
   if(g_swapModelled)
      PrintFormat("DIAGNOSTIC swap | long %.2f pts/night, short %.2f pts/night. "
                  "A 60-day hold costs roughly %.4f ATR.",
                  SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG),
                  SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT),
                  MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG)) * 60.0 * _Point / atr);
   else
      Print("DIAGNOSTIC swap | *** swap mode is not points-per-night. swap_atr will be "
            "zero and net_move_atr will OVERSTATE the slow rungs. Add financing manually.");

   if(costATR > 0.10)
      PrintFormat("  *** WARNING: cost hurdle is %.3f ATR per reversal. Short channels "
                  "will not clear this. Expect only the slow rungs to survive.", costATR);
  }

//+------------------------------------------------------------------+
//| CSV logging                                                      |
//+------------------------------------------------------------------+
void OpenLogs()
  {
//--- A walk-forward optimisation is hundreds of passes across parallel
//    agents. Writing two timestamped CSVs per pass floods the disk and
//    collides on filenames, because the tag derives from simulated
//    start time. Log only on single runs, which is when files are read.
   if(g_isOptimising)
      return;

   if(InpLogVirtual)
     {
      string fn = StringFormat("DSR_virtual_%s.csv", g_runTag);
      g_fhVirtual = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(g_fhVirtual != INVALID_HANDLE)
         FileWrite(g_fhVirtual,
                   "sub_N", "direction", "entry_time", "entry_price",
                   "exit_time", "exit_price", "bars_held",
                   "atr_at_entry", "move_price",
                   "gross_move_atr", "cost_atr", "swap_atr", "net_move_atr",
                   "entry_spread_pts", "exit_spread_pts",
                   "net_signal_after", "synthetic_entry", "equity");
      else
         PrintFormat("Could not open %s (err %d)", fn, GetLastError());
     }

   if(InpLogDeals)
     {
      string fn = StringFormat("DSR_deals_%s.csv", g_runTag);
      g_fhDeals = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(g_fhDeals != INVALID_HANDLE)
         FileWrite(g_fhDeals,
                   "time", "deal_id", "entry_type", "order_type", "volume",
                   "price", "comm_reported", "comm_modelled", "swap", "profit",
                   "net_after", "equity");
      else
         PrintFormat("Could not open %s (err %d)", fn, GetLastError());
     }
  }

void CloseLogs()
  {
   if(g_fhVirtual != INVALID_HANDLE) { FileClose(g_fhVirtual); g_fhVirtual = INVALID_HANDLE; }
   if(g_fhDeals   != INVALID_HANDLE) { FileClose(g_fhDeals);   g_fhDeals   = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
//| Log a completed virtual trade                                    |
//|                                                                  |
//| THE PRIMARY RESEARCH ARTIFACT. Denominated in ATR and net of      |
//| modelled cost, so it is independent of lot quantisation, netting  |
//| and account size. This file - not the tester report - is what     |
//| answers whether the hypothesis is true.                           |
//+------------------------------------------------------------------+
void LogVirtualTrade(int idx, datetime exitTime, double exitPrice,
                     double move, double grossATR, double costATR, double swapATR,
                     double netATR, int exitSpreadPts, int netAfter)
  {
   if(g_fhVirtual == INVALID_HANDLE)
      return;

   long bars = g_barCounter - g_sub[idx].entryBar;

   FileWrite(g_fhVirtual,
             IntegerToString(g_sub[idx].n),
             (g_sub[idx].state > 0 ? "LONG" : "SHORT"),
             TimeToString(g_sub[idx].entryTime, TIME_DATE | TIME_MINUTES),
             DoubleToString(g_sub[idx].entryPrice, _Digits),
             TimeToString(exitTime, TIME_DATE | TIME_MINUTES),
             DoubleToString(exitPrice, _Digits),
             IntegerToString(bars),
             DoubleToString(g_sub[idx].entryATR, _Digits),
             DoubleToString(move, _Digits),
             DoubleToString(grossATR, 5),
             DoubleToString(costATR, 5),
             DoubleToString(swapATR, 5),
             DoubleToString(netATR, 5),
             IntegerToString(g_sub[idx].entrySpreadPts),
             IntegerToString(exitSpreadPts),
             IntegerToString(netAfter),
             (g_sub[idx].synthetic ? "1" : "0"),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
  }

//+------------------------------------------------------------------+
//| Executed deal logging - execution reality, including costs       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest    &request,
                        const MqlTradeResult     &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket))
      return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
      return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagic)
      return;

   long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
      return;

   long   entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   double vol       = HistoryDealGetDouble (dealTicket, DEAL_VOLUME);
   double price     = HistoryDealGetDouble (dealTicket, DEAL_PRICE);
   double comm      = HistoryDealGetDouble (dealTicket, DEAL_COMMISSION);
   double swap      = HistoryDealGetDouble (dealTicket, DEAL_SWAP);
   double profit    = HistoryDealGetDouble (dealTicket, DEAL_PROFIT);

   double modelled  = vol * InpCommPerLotSide;
   g_commReported  += MathAbs(comm);
   g_commModelled  += modelled;

   if(g_fhDeals == INVALID_HANDLE)
      return;

   FileWrite(g_fhDeals,
             TimeToString((datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME),
                          TIME_DATE | TIME_MINUTES | TIME_SECONDS),
             IntegerToString((long)dealTicket),
             (entryType == DEAL_ENTRY_IN  ? "IN"  :
              entryType == DEAL_ENTRY_OUT ? "OUT" : "INOUT"),
             (dealType == DEAL_TYPE_BUY ? "BUY" : "SELL"),
             DoubleToString(vol, g_volDigits),
             DoubleToString(price, _Digits),
             DoubleToString(comm, 2),
             DoubleToString(-modelled, 2),
             DoubleToString(swap, 2),
             DoubleToString(profit, 2),
             DoubleToString(CurrentNetLots(), g_volDigits),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
  }

//+------------------------------------------------------------------+
//| End-of-run summary                                               |
//+------------------------------------------------------------------+
void PrintSummary()
  {
   if(g_isOptimising)
      return;

   Print("=============== DSR ENSEMBLE v6 SUMMARY ===============");
   PrintFormat("Symbol %s | TF %s | trigger %s | rungs %d",
               _Symbol, TFToStr(InpSignalTF),
               (InpBreakMode == BREAK_CLOSE ? "close-break" : "extreme-break"),
               g_activeCount);
   Print("  Per-rung virtual results, net of modelled cost, in ATR units:");

   double totalNet = 0;
   int    totalFlips = 0;

   for(int i = 0; i < 4; i++)
     {
      if(!g_sub[i].active)
         continue;

      double nT = g_sub[i].wins + g_sub[i].losses;
      if(nT < 1)
        {
         PrintFormat("   N=%-4d  no completed virtual trades", g_sub[i].n);
         continue;
        }

      double mean  = g_sub[i].sumNetATR / nT;
      //--- sample variance (n-1), not population
      double var   = (nT > 1)
                     ? (g_sub[i].sumNetATRSq - nT * mean * mean) / (nT - 1.0)
                     : 0.0;
      double sd    = (var > 0) ? MathSqrt(var) : 0.0;
      double tStat = (sd > 0 && nT > 1) ? mean / (sd / MathSqrt(nT)) : 0.0;
      double wr    = g_sub[i].wins / nT * 100.0;
      double gmean = g_sub[i].sumGrossATR / nT;

      PrintFormat("   N=%-4d n=%-5d gross=%+.4f  net=%+.4f  sd=%.4f  t=%+.2f  win%%=%.1f",
                  g_sub[i].n, (int)nT, gmean, mean, sd, tStat, wr);

      totalNet   += g_sub[i].sumNetATR;
      totalFlips += g_sub[i].flips;
     }

   PrintFormat("  ENSEMBLE flips=%d  sum net ATR=%+.2f  per-rung=%+.2f",
               totalFlips, totalNet,
               (g_activeCount > 0 ? totalNet / g_activeCount : 0.0));
   PrintFormat("  Execution: orders=%d  turnover=%.2f lots  rebalances=%d  spread-defers=%d  send-failures=%d",
               g_execCount, g_turnoverLots, g_rebalanceCount, g_deferCount, g_sendFailures);
   PrintFormat("  Commission: reported=%.2f  modelled=%.2f",
               g_commReported, g_commModelled);
   PrintFormat("  Financing:  %s",
               (g_swapModelled ? "modelled into swap_atr"
                               : "*** NOT MODELLED - slow rungs are overstated ***"));

   if(g_commReported < g_commModelled * 0.5)
      PrintFormat("  *** The tester charged %.2f but the honest figure is %.2f. "
                  "Subtract the %.2f difference from net profit before judging this run.",
                  g_commReported, g_commModelled, g_commModelled - g_commReported);

   if(g_quantOverrides > 0)
      PrintFormat("  *** %d sizing calls were forced up to minimum lot. Realised risk "
                  "exceeded target on those flips - raise capital and re-run.", g_quantOverrides);

   Print("  NOTE: t-statistics above assume independent trades. Overlapping holds and");
   Print("  four rungs tested together both inflate them. Treat |t| < 3 as no evidence.");

   if(g_halted)
      Print("  RUN HALTED BY KILL SWITCH.");
   Print("=======================================================");
  }

//+------------------------------------------------------------------+
//| On-chart panel                                                   |
//+------------------------------------------------------------------+
void DrawPanel()
  {
   string s = "DSR ENSEMBLE v6\n";
   int netSignal = 0;
   for(int i = 0; i < 4; i++)
     {
      if(!g_sub[i].active)
         continue;
      netSignal += g_sub[i].state;
      s += StringFormat("  N=%-4d  %s   flips=%d\n",
                        g_sub[i].n,
                        (g_sub[i].state > 0 ? "LONG " :
                         g_sub[i].state < 0 ? "SHORT" : "  -  "),
                        g_sub[i].flips);
     }
   s += StringFormat("  net signal : %+d / %d\n", netSignal, g_activeCount);
   s += StringFormat("  net lots   : %+.2f\n", CurrentNetLots());
   s += StringFormat("  ATR(D1)    : %.2f\n", GetATR());
   if(g_needReconcile) s += "  reconciling...\n";
   if(g_halted)        s += "  *** HALTED ***\n";
   Comment(s);
  }

//+------------------------------------------------------------------+
//| Timeframe to string                                              |
//+------------------------------------------------------------------+
string TFToStr(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
      default:         return(EnumToString(tf));
     }
  }

//+------------------------------------------------------------------+
