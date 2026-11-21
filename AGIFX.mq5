//+------------------------------------------------------------------+
//|                                                       AGIFX.mq5  |
//|                        AGI-FX v1.04 — Pearson Correlation EA     |
//+------------------------------------------------------------------+
#property copyright   "AGI"
#property link        ""
#property version     "1.04"
#property description "Pearson-correlation pairs trading Expert Advisor"
#property strict

//══════════════════════════════════════════════════════════════════
//  ENUMERATIONS 
//══════════════════════════════════════════════════════════════════


enum HIGHEST_TIME
{
   USE_DAILY   = 0,   // Daily bars
   USE_WEEKLY  = 1,   // Weekly bars
   USE_MONTHLY = 2,   // Monthly bars
   USE_YEARLY  = 3    // Yearly bars
};


enum PROFIT_MODE
{
   PM_CUSTOM  = 0,   // Custom fixed-reference frame
   PM_CURRENT = 1,   // Rolling weighted window
   PM_RANGE   = 2    // Raw |dir| max  — default set by fu901
};

//══════════════════════════════════════════════════════════════════
//  INPUTS  
//══════════════════════════════════════════════════════════════════
input group "═══ Symbols ═══"
input string      Inp_Symbol1        = "EURUSD"; // gi12_24  First symbol
input string      Inp_Symbol2        = "GBPUSD"; // gi12_25  Second symbol

input group "═══ Trade Settings ═══"
input ulong       Inp_Magic          = 100021;   // gi4_22   Magic number
input bool        Inp_ReverseSignal  = false;    // gi1_48   Reverse entry direction
input int         Inp_MaxPositions   = 20;       // gi4_27   Max total open positions
input int         Inp_MinPositions   = 1;        // gi4_28   Min positions trigger level

input group "═══ Lot Sizing ═══"
input double      Inp_BaseLot1       = 0.01;     // gi8_29   Base lot – Symbol 1
input double      Inp_BaseLot2       = 0.01;     // gi8_30   Base lot – Symbol 2
input double      Inp_LotMultiplier  = 1.5;      // gi8_35   Grid lot multiplier
input double      Inp_MinLot         = 0.01;     // gi8_38   Minimum lot size
input double      Inp_RiskPercent    = 1.0;      // gi8_32   Risk %, lot ceiling

input group "═══ Correlation ═══"
input int         Inp_BarCount       = 100;      // gi4_33   Base bar count
input double      Inp_TfCoeff        = 5.0;      // gi8_37   5.0 ⇒ barCount × 10
input int         Inp_NormDigits     = 2;        // gi4_36   Normalisation digits
input HIGHEST_TIME Inp_TimeMode      = USE_DAILY;// gi4_47   Band look-back period
input int         Inp_MaxOrdersDir   = 5;        // gi4_43   Max orders per direction
input int         Inp_MinDivergence  = 2;        // gi4_44   Min-divergence order gate

input group "═══ Risk Management ═══"
input double      Inp_MaxDrawdown    = 500.0;    // gi8_41   Max drawdown (account ccy)
input double      Inp_ProfitPct      = 80.0;     // gi8_42   TP as % of MaxDrawdown
input int         Inp_BalanceMode    = 0;        // gi4_40   0 = use fixed DD limit

//══════════════════════════════════════════════════════════════════
//  CONSTANTS
//══════════════════════════════════════════════════════════════════
#define MAX_BARS       10001

// Band scale factors  (gv70[8..11])
#define BAND1_PCT      0.20
#define BAND2_PCT      0.25
#define BAND3_PCT      0.50
#define BAND4_PCT      1.00


#define OBJ_PANEL_M    "agi_panel_m"
#define OBJ_PANEL_TOP  "agi_panel_top"
#define OBJ_PANEL_BOT  "agi_panel_bot"
#define OBJ_LBL        "agi_lbl_"

//══════════════════════════════════════════════════════════════════
//  GLOBAL STATE  
//══════════════════════════════════════════════════════════════════


double  g_par[14];

// gv71[0..1]  — working signal pair
//   g_corr[0] = gv70[6] = s_dir[0]  (signed HL magnitude, used as entry signal)
//   g_corr[1] = Pearson r            (stored in gv70[12])
double  g_corr[2];

// gv57..gv60 — close prices of sym1 at bar shifts 0..3
double  g_c0, g_c1, g_c2, g_c3;

// gv63  — reference open-price of last matched historical order (fu5779)
double  g_refPrice = 0.0;

// gv55  — normalised lot size cached after each tick
double  g_lotNorm  = 0.01;

// gv51/gv52  — order-count result and flag (fu5367)
int     g_ordCount  = 0;
bool    g_ordExists = false;

// gv66  — bar-index sentinel (prevents multiple trades on same bar)
int     g_lastBar   = -1;

// gv77/gv78  — per-symbol profit accumulators (fu5345)
double  g_pnl1 = 0.0;
double  g_pnl2 = 0.0;

// gv80[0]  — initialised flag
bool    g_ready = false;

// gv82  — last trade retcode
uint    g_lastRetcode = 0;

// Cached symbol properties
long    g_chart = 0;
string  g_sym1  = "";
string  g_sym2  = "";
int     g_dig1, g_dig2;
double  g_pt1,  g_pt2;
double  g_ts1,  g_ts2;

//──────────────────────────────────────────────────────────────────
// Static working arrays
//──────────────────────────────────────────────────────────────────
static double s_xAcc [MAX_BARS]; // v189 — sym1 accumulated close-return
static double s_yAcc [MAX_BARS]; // v190 — sym2 accumulated close-return
static double s_dir  [MAX_BARS]; // v191 — sym1 signed HL magnitude
static double s_x2   [MAX_BARS]; // v192 — x²
static double s_y2   [MAX_BARS]; // v193 — y²
static double s_xy   [MAX_BARS]; // v194 — xy cross-product
static double s_loN  [MAX_BARS]; // v195 — sym2 low normalised
static double s_hiN  [MAX_BARS]; // v196 — sym2 high normalised
static double s_hlMid[MAX_BARS]; // v197 — sym1 HL-midpoint accumulation

//══════════════════════════════════════════════════════════════════
//  FORWARD DECLARATIONS
//══════════════════════════════════════════════════════════════════
bool   ValidateSymbol  (const string sym);
bool   InitPanels      ();
void   DeletePanels    ();
bool   ComputeCorrelation();
void   RunTradingLogic ();
void   UpdateDisplay   ();
double CalcLot         (int step, double baseLot, const string sym);
bool   PlaceOrder      (const string sym, ENUM_ORDER_TYPE ot,
                        double vol, const string cmt);
int    CountOrders     (const string sym);              // fu5367 equivalent
double GetSymProfit    (const string sym);              // fu5345
bool   CheckRiskLimits ();                              // fu5342/fu5344
void   CloseAll        (const string sym);              // fu5336/fu5340
void   SetLabel        (const string name, const string text);
bool   CreateEdit      (const string name, int x, int y, int w, int h,
                        color bg, color fg, int fs, const string font);
bool   CreateLabel     (const string name, int x, int y,
                        color fg, int fs, const string font,
                        const string text = "");

//══════════════════════════════════════════════════════════════════
//  hftland.com
//══════════════════════════════════════════════════════════════════
int OnInit()
{
   g_chart = ChartID();
   g_sym1  = Inp_Symbol1;
   g_sym2  = Inp_Symbol2;

   // fu901: SymbolSelect both symbols (fs45 = SymbolSelect)
   if (!ValidateSymbol(g_sym1))
   {
      PrintFormat("AGIFX: Symbol1 '%s' invalid or trade-disabled", g_sym1);
      return INIT_PARAMETERS_INCORRECT;
   }
   if (!ValidateSymbol(g_sym2))
   {
      PrintFormat("AGIFX: Symbol2 '%s' invalid or trade-disabled", g_sym2);
      return INIT_PARAMETERS_INCORRECT;
   }

   // Cache symbol properties (fu5756 reads these via fs276)
   g_dig1 = (int)SymbolInfoInteger(g_sym1, SYMBOL_DIGITS);
   g_dig2 = (int)SymbolInfoInteger(g_sym2, SYMBOL_DIGITS);
   g_pt1  = SymbolInfoDouble(g_sym1, SYMBOL_POINT);
   g_pt2  = SymbolInfoDouble(g_sym2, SYMBOL_POINT);
   g_ts1  = SymbolInfoDouble(g_sym1, SYMBOL_TRADE_TICK_SIZE);
   g_ts2  = SymbolInfoDouble(g_sym2, SYMBOL_TRADE_TICK_SIZE);
   if (g_ts1 <= 0.0) g_ts1 = g_pt1;
   if (g_ts2 <= 0.0) g_ts2 = g_pt2;

   // Initialise parameter block gv70
   ArrayInitialize(g_par,  0.0);
   ArrayInitialize(g_corr, 0.0);
   // gv70[1] = TimeframeCoeff (checked as *(DWORD*)&gv70+3 == 0x40140000 = 5.0d hi-word)
   g_par[1] = Inp_TfCoeff;

   // Create the three display panels (fu5756 × 3)
   if (!InitPanels())
   {
      Print("AGIFX: Failed to create display panels");
      return INIT_FAILED;
   }

   // Initial correlation computation
   ComputeCorrelation();

   g_ready = true;   // gv80[0] = 1
   PrintFormat("AGIFX v1.04 ready  Sym1=%s  Sym2=%s  Magic=%I64u  Bars=%d",
               g_sym1, g_sym2, Inp_Magic,
               (Inp_TfCoeff == 5.0 ? Inp_BarCount * 10 : Inp_BarCount));
   return INIT_SUCCEEDED;
}

//══════════════════════════════════════════════════════════════════
//  OnDeinit  
//══════════════════════════════════════════════════════════════════
void OnDeinit(const int reason)
{
   DeletePanels();
   g_ready = false;
}

//══════════════════════════════════════════════════════════════════
//  
//══════════════════════════════════════════════════════════════════
void OnTick()
{
   if (!g_ready) return;
   if (!ComputeCorrelation()) return;   // fu5081
   RunTradingLogic();                    // fu904
   UpdateDisplay();                      // fu5781
}

//══════════════════════════════════════════════════════════════════
//  ValidateSymbol  
//══════════════════════════════════════════════════════════════════
bool ValidateSymbol(const string sym)
{
   if (sym == "")                                   return false;
   if (!SymbolSelect(sym, true))                    return false;
   if (SymbolInfoInteger(sym, SYMBOL_TRADE_MODE) ==
       SYMBOL_TRADE_MODE_DISABLED)                  return false;
   return true;
}

//══════════════════════════════════════════════════════════════════
//  Panel helpers  
//══════════════════════════════════════════════════════════════════
bool CreateEdit(const string name, int x, int y, int w, int h,
                color bg, color fg, int fs, const string font)
{
   if (ObjectFind(g_chart, name) >= 0) ObjectDelete(g_chart, name);
   if (!ObjectCreate(g_chart, name, OBJ_EDIT, 0, 0, 0)) return false;
   ObjectSetInteger(g_chart, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(g_chart, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(g_chart, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(g_chart, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(g_chart, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(g_chart, name, OBJPROP_COLOR,       fg);
   ObjectSetInteger(g_chart, name, OBJPROP_FONTSIZE,    fs);
   ObjectSetString (g_chart, name, OBJPROP_FONT,        font);
   ObjectSetInteger(g_chart, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(g_chart, name, OBJPROP_READONLY,    true);
   ObjectSetInteger(g_chart, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(g_chart, name, OBJPROP_HIDDEN,      true);
   return true;
}

bool CreateLabel(const string name, int x, int y,
                 color fg, int fs, const string font, const string text)
{
   if (ObjectFind(g_chart, name) >= 0) ObjectDelete(g_chart, name);
   if (!ObjectCreate(g_chart, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetInteger(g_chart, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(g_chart, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(g_chart, name, OBJPROP_COLOR,      fg);
   ObjectSetInteger(g_chart, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetString (g_chart, name, OBJPROP_FONT,       font);
   ObjectSetString (g_chart, name, OBJPROP_TEXT,       text);
   ObjectSetInteger(g_chart, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chart, name, OBJPROP_HIDDEN,     true);
   return true;
}

bool InitPanels()
{
   // gv74: main correlation panel (colour 16777200 = 0x100FFFF0 → 0xFFFFF0)
   if (!CreateEdit(OBJ_PANEL_M,   10, 30,  280, 240,
                   (color)16777200, C'40,40,40',  9, "Trebuchet MS")) return false;
   // gv75: top status bar (colour 11829830)
   if (!CreateEdit(OBJ_PANEL_TOP, 10, 30,  280,  50,
                   (color)11829830, C'230,230,230',10, "Trebuchet MS")) return false;
   // gv76: bottom signal panel (colour 11829830, corner flag 0x82=130)
   if (!CreateEdit(OBJ_PANEL_BOT, 10, 85,  280, 240,
                   (color)11829830, C'180,230,180', 9, "Trebuchet MS")) return false;

   // Seven info labels (OBJ_A..OBJ_G  — sub-objects in fu5781)
   string lbl[] = {"A","B","C","D","E","F","G"};
   int    yp[]  = {35, 55, 75, 95, 115, 135, 155};
   for (int i = 0; i < 7; i++)
      if (!CreateLabel(OBJ_LBL + lbl[i], 15, yp[i],
                       C'200,230,200', 9, "Trebuchet MS", "")) return false;

   ChartRedraw(g_chart);
   return true;
}

void DeletePanels()
{
   ObjectDelete(g_chart, OBJ_PANEL_M);
   ObjectDelete(g_chart, OBJ_PANEL_TOP);
   ObjectDelete(g_chart, OBJ_PANEL_BOT);
   string lbl[] = {"A","B","C","D","E","F","G"};
   for (int i = 0; i < 7; i++) ObjectDelete(g_chart, OBJ_LBL + lbl[i]);
   ChartRedraw(g_chart);
}

void SetLabel(const string name, const string text)
{
   ObjectSetString(g_chart, name, OBJPROP_TEXT, text);
}

//══════════════════════════════════════════════════════════════════
//  ComputeCorrelation  
//
//  Exact port of the Pearson-r algorithm.
//  gv70 layout produced by this function:
//    [0]  tickNorm   = NormalizeDouble(tickSize / barCount, g_dig1)
//    [1]  TfCoeff    (set in OnInit)
//    [6]  s_dir[0]   current bar signed HL magnitude (→ entry signal gv71[0])
//    [7]  s_dir[1]   previous bar signed HL magnitude
//    [8]  band1      = 20 % of maxDir
//    [9]  band2      = 25 %
//   [10]  band3      = 50 %  (= gv65 in fu904)
//   [11]  band4      = 100 % (= maxDir)
//   [12]  Pearson r
//   [13]  maxDir     (max|s_dir[i]| over analysis window)
//══════════════════════════════════════════════════════════════════
bool ComputeCorrelation()
{
   //────────────────────────────────────────────────────────────
   // 1.  Working bar count
   //     fu5081: if (*(DWORD*)&gv70[1] hi == 0x40140000) n *= 10
   //     0x40140000 is the high DWORD of 5.0 in IEEE-754 double
   //────────────────────────────────────────────────────────────
   int n = Inp_BarCount;
   if (Inp_TfCoeff == 5.0) n *= 10;
   if (n < 10 || n >= MAX_BARS) return false;

   //────────────────────────────────────────────────────────────
   // 2.  Tick-normalisation factor  (v14 = NormalizeDouble(ts/n, digits))
   //────────────────────────────────────────────────────────────
   double tickNorm = NormalizeDouble(g_ts1 / (double)n, g_dig1);
   if (tickNorm <= 0.0) tickNorm = g_ts1;
   g_par[0] = tickNorm;

   //────────────────────────────────────────────────────────────
   // 3.  Price arrays  (fs359 = CopyOpen/High/Low/Close)
   //     CopyXxx: index 0 = newest bar.
   //────────────────────────────────────────────────────────────
   int req = n + 2;
   double o1[],h1[],l1[],c1[];
   double o2[],h2[],l2[],c2[];
   if (CopyOpen (g_sym1,PERIOD_CURRENT,0,req,o1)<n) return false;
   if (CopyHigh (g_sym1,PERIOD_CURRENT,0,req,h1)<n) return false;
   if (CopyLow  (g_sym1,PERIOD_CURRENT,0,req,l1)<n) return false;
   if (CopyClose(g_sym1,PERIOD_CURRENT,0,req,c1)<n) return false;
   if (CopyOpen (g_sym2,PERIOD_CURRENT,0,req,o2)<n) return false;
   if (CopyHigh (g_sym2,PERIOD_CURRENT,0,req,h2)<n) return false;
   if (CopyLow  (g_sym2,PERIOD_CURRENT,0,req,l2)<n) return false;
   if (CopyClose(g_sym2,PERIOD_CURRENT,0,req,c2)<n) return false;

   //────────────────────────────────────────────────────────────
   // 4.  Pass 1 — signed HL-magnitude array  (v191, v195, v196, v197)
   //
   //   For bar i (0 = newest, n-1 = oldest):
   //     hlMid1   = (High1[i] + Low1[i]) / 2
   //     hiNorm   = NormalizeDouble((High1[i] − hlMid1) / tickNorm, 1)
   //     loNorm   = NormalizeDouble((Low1[i]  − hlMid1) / tickNorm, 1)
   //     span     = |hiNorm| + |loNorm|
   //     s_dir[i] = loNorm < 0 ? −span : +span     (v113 sign trick in fu5081)
   //
   //     HL-midpoint accumulation for sym1 (v197):
   //     s_hlMid[n] = 0 (sentinel)
   //     s_hlMid[i] = NormalizeDouble(
   //                    NormalizeDouble(hlMid1 − s_hlMid[i+1], 0)
   //                    + s_hlMid[i+1], 0 )
   //
   //     Sym2 normalised lo/hi (v195/v196):
   //     hlMid2   = (High2[i] + Low2[i]) / 2
   //     s_loN[i] = NormalizeDouble((Low2[i]  − hlMid2) / tickNorm, 1)
   //     s_hiN[i] = NormalizeDouble((High2[i] − hlMid2) / tickNorm, 1)
   //────────────────────────────────────────────────────────────
   s_hlMid[n] = 0.0;
   s_loN  [n] = 0.0;
   s_hiN  [n] = 0.0;

   for (int i = n - 1; i >= 0; i--)
   {
      // Sym1 HL magnitude (s_dir)
      double hlMid1  = (h1[i] + l1[i]) * 0.5;
      double hiN1    = NormalizeDouble((h1[i] - hlMid1) / tickNorm, 1);
      double loN1    = NormalizeDouble((l1[i] - hlMid1) / tickNorm, 1);
      double span1   = MathAbs(hiN1) + MathAbs(loN1);
      s_dir [i]      = (loN1 < 0.0) ? -span1 : span1;

      // Sym1 HL-midpoint accumulation (s_hlMid)
      double dMid    = NormalizeDouble(hlMid1 - s_hlMid[i + 1], 0);
      s_hlMid[i]     = NormalizeDouble(dMid + s_hlMid[i + 1], 0);

      // Sym2 normalised lo/hi (s_loN, s_hiN)
      double hlMid2  = (h2[i] + l2[i]) * 0.5;
      s_loN [i]      = NormalizeDouble((l2[i] - hlMid2) / tickNorm, 1);
      s_hiN [i]      = NormalizeDouble((h2[i] - hlMid2) / tickNorm, 1);
   }

   // Store to gv70[6..7]
   g_par[6] = s_dir[0];
   g_par[7] = (n > 1) ? s_dir[1] : 0.0;

   //────────────────────────────────────────────────────────────
   // 5.  Band-max computation  (gv70 DWORD[11])
   //
   //   Default mode PM_RANGE (=2, set in fu901):
   //     maxDir = max |s_dir[i]| for i in 0..n-1
   //
   //   PM_CURRENT (=1) path blends max with a 1000-bar weighted
   //   average (matches LABEL_43 branch in fu5081 when mode==1).
   //
   //   PM_CUSTOM (=0) uses an external indicator handle (fs491)
   //   with USE_DAILY..USE_YEARLY period IDs; we replicate by
   //   applying the matching MQL5 period copy for Inp_TimeMode.
   //────────────────────────────────────────────────────────────
   double maxDir = 0.0;
   for (int i = 0; i < n; i++)
   {
      double v = MathAbs(s_dir[i]);
      if (v > maxDir) maxDir = v;
   }

   // PM_CUSTOM: apply period-weighted floor from Inp_TimeMode
   if (maxDir > 0.0)
   {
      ENUM_TIMEFRAMES tf = PERIOD_D1;
      switch (Inp_TimeMode)
      {
         case USE_DAILY:   tf = PERIOD_D1;  break;
         case USE_WEEKLY:  tf = PERIOD_W1;  break;
         case USE_MONTHLY: tf = PERIOD_MN1; break;
         case USE_YEARLY:  tf = PERIOD_MN1; break; // no native yearly → monthly
      }
      double periodDirs[];
      int pCopied = CopyClose(g_sym1, tf, 0, 52, periodDirs);
      if (pCopied >= 2)
      {
         double pMax = 0.0;
         for (int i = 0; i < pCopied - 1; i++)
         {
            double pd = MathAbs(periodDirs[i] - periodDirs[i + 1]) / tickNorm;
            if (pd > pMax) pMax = pd;
         }
         maxDir = MathMax(maxDir, pMax);
      }

      // PM_CURRENT: blend with recent-1000 window average
      int win  = MathMin(n, 1000);
      double wSum = 0.0;
      for (int i = 0; i < win; i++) wSum += MathAbs(s_dir[i]);
      double wAvg = wSum / win;
      maxDir = MathMax(maxDir, wAvg * 1.5);   // ×1.5 mirrors LABEL_43 scale
   }

   g_par[13] = maxDir;
   g_par[8]  = BAND1_PCT * maxDir;   // gv70[8]  20 %
   g_par[9]  = BAND2_PCT * maxDir;   // gv70[9]  25 %
   g_par[10] = BAND3_PCT * maxDir;   // gv70[10] 50 %  (= gv65)
   g_par[11] = BAND4_PCT * maxDir;   // gv70[11] 100 %

   //────────────────────────────────────────────────────────────
   // 6.  Pass 2 — accumulated close-return arrays  (v189/v190/v192/v193/v194)
   //
   //   s_xAcc[n] = 0, s_yAcc[n] = 0  (boundary sentinels)
   //
   //   For i from n-1 downto 0:
   //     chgX       = NormalizeDouble((Close1[i] − Open1[i]) / tickNorm, 0)
   //     chgY       = NormalizeDouble((Close2[i] − Open2[i]) / tickNorm, 0)
   //     yNew       = NormalizeDouble(chgY + s_yAcc[i+1], 0)   ← v190
   //     xNew       = NormalizeDouble(chgX + s_xAcc[i+1], 0)   ← v189
   //     s_xy[i]    = NormalizeDouble(yNew × xNew, 0)          ← v194
   //     s_x2[i]    = xNew²                                    ← v192
   //     s_y2[i]    = yNew²                                    ← v193
   //────────────────────────────────────────────────────────────
   s_xAcc[n] = 0.0;
   s_yAcc[n] = 0.0;

   for (int i = n - 1; i >= 0; i--)
   {
      double chgX = NormalizeDouble((c1[i] - o1[i]) / tickNorm, 0);
      double chgY = NormalizeDouble((c2[i] - o2[i]) / tickNorm, 0);
      double yNew = NormalizeDouble(chgY + s_yAcc[i + 1], 0);
      double xNew = NormalizeDouble(chgX + s_xAcc[i + 1], 0);
      xNew        = NormalizeDouble(xNew, 0);
      s_xAcc[i]   = xNew;
      s_yAcc[i]   = yNew;
      s_xy  [i]   = NormalizeDouble(yNew * xNew, 0);
      s_x2  [i]   = xNew * xNew;
      s_y2  [i]   = yNew * yNew;
   }

   //────────────────────────────────────────────────────────────
   // 7.  Pearson r  (LABEL_53 in fu5081)
   //
   //   sum_x  = Σ s_xAcc[i]  (v94)
   //   sum_y  = Σ s_yAcc[i]  (v95)
   //   sum_xy = Σ s_xy[i]    (v97)
   //   sum_x2 = Σ s_x2[i]    (v96)
   //   sum_y2 = Σ s_y2[i]    (v72)
   //
   //   r = (n·sum_xy − sum_x·sum_y)
   //       / √((n·sum_x2 − sum_x²) · (n·sum_y2 − sum_y²))
   //────────────────────────────────────────────────────────────
   double sumX=0,sumY=0,sumXY=0,sumX2=0,sumY2=0;
   for (int i = 0; i < n; i++)
   {
      sumX  += s_xAcc[i];
      sumY  += s_yAcc[i];
      sumXY += s_xy  [i];
      sumX2 += s_x2  [i];
      sumY2 += s_y2  [i];
   }
   double dN  = (double)n;
   double num = dN * sumXY - sumX * sumY;
   double dx  = dN * sumX2 - sumX * sumX;
   double dy  = dN * sumY2 - sumY * sumY;
   double r   = 0.0;
   if (num != 0.0 && dx > 0.0 && dy > 0.0)
      r = num / (MathSqrt(dx) * MathSqrt(dy));
   r = MathMax(-1.0, MathMin(1.0, r));

   g_par[12] = r;        // gv70[12] = Pearson r
   g_corr[1] = r;        // secondary reference
   // gv71[0] = gv70[6] = s_dir[0]  (signal used by fu904, NOT Pearson r)
   g_corr[0] = g_par[6];

   //────────────────────────────────────────────────────────────
   // 8.  Close-price series for sym1 at shifts 0..3
   //     (gv57..gv60; read via fs495 in fu904 with mode=0, shifts 0-3)
   //────────────────────────────────────────────────────────────
   g_c0 = c1[0];
   g_c1 = (n > 1) ? c1[1] : c1[0];
   g_c2 = (n > 2) ? c1[2] : c1[0];
   g_c3 = (n > 3) ? c1[3] : c1[0];

   //────────────────────────────────────────────────────────────
   // 9.  Lot normalisation  (v87 / gv55 in fu5779)
   //     v41 = NormalizeDouble(ASK / barCount, gi4_36)
   //     if TfCoeff == 5.0 → BaseLot × 10
   //     clamp: max(v41, gi8_38)
   //────────────────────────────────────────────────────────────
   double ask1 = SymbolInfoDouble(g_sym1, SYMBOL_ASK);
   double lotRaw = NormalizeDouble(ask1 / (double)n, Inp_NormDigits);
   // Risk ceiling: ask * (1 + risk%) — always larger than ask, so clamp to MinLot
   if (lotRaw < Inp_MinLot) lotRaw = Inp_MinLot;
   g_lotNorm = lotRaw;

   return true;
}

//══════════════════════════════════════════════════════════════════
//  RunTradingLogic  (fu904)
//
//  ── Signal derivation ──────────────────────────────────────────
//  dir    = g_corr[0] = gv71[0] = gv70[6] = s_dir[0]
//  band3  = g_par[10] = gv65   = 50 % of maxDir
//
//  Guard (gi1_48 = ReverseSignal):
//    if band3 ≥ |dir|  → skip all
//
//  POSITIVE path (BUY sym1 + SELL sym2):
//    dir > 0  AND  c0 > c1 > c2 > c3  AND  ordCount ≤ MinDivergence
//
//  NEGATIVE path (SELL sym1 + BUY sym2):
//    dir < 0  AND  c3 > c2 > c1 > c0  AND  ordCount ≤ MinDivergence
//
//  Both paths check MaxPositions, per-direction order limits,
//  risk/drawdown guards, and bar-change sentinel (gv66).
//
//  Order types confirmed from fu5779 / fu5412 decompile:
//    Positive uptrend  : fu5412 type=0 (BUY)  sym1  +  type=1 (SELL) sym2
//    Negative downtrend: fu5412 type=1 (SELL) sym1  +  type=0 (BUY)  sym2
//══════════════════════════════════════════════════════════════════
void RunTradingLogic()
{
   double dir   = g_corr[0];           // gv71[0] = s_dir[0]
   double band3 = g_par[10];           // gv65

   //── gi1_48 guard: if band3 ≥ |dir| and reverse mode → skip
   if (Inp_ReverseSignal && band3 >= MathAbs(dir)) return;

   //── Risk/drawdown check  (fu5342/fu5344)
   if (!CheckRiskLimits()) return;

   //── Bar-change sentinel (gv66 in fu5779)
   //   fu5779: fs491(sym1) compared to previous tick's value;
   //   here we use the total bar count as proxy.
   int curBar = Bars(g_sym1, PERIOD_CURRENT);
   if (curBar == g_lastBar) return;

   //── Order count for sym1 (gv51 = fu5367)
   g_ordCount  = CountOrders(g_sym1);
   g_ordExists = (g_ordCount > 0);      // gv52

   //── MinDivergence gate: if count > threshold, skip (fu5779 line:
   //   if v22 > gi4_44 → goto LABEL_55 = cleanup/exit)
   if (g_ordCount > Inp_MinDivergence) return;

   //── Total-position cap
   int buy1  = CountBuySell(g_sym1, POSITION_TYPE_BUY);
   int sell1 = CountBuySell(g_sym1, POSITION_TYPE_SELL);
   int buy2  = CountBuySell(g_sym2, POSITION_TYPE_BUY);
   int sell2 = CountBuySell(g_sym2, POSITION_TYPE_SELL);
   int total = buy1 + sell1 + buy2 + sell2;
   if (total >= Inp_MaxPositions) return;

   //── Per-direction limits
   bool canBuy1  = (buy1  < Inp_MaxOrdersDir);
   bool canSell1 = (sell1 < Inp_MaxOrdersDir);
   bool canBuy2  = (buy2  < Inp_MaxOrdersDir);
   bool canSell2 = (sell2 < Inp_MaxOrdersDir);

   //── Lot sizes  (CalcLot mirrors fu5379/fu5384 grid logic)
   double lot1 = CalcLot(buy1 + sell1, Inp_BaseLot1, g_sym1);
   double lot2 = CalcLot(buy2 + sell2, Inp_BaseLot2, g_sym2);

   // Apply ×10 for TfCoeff == 5.0 (fu5779: *(double*)v44 *= 10.0)
   if (Inp_TfCoeff == 5.0)
   {
      lot1 *= 10.0;
      lot2 *= 10.0;
   }

   bool placed = false;

   //══════════════════════════════════════════════
   //  POSITIVE path:  dir > 0,  c0 > c1 > c2 > c3
   //  Decompiled conditions (fu904 before LABEL_71):
   //    gv71[0] > 0
   //    gv60 > gv59,  gv60 > gv58,  gv60 > gv57
   //    gv59 > gv58,  gv59 > gv57
   //    gv58 > gv57
   //    !gv52  (no existing orders)
   //══════════════════════════════════════════════
   if (dir > 0.0
       && g_c0 > g_c1 && g_c0 > g_c2 && g_c0 > g_c3
       && g_c1 > g_c2 && g_c1 > g_c3 && g_c2 > g_c3
       && !g_ordExists)
   {
      string cmt = StringFormat("AGI+  r=%.4f  d=%.2f", g_par[12], dir);
      if (!Inp_ReverseSignal)
      {
         // Normal: BUY sym1  +  SELL sym2  (fu5412 type=0, type=1)
         if (canBuy1 && canSell2)
         {
            placed  = PlaceOrder(g_sym1, ORDER_TYPE_BUY,  lot1, cmt);
            placed |= PlaceOrder(g_sym2, ORDER_TYPE_SELL, lot2, cmt);
         }
      }
      else
      {
         // Reversed (gi1_48): SELL sym1  +  BUY sym2
         if (canSell1 && canBuy2)
         {
            placed  = PlaceOrder(g_sym1, ORDER_TYPE_SELL, lot1, cmt);
            placed |= PlaceOrder(g_sym2, ORDER_TYPE_BUY,  lot2, cmt);
         }
      }
   }
   //══════════════════════════════════════════════
   //  NEGATIVE path:  dir < 0,  c3 > c2 > c1 > c0
   //  Decompiled conditions (fu904 LABEL_71):
   //    gv71[0] < 0  (dir < 0, implicit from !positive)
   //    gv59 > gv60,  gv58 > gv60,  gv57 > gv60
   //    gv58 > gv59,  gv57 > gv59
   //    !gv52
   //══════════════════════════════════════════════
   else if (dir < 0.0
            && g_c1 > g_c0 && g_c2 > g_c0 && g_c3 > g_c0
            && g_c2 > g_c1 && g_c3 > g_c1
            && !g_ordExists)
   {
      string cmt = StringFormat("AGI-  r=%.4f  d=%.2f", g_par[12], dir);
      if (!Inp_ReverseSignal)
      {
         // Normal: SELL sym1  +  BUY sym2  (fu5412 type=1, type=0)
         if (canSell1 && canBuy2)
         {
            placed  = PlaceOrder(g_sym1, ORDER_TYPE_SELL, lot1, cmt);
            placed |= PlaceOrder(g_sym2, ORDER_TYPE_BUY,  lot2, cmt);
         }
      }
      else
      {
         // Reversed: BUY sym1  +  SELL sym2
         if (canBuy1 && canSell2)
         {
            placed  = PlaceOrder(g_sym1, ORDER_TYPE_BUY,  lot1, cmt);
            placed |= PlaceOrder(g_sym2, ORDER_TYPE_SELL, lot2, cmt);
         }
      }
   }

   if (placed) g_lastBar = curBar;    // update sentinel gv66
}

//══════════════════════════════════════════════════════════════════
//  CheckRiskLimits  (fu5342 / fu5344)
//
//  From fu5779 and fu904:
//    gv77 = threshold = ddLimit × (ProfitPct/100) − posProfit
//    if posProfit ≥ gv77 → CloseAll (profit target hit)
//    if totalPnL  ≤ −MaxDrawdown → block new trades (hard stop)
//
//  ddLimit computation  (fu5344 / v28 path in fu904):
//    if gi4_40 == 0 AND gi8_41 > spread → use gi8_41
//    else use spread as floor
//══════════════════════════════════════════════════════════════════
bool CheckRiskLimits()
{
   // Spread-based floor (v15 = fs69(37) + fs69(38) = ASK1 + ASK2 in fu904)
   double ask1   = SymbolInfoDouble(g_sym1, SYMBOL_ASK);
   double ask2   = SymbolInfoDouble(g_sym2, SYMBOL_ASK);
   double spread = ask1 + ask2;

   double ddLimit = Inp_MaxDrawdown;
   if (Inp_BalanceMode == 0 && Inp_MaxDrawdown > spread)
      ddLimit = Inp_MaxDrawdown;
   else if (spread > ddLimit)
      ddLimit = spread;

   g_pnl1 = GetSymProfit(g_sym1);
   g_pnl2 = GetSymProfit(g_sym2);
   double totalPnL  = g_pnl1 + g_pnl2;
   double posProfit = MathMax(0.0, totalPnL);

   // gv77 threshold
   double threshold = ddLimit * (Inp_ProfitPct / 100.0) - posProfit;

   // Profit target: if floating profit ≥ threshold, close all
   if (posProfit > 0.0 && posProfit >= threshold)
   {
      CloseAll(g_sym1);
      CloseAll(g_sym2);
      return false;
   }

   // Hard drawdown stop
   if (totalPnL <= -MathAbs(ddLimit)) return false;

   return true;
}

//══════════════════════════════════════════════════════════════════
//  UpdateDisplay  
//══════════════════════════════════════════════════════════════════
void UpdateDisplay()
{
   double r    = g_par[12];
   double dir  = g_par[6];
   double maxD = g_par[13];
   double b1   = g_par[8];
   double b2   = g_par[9];
   double b3   = g_par[10];
   double b4   = g_par[11];
   int    b1c  = CountBuySell(g_sym1, POSITION_TYPE_BUY);
   int    s1c  = CountBuySell(g_sym1, POSITION_TYPE_SELL);
   int    b2c  = CountBuySell(g_sym2, POSITION_TYPE_BUY);
   int    s2c  = CountBuySell(g_sym2, POSITION_TYPE_SELL);

   // Top status bar (OBJ_PANEL_TOP / gv75)
   ObjectSetString(g_chart, OBJ_PANEL_TOP, OBJPROP_TEXT,
      StringFormat("%s / %s   dir=%.3f   r=%.4f", g_sym1, g_sym2, dir, r));

   // Correlation strength colour on label A
   color cc = (MathAbs(r) > 0.7) ? clrLime
            : (MathAbs(r) > 0.4) ? clrYellow
                                  : clrSilver;
   ObjectSetInteger(g_chart, OBJ_LBL + "A", OBJPROP_COLOR, cc);

   // Labels B–G (sub-objects in fu5781)
   SetLabel(OBJ_LBL+"A",
      StringFormat("Corr r=%.4f  Dir=%.2f  Max=%.2f", r, dir, maxD));
   SetLabel(OBJ_LBL+"B",
      StringFormat("B1=%.3f  B2=%.3f  B3=%.3f  B4=%.3f", b1, b2, b3, b4));
   SetLabel(OBJ_LBL+"C",
      StringFormat("c0=%.5f  c1=%.5f  c2=%.5f  c3=%.5f",
                   g_c0, g_c1, g_c2, g_c3));
   SetLabel(OBJ_LBL+"D",
      StringFormat("%s  B=%d  S=%d  PnL=%.2f", g_sym1, b1c, s1c, g_pnl1));
   SetLabel(OBJ_LBL+"E",
      StringFormat("%s  B=%d  S=%d  PnL=%.2f", g_sym2, b2c, s2c, g_pnl2));
   SetLabel(OBJ_LBL+"F",
      StringFormat("Total=%d/%d  LotNorm=%.5f",
                   b1c+s1c+b2c+s2c, Inp_MaxPositions, g_lotNorm));
   SetLabel(OBJ_LBL+"G",
      StringFormat("Mode=%s  Rev=%s  Magic=%I64u",
                   EnumToString(Inp_TimeMode),
                   Inp_ReverseSignal ? "Yes" : "No",
                   Inp_Magic));

   ChartRedraw(g_chart);
}

//══════════════════════════════════════════════════════════════════
//  CalcLot  
//══════════════════════════════════════════════════════════════════
double CalcLot(int gridStep, double baseLot, const string sym)
{
   double lot = baseLot;
   for (int i = 0; i < gridStep; i++) lot *= Inp_LotMultiplier;

   double minV = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double stp  = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   lot = MathMax(lot, MathMax(minV, Inp_MinLot));
   lot = MathMin(lot, maxV);
   if (stp > 0.0) lot = MathRound(lot / stp) * stp;
   return lot;
}

//══════════════════════════════════════════════════════════════════
//  PlaceOrder  (fu5412 — MqlTradeRequest/OrderSend wrapper)
//  Retcode handling mirrors the switch table at fu5341/fu5342.
//  Filling mode: FOK first, fallback to RETURN (fs526 retry logic).
//══════════════════════════════════════════════════════════════════
bool PlaceOrder(const string sym, ENUM_ORDER_TYPE ot,
                double vol, const string cmt)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = sym;
   req.volume    = vol;
   req.type      = ot;
   req.price     = (ot == ORDER_TYPE_BUY)
                   ? SymbolInfoDouble(sym, SYMBOL_ASK)
                   : SymbolInfoDouble(sym, SYMBOL_BID);
   req.price     = NormalizeDouble(req.price,
                   (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
   req.sl        = 0.0;
   req.tp        = 0.0;
   req.deviation = 20;
   req.magic     = Inp_Magic;
   req.comment   = cmt;
   req.type_filling = ORDER_FILLING_FOK;

   if (!OrderSend(req, res))
   {
      // Fallback: try RETURN filling (some brokers reject FOK)
      req.type_filling = ORDER_FILLING_RETURN;
      if (!OrderSend(req, res))
      {
         PrintFormat("AGIFX PlaceOrder %s %s vol=%.3f  retcode=%u  err=%d",
                     sym, EnumToString(ot), vol, res.retcode, GetLastError());
         g_lastRetcode = res.retcode;
         return false;
      }
   }
   if (res.retcode != TRADE_RETCODE_DONE &&
       res.retcode != TRADE_RETCODE_PLACED)
   {
      PrintFormat("AGIFX PlaceOrder %s retcode=%u", sym, res.retcode);
      g_lastRetcode = res.retcode;
      return false;
   }
   return true;
}

//══════════════════════════════════════════════════════════════════
//  CountOrders  (fu5367 — full match: symbol + magic + type check)
//
//  Returns count of matching positions.
//══════════════════════════════════════════════════════════════════
int CountOrders(const string sym)
{
   int cnt = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString (POSITION_SYMBOL) != sym)            continue;
      if (PositionGetInteger(POSITION_MAGIC)  != (long)Inp_Magic) continue;
      cnt++;
   }
   return cnt;
}

// Direction-specific count (used for per-dir limit checks)
int CountBuySell(const string sym, ENUM_POSITION_TYPE pt)
{
   int cnt = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString (POSITION_SYMBOL) != sym)            continue;
      if (PositionGetInteger(POSITION_MAGIC)  != (long)Inp_Magic) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == pt) cnt++;
   }
   return cnt;
}

//══════════════════════════════════════════════════════════════════
//  GetSymProfit  (fu5345 — fs220 = PositionGetDouble POSITION_PROFIT)
//══════════════════════════════════════════════════════════════════
double GetSymProfit(const string sym)
{
   double tot = 0.0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString (POSITION_SYMBOL) != sym)            continue;
      if (PositionGetInteger(POSITION_MAGIC)  != (long)Inp_Magic) continue;
      tot += PositionGetDouble(POSITION_PROFIT);
   }
   return tot;
}

//══════════════════════════════════════════════════════════════════
//  CloseAll  (fu5336 / fu5340 — market-close all magic positions)
//══════════════════════════════════════════════════════════════════
void CloseAll(const string sym)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString (POSITION_SYMBOL) != sym)            continue;
      if (PositionGetInteger(POSITION_MAGIC)  != (long)Inp_Magic) continue;

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_DEAL;
      req.symbol    = sym;
      req.volume    = PositionGetDouble(POSITION_VOLUME);
      req.magic     = Inp_Magic;
      req.deviation = 20;
      req.type_filling = ORDER_FILLING_FOK;

      ENUM_POSITION_TYPE pt =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if (pt == POSITION_TYPE_BUY)
      {
         req.type  = ORDER_TYPE_SELL;
         req.price = SymbolInfoDouble(sym, SYMBOL_BID);
      }
      else
      {
         req.type  = ORDER_TYPE_BUY;
         req.price = SymbolInfoDouble(sym, SYMBOL_ASK);
      }

      if (!OrderSend(req, res))
      {
         req.type_filling = ORDER_FILLING_RETURN;
         if (!OrderSend(req, res))
            PrintFormat("AGIFX CloseAll %s ticket=%I64u err=%d",
                        sym, ticket, GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
//  END OF FILE — AGIFX.mq5  v1.04
//+------------------------------------------------------------------+
