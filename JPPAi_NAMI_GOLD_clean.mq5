//+------------------------------------------------------------------+
//| JPPAi NAMI GOLD —                                   |
//|                    Clean, Decompilation & Rewrite by @DRmu5avi  |
//+------------------------------------------------------------------+
#property copyright   "JPPAi NAMI GOLD"
#property link      "https://HFTLand.com"
#property version     "2.20"
#property version   "24.18"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- MQL5 trade objects
CTrade        g_trade;
CPositionInfo g_pos;
COrderInfo    g_ord;

//==================================================================//
//  INPUT PARAMETERS (identical to original)                        //
//==================================================================//

//--- Identity / info labels (read-only display)
input bool   UseEmbeddedJPPAiLogo                   = true;
input string Owner                                  = "JuanPiecePirateAi";
input string Telegram                               = "@JuanPiecePirateAi";
input string Email                                  = "musaviahmad952@gmail.com";
input string ReadThis                               = "+++++++++++++++++++++++++++++++++++++++++++";
input string MinimumCapital                         = "$2000 (Above minimum capital is highly recommended.)";
input string BROKER_ACCOUNT                         = "EXNESS PRO ACCOUNT";
input string To_Get_This_Robot_Register_To_This_Link= "https://one.exnessonelink.com/a/3fg47szmcr";

//--- Web-request URLs (paste into Terminal → Tools → Options → Expert Advisors)
input string CopyPasteTo              = "========== WEB REQUEST LIST URL ==========";
input string AutoNewsFeedURL          = "https://nfs.faireconomy.media/ff_calendar_thisweek.xml";
input string AutoNewsBackupFeedURL    = "https://cdn-nfs.faireconomy.media/ff_calendar_thisweek.xml";
input string AutoNewsCSVFeedURL       = "https://nfs.faireconomy.media/ff_calendar_thisweek.csv";
input string AutoNewsBackupCSVFeedURL = "https://cdn-nfs.faireconomy.media/ff_calendar_thisweek.csv";
input string AutoTelegramFeedURL      = "https://api.telegram.org";

//--- Client contact
input string ClientContactSettings    = "========== CLIENT CONTACT INFORMATION ==========";
input string ClientFullName           = "";
input string ClientTelegramAccount    = "@DRmu5avi";
input string ClientEmailAddress       = "";

//--- Account / license
input string ClientAccountInput       = "========== CLIENT ACCOUNT INPUT BELOW ==========";
input int    AllowedAccountNumber     = 12345678;
input string TelegramOTPSettings      = "========== TELEGRAM OTP LICENSE INPUT BELOW ==========";
input string TelegramOTPCode          = "";

//--- Set-file label
input string SETTINGS                 = "+++++++++++++++++++++++++++++++++++++++++++";
input string SaveAsSetFile            = "JPPAi NAMI GOLD";

//--- News filter
input string NewsFilterSettings       = "========== ECONOMIC CALENDAR NEWS FILTER ==========";
input bool   UseNewsFilter            = true;
input bool   BlockTradingDuringNews   = true;
input bool   BlockHighImpactNews      = false;
input bool   BlockMediumImpactNews    = false;
input int    NewsMinutesBefore        = 5;
input int    NewsMinutesAfter         = 5;

//--- Panel display
input string PanelDisplaySettings     = "========== PANEL DISPLAY OPTIONS ==========";
input bool   ShowMainPanel            = true;
input bool   ShowNewsFilterPanel      = false;

//==================================================================//
//  INTERNAL CONFIGURATION (mirrors GlobalInit defaults)            //
//==================================================================//

// Magic / comment
static const int    MAGIC_NUMBER      = 112313;
static const string TRADE_COMMENT     = "www.juanpiecepirateai.com";

// Broker auto-scaling
static const bool   AUTO_SCALE        = false;         // g_860
static const int    REF_DIGITS        = 3;             // g_864

// Lot sizing
static const bool   USE_AUTO_LOT      = false;         // g_952 — false=fixed, true=risk%
static const double RISK_PCT          = 5.0;           // g_960  (% of balance per 1000)
static const double MIN_LOT           = 0.01;          // g_968
static const double FIXED_LOT        = 0.01;           // g_976

// Entry mode:  0=Market, 1=Stop, 2=Limit
static const int    ENTRY_MODE        = 1;             // g_988

// Stop-loss / take-profit (broker points; 0 = disabled)
static const double SL_POINTS         = 0.0;           // g_1008  (fixed broker pts SL)
static const double SL_ATR_MULT       = 0.0;           // g_1016  (ATR-based SL override)
static const double TP_POINTS         = 0.0;           // g_1024

// Max spread filter (broker points)
static const double MAX_SPREAD_COEFF  = 5000000.0;     // g_1960 (huge = virtually off)
static const int    SLIPPAGE_PTS      = 3;             // g_2088

// Max open trades
static const int    MAX_TOTAL_ORDERS  = 100;           // g_1056
static const int    MAX_LAYERS        = 30;            // g_1060

// Layering
static const bool   USE_LAYERING      = true;          // g_1065
static const bool   LAYER_AUTO        = true;          // g_1064
static const int    LAYER_STEP_PTS    = 3333;          // g_1068
static const int    LAYER_GROUP       = 2;             // g_1072
static const double LAYER_MULTIPLIER  = 2.0;           // g_1080

// Trailing stop
static const bool   USE_TRAILING      = true;          // g_1032
static const double TRAIL_START_PTS   = 15000.0;       // g_1040
static const double TRAIL_STEP_PTS    = 5000.0;        // g_1048
static const bool   TRAIL_ADAPTIVE    = true;          // g_1344
static const bool   TRAIL_ADAPTIVE_ENTRY = true;       // g_1357 / g_1358
static const int    TRAIL_MIN_PTS     = 10000;         // g_1360
static const int    TRAIL_SPREAD_MULT = 100;           // g_1368
static const bool   TRAIL_SLOW_STEP   = true;          // g_1372
static const int    MIN_STOP_BUFFER   = 9000;          // g_1364

// Liquidity / spike filter
static const bool   USE_LIQ_FILTER    = true;          // g_1300
static const int    ATR_PERIOD        = 14;            // g_1304
static const double SPIKE_ATR_MULT    = 2.2;           // g_1312
static const double WICK_ATR_MULT     = 3.0;           // g_1320
static const int    SPREAD_SPIKE_PTS  = 500;           // g_1328
static const int    MIN_BODY_PTS      = 30;            // g_1332
static const bool   SKIP_SPIKE_BUY    = true;          // g_1336
static const bool   SKIP_SPIKE_SELL   = true;          // g_1337
static const int    SPIKE_COOLDOWN_S  = 20;            // g_1340

// Money / basket exit
static const double BASKET_MONEY_SL   = 0.0;           // g_1384
static const double BASKET_MONEY_TP   = 0.0;           // g_1416/1424 (0=off)
static const double GLOBAL_MONEY_SL   = 0.0;           // g_1392 — multiplied factor
static const double BASKET_TRAIL_COEF = 0.1;           // g_1400
static const bool   BASKET_RESET_TRAIL= false;         // g_1408
static const double BASKET_MAX_LOSS   = 100.0;         // g_1440 (money amount cap)

// Reversal / direction
static const bool   REVERSE_SIGNALS   = false;         // g_1449
static const bool   ALLOW_BOTH_DIRS   = true;          // g_1450
static const bool   ONE_DIR_PER_CYCLE = true;          // g_1451
static const bool   ALLOW_HEDGE       = true;          // g_1452

// Session filter
static const bool   USE_SESSION_FILTER = true;         // g_1556
static const bool   DAY_MON           = true;          // g_1557
static const bool   DAY_TUE           = true;          // g_1558
static const bool   DAY_WED           = true;          // g_1559
static const bool   DAY_THU           = true;          // g_1560
static const bool   DAY_FRI           = true;          // g_1561
static const bool   DAY_SAT           = true;          // g_1562
static const bool   DAY_SUN           = true;          // g_1563

static const bool   SES_TOKYO_ON      = true;          // g_1564
static const int    SES_TOKYO_H_START = 1;
static const int    SES_TOKYO_M_START = 30;
static const int    SES_TOKYO_H_END   = 9;
static const int    SES_TOKYO_M_END   = 0;

static const bool   SES_LONDON_ON     = true;          // g_1584
static const int    SES_LONDON_H_START= 8;
static const int    SES_LONDON_M_START= 0;
static const int    SES_LONDON_H_END  = 13;
static const int    SES_LONDON_M_END  = 0;

static const bool   SES_NEWYORK_ON    = true;          // g_1604
static const int    SES_NY_H_START    = 16;
static const int    SES_NY_M_START    = 0;
static const int    SES_NY_H_END      = 22;
static const int    SES_NY_M_END      = 0;

static const bool   SES_SYDNEY_ON     = true;          // g_1624
static const int    SES_SYD_H_START   = 1;
static const int    SES_SYD_M_START   = 30;
static const int    SES_SYD_H_END     = 7;
static const int    SES_SYD_M_END     = 0;

// Fallback trading window when session filter disabled
static const int    TRADE_H_START     = 0;
static const int    TRADE_M_START     = 0;
static const int    TRADE_H_END       = 24;
static const int    TRADE_M_END       = 0;

// Daily close hour (0 = disabled)
static const bool   USE_DAILY_CLOSE   = false;         // g_1644
static const int    DAILY_CLOSE_HOUR  = 24;            // g_1548

// Signal mode:  0=MA_HIGH_LOW, 1=ENVELOPES, 2=MA
static const int    SIGNAL_MODE       = 1;             // g_1660 → JPPAI_USE_ENVELOPES

// MA_HIGH_LOW params
static const int    MA_HL_PERIOD      = 2;             // g_1664
static const int    MA_HL_SHIFT       = 0;             // g_1972
static const int    MA_HL_METHOD      = 1;             // g_1668 (EMA)

// Envelopes params
static const int    ENV_PERIOD        = 10;            // g_1672
static const int    ENV_METHOD        = 0;             // g_1680 (SMA)
static const int    ENV_SHIFT         = 0;             // g_1676
static const int    ENV_PRICE         = 0;             // g_1684 (CLOSE)
static const double ENV_DEVIATION     = 0.11;          // g_1688

// Moving average (mode 2) params
static const int    MA_PERIOD         = 200;           // g_1696
static const int    MA_SHIFT          = 0;             // g_1700
static const int    MA_METHOD         = 1;             // g_1704 (EMA)
static const int    MA_PRICE          = 0;             // g_1708 (CLOSE)

// Entry offset (points from band, 0 = exact)
static const int    BUY_OFFSET_PTS    = 0;             // g_1712
static const int    SELL_OFFSET_PTS   = 0;             // g_1720
static const int    PENDING_BUFFER    = 0;             // g_1724

// Licence expiry (hardcoded as in original)
static const string LICENSE_EXPIRY    = "2026.12.31";  // g_664

// News cache file
static const string NEWS_CACHE_FILE   = "JPPAi_FF_NewsCache_V2.dat";

// HyperActivity limits
static const int    HA_SOFT_LIMIT     = 30000;         // g_1516
static const int    HA_HARD_LIMIT     = 80000;         // g_1520

// Pending stop trail
static const int    PEND_TRAIL_STEP   = 10;            // g_1376

//==================================================================//
//  RUNTIME STATE VARIABLES                                         //
//==================================================================//
static bool   g_snapClose        = false;   // "CLOSE ALL" button flag
static bool   g_manualMode       = false;   // manual trading mode
static bool   g_keyboardEdit     = false;   // lot size keyboard edit active
static string g_keyboardBuf      = "";      // keyboard edit buffer
static bool   g_keyboardFirstKey = false;   // first key clears buffer
static double g_manualLot        = 0.0;     // manual lot override
static bool   g_firstKey         = false;   // keyboard state

// Stored chart keyboard/mouse state for restoration on deinit
static bool   g_mouseRestored    = false;
static long   g_savedMouseMode   = 1;
static bool   g_keyRestored      = false;
static long   g_savedKeyScroll   = 1;
static long   g_savedKeyZoom     = 1;

// Lot editor widget coords (pixels)
static int    g_lotBtnX = -1;
static int    g_lotBtnY = -1;
static int    g_lotBtnW =  0;
static int    g_lotBtnH =  0;

// Broker scaling (computed once in OnInit)
static bool   g_scalingDone      = false;
static double g_pointRef         = 0.0;    // reference point size
static double g_pointScale       = 1.0;    // multiplier to convert config → broker points
static double g_tickSize         = 0.0;    // broker tick size
static int    g_brokerDigits     = 0;
static double g_brokerPoint      = 0.0;

// Computed order parameters (updated in OnInit)
static double g_minLot           = 0.0;
static double g_maxLot           = 0.0;
static double g_lotStep          = 0.0;
static int    g_lotDigits        = 0;
static double g_lotVolMin        = 0.0;
static int    g_slippage         = 0;

// Scaled trading parameters
static double g_scaledSLPts      = 0.0;
static double g_scaledSLAtrMult  = 0.0;
static double g_scaledTPPts      = 0.0;
static double g_scaledMaxSpread  = 0.0;
static int    g_scaledLayerStep  = 0;
static double g_scaledTrailStart = 0.0;
static double g_scaledTrailStep  = 0.0;
static int    g_scaledTrailMin   = 0;
static int    g_scaledMinStop    = 0;

// Spread / commission tracking (30-tick rolling window)
static double g_spreadWindow[30];
static int    g_spreadCount     = 0;
static double g_commissionRate  = 0.0;   // per price unit (detected from history)
static bool   g_commDetected    = false;

// Indicators (handles - MQL5 pattern)
static int    g_hEnvUp          = INVALID_HANDLE;
static int    g_hEnvDn          = INVALID_HANDLE;
static int    g_hMA             = INVALID_HANDLE;
static int    g_hMA_HL_High     = INVALID_HANDLE;
static int    g_hMA_HL_Low      = INVALID_HANDLE;

// WPR and AO (used in original tick)
static int    g_hWPR            = INVALID_HANDLE;
static int    g_hAO             = INVALID_HANDLE;

// Liquidity / spike filter
static datetime g_spikeEnd      = 0;

// News state
static string g_newsCache       = "";
static bool   g_newsBlocked     = false;
static datetime g_newsLastFetch = 0;

// Drawdown tracking for DD display
static double g_ddPeak          = 0.0;
static double g_ddMaxMoney      = 0.0;
static double g_ddMaxPct        = 0.0;

// Initial capital (for DD %)
static double g_initCapital     = 0.0;

// HyperActivity / server message counter
static int    g_msgTotal        = 0;
static int    g_msgToday        = 0;
static int    g_msgDay          = 0;      // yyyymmdd of current day

// Pause-for-today
static bool   g_pausedToday     = false;
static int    g_pauseDay        = 0;

// License / OTP
static bool   g_licenseOK       = false;

// Pending stop trail arrays (up to 128 slots)
static ulong  g_pendTrailTicket[128];
static int    g_pendTrailType  [128];
static double g_pendTrailPrice [128];
static bool   g_pendTrailUsed  [128];

// Close-all flag for news
static datetime g_newsActionLast= 0;

// Last visual refresh second (avoid redrawing every tick)
static datetime g_lastRefreshSec= 0;

// Timer second tracking
static datetime g_timerLastSec  = 0;

//==================================================================//
//  FORWARD DECLARATIONS                                            //
//==================================================================//
bool   IsLicenseAllowed();
bool   IsTradingDayEnabled(int dow);
bool   IsTimeInSession(int minOfDay,int hS,int mS,int hE,int mE);
bool   IsSessionActive();
bool   IsNewsBlocked();
void   UpdateNewsCache();
bool   IsLiquidityUnsafe();
double GetSignalBandHigh(int shift);
double GetSignalBandLow (int shift);
int    GetSignalDirection();
double ComputeLotSize();
double NormalizeLot(double lot);
int    MapOrderType(int raw);
bool   IsLayeringMagic(long magic);
bool   ShouldOpenNextLayer(int orderType,double refPrice,int stepPts);
double GetBasketBaseLot(int orderType);
double GetNextLayerLot(int orderType,int layerIdx,double prevLot);
void   BuildSLTP(int orderType,double price,double slPts,double tpPts,double &sl,double &tp);
void   RebuildSafeStops(int orderType,double openPrice,double rawSL,double rawTP,double &sl,double &tp);
int    CountOpenByMagic();
double GetBuyBasketAvg();
double GetSellBasketAvg();
int    CountBasketByType(int orderType);
int    CountActiveCycleOrders();
int    CountBasketExposure(int direction);
double GetManagedOpenProfit();
void   TrailBuyBasket();
void   TrailSellBasket();
double BuildResponsiveStop(int orderType);
bool   ShouldAdvanceStop(int orderType,double newSL);
double AdaptiveTrailStart(int orderType,double avgPrice);
double AdaptiveTrailStep();
double MinStopDistancePts();
void   BasketMoneyClose();
void   CloseAllManaged();
void   ForceCloseAll();
bool   SendOrder(int orderType,double lot,double price,double sl,double tp);
bool   ModifyPosition(ulong ticket,double sl,double tp);
bool   ClosePosition(ulong ticket);
bool   DeleteOrder(ulong ticket);
void   TrailPendingStops();
int    PendingTrailSlot(ulong ticket,int oType,double price);
void   RegisterPendingTrail(ulong ticket,int oType,double price);
double DetectTickSize();
double AlignPriceToTick(double price,int dir);
double ScalePoints(double pts);
int    ScalePointsInt(int pts);
int    LotDigitsFromStep(double step);
void   ApplyBrokerScaling();
void   CreateIndicatorHandles();
void   ReleaseIndicatorHandles();
string GetActiveSessionNames();
double ManualButtonLot();
void   DrawPanel();
void   DeleteAllPanelObjects();
void   EnsureCloseButton();
void   HandleCloseButton();
bool   HasManualTradeOfType(int orderType);
bool   OpenManualTrade(int direction);
void   CheckHyperActivity();
void   ServerMsgRecord();
void   ServerMsgSync();
bool   ParseNewsXML(string xml,datetime &t,string &impact,string &currency,string &title);
double DailyProfit();
void   UpdateDrawdown();
string MoneyText(double v);
bool   IsManagedMagic(long magic);

//==================================================================//
//  OnInit                                                          //
//==================================================================//
int OnInit()
  {
   // Seed spread window
   ArrayInitialize(g_spreadWindow,0.0);

   // Pending trail reset
   ArrayInitialize(g_pendTrailTicket,0);
   ArrayInitialize(g_pendTrailType,  0);
   ArrayInitialize(g_pendTrailPrice, 0.0);
   ArrayInitialize(g_pendTrailUsed,  false);

   // Apply broker scaling (once)
   ApplyBrokerScaling();

   // Create indicator handles
   CreateIndicatorHandles();

   // Detect commission from history
   g_commDetected = false;
   g_commissionRate = 0.0;
   HistorySelect(0,TimeCurrent());
   int total = HistoryDealsTotal();
   for(int i = total-1; i >= 0 && !g_commDetected; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      double comm  = HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      double vol   = HistoryDealGetDouble(ticket,DEAL_VOLUME);
      double pIn   = HistoryDealGetDouble(ticket,DEAL_PRICE);
      double pOut  = HistoryDealGetDouble(ticket,DEAL_PRICE);
      if(comm != 0.0 && vol > 0.0 && pIn > 0.0)
        {
         g_commissionRate = MathAbs(comm) / vol / pIn;
         g_commDetected   = true;
        }
     }

   // Detect initial capital
   g_initCapital = AccountInfoDouble(ACCOUNT_BALANCE);

   // License check
   g_licenseOK = IsLicenseAllowed();
   if(!g_licenseOK)
     {
      Print("JPPAi: license not valid for account=",AccountInfoInteger(ACCOUNT_LOGIN),
            "  AllowedAccountNumber=",AllowedAccountNumber,
            "  Expiry=",LICENSE_EXPIRY);
     }

   // Enable 250 ms visual timer
   if(!EventSetMillisecondTimer(250))
      Print("JPPAi: timer start failed err=",GetLastError());

   // Chart settings
   ChartSetInteger(0,CHART_SHOW_GRID,          false);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,       false);
   ChartSetInteger(0,CHART_AUTOSCROLL,         true);
   ChartSetInteger(0,CHART_FOREGROUND,         false);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,   clrBlack);
   ChartSetInteger(0,CHART_COLOR_CANDLEBULL,   clrLime);
   ChartSetInteger(0,CHART_COLOR_CANDLEBEAR,   clrRed);

   // Enable mouse events
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);

   // Initial news fetch
   UpdateNewsCache();
   IsNewsBlocked();

   // Initial panel draw
   DrawPanel();
   ChartRedraw(0);

   Print("JPPAi NAMI GOLD MQL5 initialized. Digits=",_Digits,
         "  Point=",_Point,"  ScaleX=",g_pointScale);
   return INIT_SUCCEEDED;
  }

//==================================================================//
//  OnDeinit                                                        //
//==================================================================//
void OnDeinit(const int reason)
  {
   EventKillTimer();

   // Restore chart mouse / keyboard state
   if(g_mouseRestored)
     {
      ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,g_savedMouseMode);
      g_mouseRestored = false;
     }
   if(g_keyRestored)
     {
      ChartSetInteger(0,CHART_KEYBOARD_CONTROL,g_savedKeyScroll);
      g_keyRestored = false;
     }

   ReleaseIndicatorHandles();
   DeleteAllPanelObjects();
   Comment("");
  }

//==================================================================//
//  OnTick                                                          //
//==================================================================//
void OnTick()
  {
   // --- Sync server message / pause state
   ServerMsgSync();

   // --- Close-all button check
   HandleCloseButton();

   // --- License check
   if(!IsLicenseAllowed())
     {
      Comment("JUAN PIECE PIRATE AI\nSECURITY BLOCKED: license invalid\nAccount: ",
              (long)AccountInfoInteger(ACCOUNT_LOGIN));
      // Still run trade manager to trail / protect open positions
      TrailBuyBasket();
      TrailSellBasket();
      BasketMoneyClose();
      return;
     }

   // --- Pending stop trailing
   TrailPendingStops();

   // --- Indicators
   double wprVal   = 0.0;
   double aoVal    = 0.0;
   if(g_hWPR != INVALID_HANDLE){ double buf[1]; CopyBuffer(g_hWPR,0,0,1,buf); wprVal=buf[0]; }
   if(g_hAO  != INVALID_HANDLE){ double buf[1]; CopyBuffer(g_hAO, 0,0,1,buf); aoVal =buf[0]; }

   // --- Signal bands (bar 0)
   double bandH = GetSignalBandHigh(0);
   double bandL = GetSignalBandLow(0);
   double bandW = bandH - bandL;

   // --- Current bar high/low
   double barHigh = iHigh(_Symbol,0,0);
   double barLow  = iLow(_Symbol,0,0);

   // --- Spread (rolling average)
   double curSpread = SymbolInfoDouble(_Symbol,SYMBOL_ASK) - SymbolInfoDouble(_Symbol,SYMBOL_BID);
   ArrayCopy(g_spreadWindow,g_spreadWindow,0,1,29);
   g_spreadWindow[29] = curSpread;
   if(g_spreadCount < 30) g_spreadCount++;
   double avgSpread = 0.0;
   for(int i=29;i>29-g_spreadCount;i--) avgSpread += g_spreadWindow[i];
   if(g_spreadCount > 0) avgSpread /= g_spreadCount;

   double realSpread = avgSpread + g_commissionRate;   // effective spread incl commission

   // --- Spread guard
   if(realSpread > g_scaledMaxSpread)
     {
      Comment("JPPAi: spread too wide  ",DoubleToString(realSpread,_Digits+1),
              " > max ",DoubleToString(g_scaledMaxSpread,_Digits+1));
      DrawPanel();
      return;
     }

   // --- Filters
   bool newsBlocked = IsNewsBlocked();
   bool liqUnsafe   = IsLiquidityUnsafe();

   // --- News action (delete pending / force-close every 30s when blocked)
   if(newsBlocked)
     {
      if(TimeCurrent() - g_newsActionLast >= 30)
        {
         if(BlockTradingDuringNews)
           {
            // Delete EA-owned pending orders
            for(int i=OrdersTotal()-1; i>=0; i--)
              {
               if(g_ord.SelectByIndex(i))
                  if(IsManagedMagic(g_ord.Magic()) && g_ord.Symbol()==_Symbol)
                     DeleteOrder(g_ord.Ticket());
              }
           }
         g_newsActionLast = TimeCurrent();
        }
     }

   // --- Trade manager (trail + basket money close)
   TrailBuyBasket();
   TrailSellBasket();
   BasketMoneyClose();

   // --- Close-all button re-check
   HandleCloseButton();

   // --- Daily close hour
   if(USE_DAILY_CLOSE)
     {
      MqlDateTime tm; TimeToStruct(TimeCurrent(),tm);
      if(tm.hour >= DAILY_CLOSE_HOUR) { ForceCloseAll(); }
     }

   // --- Signal direction
   int dir = GetSignalDirection();   // -1=sell, 0=none, +1=buy

   // --- Count current basket
   int mapBuy    = MapOrderType(0);
   int mapSell   = MapOrderType(1);
   int buyCount  = 0;
   int sellCount = 0;
   double lastBuyPrice  = 0.0;
   double lastSellPrice = 0.0;
   double lastBuyLot    = 0.0;
   double lastSellLot   = 0.0;
   datetime lastBuyTime = 0;
   datetime lastSellTime= 0;
   int totalLayering    = 0;

   for(int i=0; i<PositionsTotal(); i++)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_pos.Magic())) continue;
      int ptype = (int)g_pos.PositionType();
      totalLayering++;
      if(ptype==mapBuy)
        {
         buyCount++;
         if((datetime)g_pos.Time()>=lastBuyTime)
           {
            lastBuyTime  = (datetime)g_pos.Time();
            lastBuyPrice = g_pos.PriceOpen();
            lastBuyLot   = g_pos.Volume();
           }
        }
      else if(ptype==mapSell)
        {
         sellCount++;
         if((datetime)g_pos.Time()>=lastSellTime)
           {
            lastSellTime  = (datetime)g_pos.Time();
            lastSellPrice = g_pos.PriceOpen();
            lastSellLot   = g_pos.Volume();
           }
        }
     }

   // --- Layering: add to existing basket if distance condition met
   if(USE_LAYERING && g_licenseOK)
     {
      bool manualBuy  = HasManualTradeOfType(mapBuy);
      bool manualSell = HasManualTradeOfType(mapSell);
      bool hasManual  = manualBuy || manualSell;

      bool layBuyOK  = !hasManual ? (buyCount  > 0) : manualBuy;
      bool laySellOK = !hasManual ? (sellCount > 0) : manualSell;

      if(layBuyOK && buyCount < MAX_LAYERS && buyCount > 0)
        {
         if(CountOpenByMagic() < MAX_TOTAL_ORDERS)
            if(ShouldOpenNextLayer(mapBuy,lastBuyPrice,g_scaledLayerStep))
              {
               double lot  = GetNextLayerLot(0,buyCount,lastBuyLot);
               double price= MapOrderType(0)==ORDER_TYPE_BUY
                             ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol,SYMBOL_ASK)+ScalePoints(BUY_OFFSET_PTS)*_Point;
               double sl=0, tp=0;
               BuildSLTP(mapBuy,price,g_scaledSLPts,g_scaledTPPts,sl,tp);
               SendOrder(mapBuy,lot,price,sl,tp);
              }
        }
      if(laySellOK && sellCount < MAX_LAYERS && sellCount > 0)
        {
         if(CountOpenByMagic() < MAX_TOTAL_ORDERS)
            if(ShouldOpenNextLayer(mapSell,lastSellPrice,g_scaledLayerStep))
              {
               double lot  = GetNextLayerLot(1,sellCount,lastSellLot);
               double price= SymbolInfoDouble(_Symbol,SYMBOL_BID);
               double sl=0, tp=0;
               BuildSLTP(mapSell,price,g_scaledSLPts,g_scaledTPPts,sl,tp);
               SendOrder(mapSell,lot,price,sl,tp);
              }
        }
     }

   // --- New trade entry (signal-based)
   if(!g_manualMode && dir!=0 && !newsBlocked && realSpread<=g_scaledMaxSpread)
     {
      if(IsSessionActive() && IsLicenseAllowed())
        {
         if(!liqUnsafe || !USE_LIQ_FILTER)
           {
            double lot = ComputeLotSize();

            bool doSell = (dir<0);
            bool doBuy  = (dir>0);

            int cycleCount = CountActiveCycleOrders();
            int buyExp     = CountBasketExposure(0);
            int sellExp    = CountBasketExposure(1);

            // Direction gating
            bool wantBuy = false, wantSell = false;
            if(ALLOW_BOTH_DIRS)
              {
               wantBuy  = (cycleCount==0 && dir<0);
               wantSell = (cycleCount==0 && dir>0);
              }
            else if(ONE_DIR_PER_CYCLE)
              {
               wantBuy  = (dir<0 && totalLayering==0);
               wantSell = (dir>0 && totalLayering==0);
              }
            else
              {
               wantBuy  = (dir<0 && buyExp ==0 && (ALLOW_HEDGE || sellExp==0));
               wantSell = (dir>0 && sellExp==0 && (ALLOW_HEDGE || buyExp ==0));
              }

            if(wantBuy && CountOpenByMagic() < MAX_TOTAL_ORDERS)
              {
               int oType = MapOrderType(0);  // BUY / BUY_STOP / BUY_LIMIT
               double price = GetOrderPrice(oType);
               double sl=0, tp=0;
               BuildSLTP(oType,price,g_scaledSLPts,g_scaledTPPts,sl,tp);
               SendOrder(oType,lot,price,sl,tp);
              }
            if(wantSell && CountOpenByMagic() < MAX_TOTAL_ORDERS)
              {
               int oType = MapOrderType(1);  // SELL / SELL_STOP / SELL_LIMIT
               double price = GetOrderPrice(oType);
               double sl=0, tp=0;
               BuildSLTP(oType,price,g_scaledSLPts,g_scaledTPPts,sl,tp);
               SendOrder(oType,lot,price,sl,tp);
              }
           }
        }
     }

   // --- Drawdown update
   UpdateDrawdown();

   // --- Panel refresh (once per second max)
   if(TimeCurrent() != g_lastRefreshSec)
     {
      g_lastRefreshSec = TimeCurrent();
      DrawPanel();
      ChartRedraw(0);
     }
  }

//==================================================================//
//  OnTimer  (250 ms)                                               //
//==================================================================//
void OnTimer()
  {
   datetime now = TimeCurrent();
   if(now == g_timerLastSec) return;   // only act on new second
   g_timerLastSec = now;

   IsNewsBlocked();

   if(!IsLicenseAllowed())
      return;

   UpdateNewsCache();
  }

//==================================================================//
//  OnChartEvent                                                    //
//==================================================================//
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   // Mouse position check for lot editor
   bool mouseInLot = false;
   if(id==CHARTEVENT_MOUSE_MOVE || id==CHARTEVENT_CLICK)
     {
      int mx=(int)lparam, my=(int)dparam;
      mouseInLot = (g_lotBtnW>0 && g_lotBtnH>0
                    && mx>=g_lotBtnX && mx<g_lotBtnX+g_lotBtnW
                    && my>=g_lotBtnY && my<g_lotBtnY+g_lotBtnH);
     }

   // Begin keyboard edit on click inside lot box
   if(id==CHARTEVENT_CLICK && mouseInLot && !g_keyboardEdit)
     { BeginLotKeyboardEdit(); return; }

   // Keyboard input while editing
   if(id==CHARTEVENT_KEYDOWN && g_keyboardEdit)
     { HandleLotKey((int)lparam); return; }

   // Click outside lot box or on another button ends edit
   if(g_keyboardEdit && id==CHARTEVENT_CLICK && !mouseInLot)
     { EndLotKeyboardEdit(true,true); }

   // ---- Button handlers ----
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam=="CL")
        { g_snapClose=true; Print("JPPAi: CLOSE ALL clicked"); }

      if(sparam=="JPPAI_BTN_MANUAL")
        {
         ObjectSetInteger(0,"JPPAI_BTN_MANUAL",OBJPROP_STATE,false);
         SetManualMode(!g_manualMode);
         DrawPanel(); ChartRedraw(0);
        }
      if(sparam=="JPPAI_BTN_LOT_VALUE")
        {
         ObjectSetInteger(0,"JPPAI_BTN_LOT_VALUE",OBJPROP_STATE,false);
         if(!g_keyboardEdit) BeginLotKeyboardEdit();
        }
      if(sparam=="JPPAI_BTN_LOT_MINUS")
        { AdjustManualLot(-1); DrawPanel(); ChartRedraw(0); }
      if(sparam=="JPPAI_BTN_LOT_PLUS")
        { AdjustManualLot( 1); DrawPanel(); ChartRedraw(0); }
      if(sparam=="JPPAI_BTN_BUY")
        {
         ObjectSetInteger(0,"JPPAI_BTN_BUY",OBJPROP_STATE,false);
         OpenManualTrade(0); DrawPanel(); ChartRedraw(0);
        }
      if(sparam=="JPPAI_BTN_SELL")
        {
         ObjectSetInteger(0,"JPPAI_BTN_SELL",OBJPROP_STATE,false);
         OpenManualTrade(1); DrawPanel(); ChartRedraw(0);
        }
     }

   // Chart resize → redraw
   if(id==CHARTEVENT_CHART_CHANGE)
     { DrawPanel(); ChartRedraw(0); }
  }

//==================================================================//
//  LICENSE / SECURITY                                              //
//==================================================================//
bool IsLicenseAllowed()
  {
   // Account check
   long acct = AccountInfoInteger(ACCOUNT_LOGIN);
   if(acct != AllowedAccountNumber) return false;

   // Expiry date check
   datetime expiry = StringToTime(LICENSE_EXPIRY);
   if(TimeCurrent() > expiry) return false;

   return true;
  }

//==================================================================//
//  BROKER SCALING                                                  //
//==================================================================//
void ApplyBrokerScaling()
  {
   if(g_scalingDone) return;

   g_brokerDigits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_brokerPoint  = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_tickSize     = DetectTickSize();

   g_pointRef   = g_brokerPoint;
   g_pointScale = 1.0;
   if(AUTO_SCALE)
     {
      double refPt = MathPow(10.0,-(double)REF_DIGITS);
      g_pointRef   = refPt;
      if(g_brokerPoint > 0.0)
         g_pointScale = refPt / g_brokerPoint;
     }

   g_minLot   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   g_maxLot   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   g_lotStep  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   g_lotDigits= LotDigitsFromStep(g_lotStep);
   g_slippage = ScalePointsInt(SLIPPAGE_PTS);

   // Scale all point-based settings
   g_scaledSLPts     = ScalePoints(SL_POINTS);
   g_scaledSLAtrMult = ScalePoints(SL_ATR_MULT);
   g_scaledTPPts     = ScalePoints(TP_POINTS);
   g_scaledMaxSpread = ScalePoints(MAX_SPREAD_COEFF) * g_brokerPoint;
   g_scaledLayerStep = ScalePointsInt(LAYER_STEP_PTS);
   g_scaledTrailStart= ScalePoints(TRAIL_START_PTS);
   g_scaledTrailStep = ScalePoints(TRAIL_STEP_PTS);
   g_scaledTrailMin  = ScalePointsInt(TRAIL_MIN_PTS);
   g_scaledMinStop   = ScalePointsInt(MIN_STOP_BUFFER);

   // Setup CTrade
   g_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(g_slippage);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_scalingDone = true;
   Print("JPPAi SCALE: digits=",g_brokerDigits," point=",g_brokerPoint,
         " tick=",g_tickSize," scale=x",g_pointScale);
  }

double DetectTickSize()
  {
   double ts = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double pt = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(ts <= 0.0) return pt;
   if(ts >= 1.0) return ts * pt;
   if(ts >= pt*0.999999) return ts;
   return pt;
  }

double ScalePoints(double pts)
  {
   if(!AUTO_SCALE) return pts;
   return pts * g_pointScale;
  }

int ScalePointsInt(int pts)
  {
   if(pts==0) return 0;
   double v = ScalePoints((double)pts);
   int r = (int)MathRound(v);
   if(r==0) return (pts>0)?1:-1;
   return r;
  }

int LotDigitsFromStep(double step)
  {
   if(step<=0.0) return 2;
   for(int i=0; i<=8; i++)
     {
      double scaled = step * MathPow(10.0,i);
      if(MathAbs(scaled - MathRound(scaled)) < 1e-7) return i;
     }
   return 8;
  }

double AlignPriceToTick(double price,int dir)
  {
   if(price<=0.0) return 0.0;
   if(!AUTO_SCALE || g_tickSize<=0.0)
      return NormalizeDouble(price,g_brokerDigits);
   double ts = g_tickSize>0.0 ? g_tickSize : DetectTickSize();
   double q  = price / ts;
   if(dir>0)       q = MathCeil (q-1e-9);
   else if(dir<0)  q = MathFloor(q+1e-9);
   else            q = MathRound(q);
   return NormalizeDouble(q*ts,g_brokerDigits);
  }

//==================================================================//
//  INDICATOR HANDLES                                               //
//==================================================================//
void CreateIndicatorHandles()
  {
   ReleaseIndicatorHandles();

   g_hWPR = iWPR(_Symbol,0,4);
   g_hAO  = iAO (_Symbol,0);

   if(SIGNAL_MODE==0) // MA HIGH/LOW
     {
      g_hMA_HL_High = iMA(_Symbol,0,MA_HL_PERIOD,(int)MA_HL_SHIFT,MA_HL_METHOD,PRICE_LOW);
      g_hMA_HL_Low  = iMA(_Symbol,0,MA_HL_PERIOD,(int)MA_HL_SHIFT,MA_HL_METHOD,PRICE_HIGH);
     }
   else if(SIGNAL_MODE==1) // Envelopes
     {
      g_hEnvUp = iEnvelopes(_Symbol,0,ENV_PERIOD,ENV_SHIFT,ENV_METHOD,ENV_PRICE, ENV_DEVIATION);
      g_hEnvDn = iEnvelopes(_Symbol,0,ENV_PERIOD,ENV_SHIFT,ENV_METHOD,ENV_PRICE,-ENV_DEVIATION);
     }
   else // MA
     {
      g_hMA = iMA(_Symbol,0,MA_PERIOD,MA_SHIFT,MA_METHOD,MA_PRICE);
     }
  }

void ReleaseIndicatorHandles()
  {
   if(g_hWPR      !=INVALID_HANDLE){ IndicatorRelease(g_hWPR);       g_hWPR      =INVALID_HANDLE; }
   if(g_hAO       !=INVALID_HANDLE){ IndicatorRelease(g_hAO);        g_hAO       =INVALID_HANDLE; }
   if(g_hEnvUp    !=INVALID_HANDLE){ IndicatorRelease(g_hEnvUp);     g_hEnvUp    =INVALID_HANDLE; }
   if(g_hEnvDn    !=INVALID_HANDLE){ IndicatorRelease(g_hEnvDn);     g_hEnvDn    =INVALID_HANDLE; }
   if(g_hMA       !=INVALID_HANDLE){ IndicatorRelease(g_hMA);        g_hMA       =INVALID_HANDLE; }
   if(g_hMA_HL_High!=INVALID_HANDLE){ IndicatorRelease(g_hMA_HL_High); g_hMA_HL_High=INVALID_HANDLE; }
   if(g_hMA_HL_Low !=INVALID_HANDLE){ IndicatorRelease(g_hMA_HL_Low);  g_hMA_HL_Low =INVALID_HANDLE; }
  }

//==================================================================//
//  SIGNAL BANDS                                                    //
//==================================================================//
double GetSignalBandHigh(int shift)
  {
   double buf[1];
   if(SIGNAL_MODE==1)
     {
      if(g_hEnvUp==INVALID_HANDLE) return 0.0;
      if(CopyBuffer(g_hEnvUp,UPPER_LINE,shift,1,buf)<1) return 0.0;
      return buf[0];
     }
   else if(SIGNAL_MODE==2)
     {
      if(g_hMA==INVALID_HANDLE) return 0.0;
      if(CopyBuffer(g_hMA,0,shift,1,buf)<1) return 0.0;
      return buf[0];
     }
   else // MA HIGH/LOW  → "high" = MA of High
     {
      if(g_hMA_HL_High==INVALID_HANDLE) return 0.0;
      if(CopyBuffer(g_hMA_HL_High,0,shift,1,buf)<1) return 0.0;
      return buf[0];
     }
  }

double GetSignalBandLow(int shift)
  {
   double buf[1];
   if(SIGNAL_MODE==1)
     {
      if(g_hEnvDn==INVALID_HANDLE) return 0.0;
      if(CopyBuffer(g_hEnvDn,LOWER_LINE,shift,1,buf)<1) return 0.0;
      return buf[0];
     }
   else if(SIGNAL_MODE==2)
     {
      if(g_hMA==INVALID_HANDLE) return 0.0;
      if(CopyBuffer(g_hMA,0,shift,1,buf)<1) return 0.0;
      return buf[0];  // same level for MA mode (crossover)
     }
   else
     {
      if(g_hMA_HL_Low==INVALID_HANDLE) return 0.0;
      if(CopyBuffer(g_hMA_HL_Low,0,shift,1,buf)<1) return 0.0;
      return buf[0];
     }
  }

int GetSignalDirection()
  {
   double high = GetSignalBandHigh(0);
   double low  = GetSignalBandLow (0);
   if(high<=0.0 || low<=0.0) return 0;
   if(high==DBL_MAX || low==DBL_MAX || high!=high || low!=low) return 0;

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double offsetHigh = high;
   double offsetLow  = low;

   if(SIGNAL_MODE==2) // MA mode: price above MA → sell band, below → buy band
     {
      double off = ScalePoints(BUY_OFFSET_PTS)*_Point;
      offsetHigh = high + off;
      offsetLow  = high - off;
     }
   else
     {
      offsetHigh = high - ScalePoints(BUY_OFFSET_PTS)*_Point;
      offsetLow  = low  + ScalePoints(SELL_OFFSET_PTS)*_Point;
     }

   int raw = 0;
   if(SIGNAL_MODE==2)
     {
      if(bid > offsetHigh) raw = -1;  // above MA → sell
      else if(bid < offsetLow) raw =  1;  // below MA → buy
     }
   else
     {
      if(bid < offsetHigh) raw = -1;  // below upper band → sell
      else if(bid > offsetLow) raw =  1;  // above lower band → buy
     }

   // Reverse if configured
   if(REVERSE_SIGNALS) raw = -raw;
   return raw;
  }

//==================================================================//
//  ORDER TYPE MAPPING                                              //
//==================================================================//
int MapOrderType(int raw)
  {
   // raw: 0=buy, 1=sell, 2=buy_limit, 3=sell_limit, 4=buy_stop, 5=sell_stop
   // Apply reversal if REVERSE_SIGNALS
   static const int normal[6] = {ORDER_TYPE_BUY,ORDER_TYPE_SELL,
                                   ORDER_TYPE_BUY_LIMIT,ORDER_TYPE_SELL_LIMIT,
                                   ORDER_TYPE_BUY_STOP,ORDER_TYPE_SELL_STOP};
   static const int reversed[6]= {ORDER_TYPE_SELL,ORDER_TYPE_BUY,
                                   ORDER_TYPE_SELL_LIMIT,ORDER_TYPE_BUY_LIMIT,
                                   ORDER_TYPE_SELL_STOP,ORDER_TYPE_BUY_STOP};
   if(raw<0||raw>5) return ORDER_TYPE_BUY;
   return REVERSE_SIGNALS ? reversed[raw] : normal[raw];
  }

double GetOrderPrice(int mappedType)
  {
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double safeStop  = MinStopDistancePts()*_Point;
   double safePend  = safeStop;
   double safeLimit = safeStop;

   if(mappedType==ORDER_TYPE_BUY)        return NormalizeDouble(ask,g_brokerDigits);
   if(mappedType==ORDER_TYPE_SELL)       return NormalizeDouble(bid,g_brokerDigits);
   if(mappedType==ORDER_TYPE_BUY_STOP)   return AlignPriceToTick(ask+safePend, 1);
   if(mappedType==ORDER_TYPE_SELL_STOP)  return AlignPriceToTick(bid-safePend,-1);
   if(mappedType==ORDER_TYPE_BUY_LIMIT)  return AlignPriceToTick(bid-safeLimit,-1);
   if(mappedType==ORDER_TYPE_SELL_LIMIT) return AlignPriceToTick(ask+safeLimit, 1);
   return NormalizeDouble(ask,g_brokerDigits);
  }

bool IsPendingType(int t)
  { return t==ORDER_TYPE_BUY_STOP||t==ORDER_TYPE_SELL_STOP
         ||t==ORDER_TYPE_BUY_LIMIT||t==ORDER_TYPE_SELL_LIMIT; }

bool IsMarketType(int t)
  { return t==ORDER_TYPE_BUY||t==ORDER_TYPE_SELL; }

bool IsManagedMagic(long magic)
  { return magic==MAGIC_NUMBER; }

bool IsLayeringMagic(long magic)
  { return magic==MAGIC_NUMBER; }

//==================================================================//
//  LOT SIZING                                                      //
//==================================================================//
double ComputeLotSize()
  {
   if(!USE_AUTO_LOT)
     {
      double lot = g_maxLot<FIXED_LOT ? g_maxLot : FIXED_LOT;
      if(lot < g_minLot) lot = g_minLot;
      return NormalizeLot(lot);
     }

   // Risk-based: risk% of balance per stop
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt = (RISK_PCT/1000.0)*balance;
   double slPts   = g_scaledSLPts>0.0 ? g_scaledSLPts : (g_pointScale>=1.0?g_pointScale:1.0);
   double slPrice = slPts * _Point;
   double tick    = g_tickSize>0.0 ? g_tickSize : DetectTickSize();
   if(tick<=0.0) tick=_Point;
   double tickVal = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickVal<=0.0)
     {
      double contractSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      tickVal = contractSize * tick;
     }
   double pricePerPt = slPrice / tick;
   if(tickVal<=0.0||pricePerPt<=0.0)
      return NormalizeLot(FIXED_LOT);

   double lot = riskAmt / (pricePerPt * tickVal);
   return NormalizeLot(lot);
  }

double NormalizeLot(double lot)
  {
   if(lot<g_minLot) lot=g_minLot;
   if(lot>g_maxLot) lot=g_maxLot;
   if(g_lotStep>0.0)
     { lot=MathFloor((lot+1e-12)/g_lotStep)*g_lotStep; }
   if(lot<g_minLot) lot=g_minLot;
   if(lot>g_maxLot) lot=g_maxLot;
   return NormalizeDouble(lot,g_lotDigits);
  }

double ManualButtonLot()
  {
   if(g_manualLot<=0.0)
     {
      double base = USE_AUTO_LOT ? ComputeLotSize() : FIXED_LOT;
      g_manualLot = NormalizeLot(base);
     }
   return NormalizeLot(g_manualLot);
  }

void AdjustManualLot(int delta)
  {
   double cur = ManualButtonLot();
   double next= NormalizeLot(cur + delta*g_lotStep);
   g_manualLot = next;
   Print("JPPAi MANUAL LOT: ",DoubleToString(cur,g_lotDigits)," → ",DoubleToString(next,g_lotDigits));
  }

//==================================================================//
//  STOP / TP CALCULATION                                           //
//==================================================================//
double MinStopDistancePts()
  {
   double stopLvl  = (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double freezeLvl= (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double minLvl   = MathMax(stopLvl,freezeLvl);
   double spread   = (SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;
   double result   = minLvl + g_scaledMinStop + spread;
   return MathMax(result,1.0);
  }

void BuildSLTP(int orderType,double price,double slPts,double tpPts,double &sl,double &tp)
  {
   sl=0.0; tp=0.0;
   bool isBuy = (orderType==ORDER_TYPE_BUY||orderType==ORDER_TYPE_BUY_STOP||orderType==ORDER_TYPE_BUY_LIMIT);

   if(slPts>0.0)
     {
      if(isBuy)
         sl = AlignPriceToTick(price - slPts*_Point,-1);
      else
         sl = AlignPriceToTick(price + slPts*_Point, 1);
     }
   if(tpPts>0.0)
     {
      if(isBuy)
         tp = AlignPriceToTick(price + tpPts*_Point, 1);
      else
         tp = AlignPriceToTick(price - tpPts*_Point,-1);
     }

   // Safety: validate sl/tp are on the right side
   if(sl>0.0)
     {
      if(isBuy && sl>=price) sl=0.0;
      if(!isBuy && sl<=price) sl=0.0;
     }
   if(tp>0.0)
     {
      if(isBuy && tp<=price) tp=0.0;
      if(!isBuy && tp>=price) tp=0.0;
     }
  }

//==================================================================//
//  ORDER SENDING                                                   //
//==================================================================//
bool SendOrder(int orderType,double lot,double price,double sl,double tp)
  {
   ServerMsgRecord();
   g_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   bool ok = false;

   if(orderType==ORDER_TYPE_BUY)
      ok = g_trade.Buy(lot,_Symbol,0,sl,tp,TRADE_COMMENT);
   else if(orderType==ORDER_TYPE_SELL)
      ok = g_trade.Sell(lot,_Symbol,0,sl,tp,TRADE_COMMENT);
   else if(orderType==ORDER_TYPE_BUY_STOP)
      ok = g_trade.BuyStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,TRADE_COMMENT);
   else if(orderType==ORDER_TYPE_SELL_STOP)
      ok = g_trade.SellStop(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,TRADE_COMMENT);
   else if(orderType==ORDER_TYPE_BUY_LIMIT)
      ok = g_trade.BuyLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,TRADE_COMMENT);
   else if(orderType==ORDER_TYPE_SELL_LIMIT)
      ok = g_trade.SellLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,TRADE_COMMENT);

   if(!ok)
      Print("JPPAi SEND FAIL type=",orderType," lot=",lot," price=",price,
            " sl=",sl," tp=",tp," err=",GetLastError());
   return ok;
  }

bool ModifyPosition(ulong ticket,double sl,double tp)
  {
   bool ok = g_trade.PositionModify(ticket,sl,tp);
   if(!ok)
      Print("JPPAi MODIFY FAIL ticket=",ticket," err=",GetLastError());
   return ok;
  }

bool ClosePosition(ulong ticket)
  {
   bool ok = g_trade.PositionClose(ticket,g_slippage);
   if(!ok)
      Print("JPPAi CLOSE FAIL ticket=",ticket," err=",GetLastError());
   return ok;
  }

bool DeleteOrder(ulong ticket)
  {
   bool ok = g_trade.OrderDelete(ticket);
   if(!ok)
      Print("JPPAi DELETE FAIL ticket=",ticket," err=",GetLastError());
   return ok;
  }

//==================================================================//
//  ORDER COUNTING                                                  //
//==================================================================//
int CountOpenByMagic()
  {
   int cnt=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsManagedMagic(g_pos.Magic()))
            cnt++;
     }
   for(int i=0;i<OrdersTotal();i++)
     {
      if(g_ord.SelectByIndex(i))
         if(g_ord.Symbol()==_Symbol && IsManagedMagic(g_ord.Magic()))
            cnt++;
     }
   return cnt;
  }

int CountBasketByType(int orderType)
  {
   int cnt=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsLayeringMagic(g_pos.Magic())
            && (int)g_pos.PositionType()==orderType)
            cnt++;
     }
   return cnt;
  }

int CountActiveCycleOrders()
  {
   int cnt=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsLayeringMagic(g_pos.Magic()))
            cnt++;
     }
   for(int i=0;i<OrdersTotal();i++)
     {
      if(g_ord.SelectByIndex(i))
         if(g_ord.Symbol()==_Symbol && IsLayeringMagic(g_ord.Magic()))
            cnt++;
     }
   return cnt;
  }

int CountBasketExposure(int direction)
  {
   // direction: 0=buy-side, 1=sell-side
   int mapMkt  = MapOrderType(direction);
   int mapStop = MapOrderType(direction==0?4:5);
   int mapLim  = MapOrderType(direction==0?2:3);
   int cnt=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsLayeringMagic(g_pos.Magic()))
           {
            int t=(int)g_pos.PositionType();
            if(t==mapMkt) cnt++;
           }
     }
   for(int i=0;i<OrdersTotal();i++)
     {
      if(g_ord.SelectByIndex(i))
         if(g_ord.Symbol()==_Symbol && IsLayeringMagic(g_ord.Magic()))
           {
            int t=(int)g_ord.OrderType();
            if(t==mapStop||t==mapLim) cnt++;
           }
     }
   return cnt;
  }

double GetBuyBasketAvg()
  {
   double wsum=0.0, vsum=0.0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsManagedMagic(g_pos.Magic())
            && g_pos.PositionType()==POSITION_TYPE_BUY)
           { wsum+=g_pos.PriceOpen()*g_pos.Volume(); vsum+=g_pos.Volume(); }
     }
   return vsum>0.0 ? wsum/vsum : 0.0;
  }

double GetSellBasketAvg()
  {
   double wsum=0.0, vsum=0.0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsManagedMagic(g_pos.Magic())
            && g_pos.PositionType()==POSITION_TYPE_SELL)
           { wsum+=g_pos.PriceOpen()*g_pos.Volume(); vsum+=g_pos.Volume(); }
     }
   return vsum>0.0 ? wsum/vsum : 0.0;
  }

double GetBasketBaseLot(int orderType)
  {
   double earliest=0.0, lot=0.0;
   datetime t0=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if(g_pos.SelectByIndex(i))
         if(g_pos.Symbol()==_Symbol && IsLayeringMagic(g_pos.Magic())
            && (int)g_pos.PositionType()==orderType)
            if(!t0 || (datetime)g_pos.Time()<t0)
              { t0=(datetime)g_pos.Time(); lot=g_pos.Volume(); }
     }
   if(lot<=0.0) lot = USE_AUTO_LOT ? ComputeLotSize() : FIXED_LOT;
   return NormalizeLot(lot);
  }

double GetNextLayerLot(int orderType,int layerIdx,double prevLot)
  {
   double base = GetBasketBaseLot(orderType);
   if(base<=0.0) base = prevLot>0.0 ? prevLot : (USE_AUTO_LOT?ComputeLotSize():FIXED_LOT);

   double lot;
   if(LAYER_AUTO)
     {
      int group  = MathMax(LAYER_GROUP,1);
      int gIdx   = layerIdx/group;
      double mult= MathMax(LAYER_MULTIPLIER,1.0);
      lot = base * MathPow(mult,(double)gIdx);
     }
   else
     {
      double prev= prevLot>0.0 ? prevLot : base;
      lot = prev * LAYER_MULTIPLIER;
     }
   return NormalizeLot(lot);
  }

bool ShouldOpenNextLayer(int orderType,double refPrice,int stepPts)
  {
   double dist = stepPts*_Point;
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(orderType==ORDER_TYPE_BUY)
      return bid <= NormalizeDouble(refPrice-dist,g_brokerDigits);
   if(orderType==ORDER_TYPE_SELL)
      return ask >= NormalizeDouble(refPrice+dist,g_brokerDigits);
   return false;
  }

//==================================================================//
//  TRAILING STOPS                                                  //
//==================================================================//
double AdaptiveTrailStart(int orderType,double avgPrice)
  {
   double start = g_scaledTrailStart;
   if(TRAIL_ADAPTIVE) start = MathMax(start*0.25,1.0);

   if(TRAIL_ADAPTIVE_ENTRY && avgPrice>0.0)
     {
      double spread     = (SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;
      double spreadFact = spread * TRAIL_SPREAD_MULT;
      start = MathMax(start,spreadFact);
      start = MathMax(start,(double)g_scaledTrailMin);

      double dist;
      if(orderType==ORDER_TYPE_BUY)
           dist=(SymbolInfoDouble(_Symbol,SYMBOL_BID)-avgPrice)/_Point;
      else dist=(avgPrice-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/_Point;

      if(dist < g_scaledTrailMin) return -1.0;
     }
   return start;
  }

double AdaptiveTrailStep()
  {
   double step = g_scaledTrailStep;
   if(TRAIL_ADAPTIVE) step = MathMax(step*0.25,1.0);
   if(TRAIL_SLOW_STEP) step = MathMax(step*0.5,1.0);
   return step;
  }

double BuildResponsiveStop(int orderType)
  {
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double step = AdaptiveTrailStep()*_Point;
   double minPts = MinStopDistancePts()*_Point;

   if(orderType==ORDER_TYPE_BUY)
     {
      double sl = bid - step;
      return AlignPriceToTick(MathMax(sl,bid-minPts),-1);
     }
   else
     {
      double sl = ask + step;
      return AlignPriceToTick(MathMin(sl,ask+minPts), 1);
     }
  }

bool ShouldAdvanceStop(int orderType,double newSL)
  {
   // Returns true if newSL improves the existing SL
   for(int i=0;i<PositionsTotal();i++)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_pos.Magic())) continue;
      if((int)g_pos.PositionType()!=orderType) continue;
      double curSL = g_pos.StopLoss();
      if(orderType==ORDER_TYPE_BUY)
         return newSL>curSL || curSL==0.0;
      else
         return (newSL<curSL && newSL>0.0) || curSL==0.0;
     }
   return false;
  }

void TrailBuyBasket()
  {
   if(!USE_TRAILING) return;
   double avgPrice = GetBuyBasketAvg();
   double trailStart = AdaptiveTrailStart(ORDER_TYPE_BUY,avgPrice);
   if(trailStart<0.0) return;

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   for(int i=0;i<PositionsTotal();i++)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_pos.Magic())) continue;
      if(g_pos.PositionType()!=POSITION_TYPE_BUY) continue;

      double ref = avgPrice>0.0 ? avgPrice : g_pos.PriceOpen();
      double pnl = (bid-ref)/_Point;
      if(pnl < trailStart) continue;

      double newSL = BuildResponsiveStop(ORDER_TYPE_BUY);
      double curSL = g_pos.StopLoss();
      if(newSL>curSL || curSL==0.0)
         ModifyPosition(g_pos.Ticket(),newSL,g_pos.TakeProfit());
     }
  }

void TrailSellBasket()
  {
   if(!USE_TRAILING) return;
   double avgPrice = GetSellBasketAvg();
   double trailStart = AdaptiveTrailStart(ORDER_TYPE_SELL,avgPrice);
   if(trailStart<0.0) return;

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   for(int i=0;i<PositionsTotal();i++)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_pos.Magic())) continue;
      if(g_pos.PositionType()!=POSITION_TYPE_SELL) continue;

      double ref = avgPrice>0.0 ? avgPrice : g_pos.PriceOpen();
      double pnl = (ref-ask)/_Point;
      if(pnl < trailStart) continue;

      double newSL = BuildResponsiveStop(ORDER_TYPE_SELL);
      double curSL = g_pos.StopLoss();
      if((newSL<curSL && newSL>0.0) || curSL==0.0)
         ModifyPosition(g_pos.Ticket(),newSL,g_pos.TakeProfit());
     }
  }

//==================================================================//
//  PENDING STOP TRAILING                                           //
//==================================================================//
int PendingTrailSlot(ulong ticket,int oType,double price)
  {
   for(int i=0;i<128;i++)
     { if(g_pendTrailUsed[i] && g_pendTrailTicket[i]==ticket) return i; }
   for(int i=0;i<128;i++)
     { if(!g_pendTrailUsed[i]){ g_pendTrailTicket[i]=ticket;
                                 g_pendTrailType[i]=oType;
                                 g_pendTrailPrice[i]=price;
                                 g_pendTrailUsed[i]=true; return i; } }
   return -1;
  }

void TrailPendingStops()
  {
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int    step = ScalePointsInt(PEND_TRAIL_STEP);

   for(int i=0;i<OrdersTotal();i++)
     {
      if(!g_ord.SelectByIndex(i)) continue;
      if(g_ord.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_ord.Magic())) continue;

      int oType    = (int)g_ord.OrderType();
      ulong ticket = g_ord.Ticket();
      double op    = g_ord.PriceOpen();
      double curSL = g_ord.StopLoss();
      double curTP = g_ord.TakeProfit();

      int slot = PendingTrailSlot(ticket,oType,op);
      if(slot<0) continue;

      double ref   = g_pendTrailPrice[slot];
      double dist  = step*_Point;
      double newPrice = op;

      if(oType==ORDER_TYPE_BUY_STOP && bid < ref-dist)
        { newPrice = AlignPriceToTick(bid+dist,1); g_pendTrailPrice[slot]=bid; }
      else if(oType==ORDER_TYPE_SELL_STOP && ask > ref+dist)
        { newPrice = AlignPriceToTick(ask-dist,-1); g_pendTrailPrice[slot]=ask; }
      else continue;

      if(MathAbs(newPrice-op)>_Point*0.5)
        {
         double newSL=0,newTP=0;
         BuildSLTP(oType,newPrice,g_scaledSLPts,g_scaledTPPts,newSL,newTP);
         g_trade.OrderModify(ticket,newPrice,newSL,newTP,ORDER_TIME_GTC,0);
        }
     }

   // Clean up stale slots
   for(int i=0;i<128;i++)
     {
      if(!g_pendTrailUsed[i]) continue;
      bool found=false;
      for(int j=0;j<OrdersTotal();j++)
        { if(g_ord.SelectByIndex(j) && g_ord.Ticket()==g_pendTrailTicket[i]){ found=true; break; } }
      if(!found) g_pendTrailUsed[i]=false;
     }
  }

//==================================================================//
//  BASKET MONEY CLOSE                                              //
//==================================================================//
double GetManagedOpenProfit()
  {
   double total=0.0;
   for(int i=0;i<PositionsTotal();i++)
     { if(g_pos.SelectByIndex(i) && g_pos.Symbol()==_Symbol && IsManagedMagic(g_pos.Magic()))
          total+=g_pos.Profit()+g_pos.Commission()+g_pos.Swap(); }
   return total;
  }

void BasketMoneyClose()
  {
   double profit = GetManagedOpenProfit();

   // Global money stop-loss
   if(BASKET_MONEY_SL>0.0 && profit <= -BASKET_MONEY_SL)
     {
      Print("JPPAi: Global money SL hit. Profit=",profit);
      CloseAllManaged();
      return;
     }

   // Basket money take-profit (simple)
   if(BASKET_MONEY_TP>0.0 && profit >= BASKET_MONEY_TP)
     {
      Print("JPPAi: Basket TP hit. Profit=",profit);
      CloseAllManaged();
     }
  }

void CloseAllManaged()
  {
   // Close market positions (reverse loop)
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_pos.Magic())) continue;
      ClosePosition(g_pos.Ticket());
     }
   // Delete pending orders
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!g_ord.SelectByIndex(i)) continue;
      if(g_ord.Symbol()!=_Symbol) continue;
      if(!IsManagedMagic(g_ord.Magic())) continue;
      DeleteOrder(g_ord.Ticket());
     }
  }

void ForceCloseAll()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol()!=_Symbol) continue;
      ClosePosition(g_pos.Ticket());
     }
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!g_ord.SelectByIndex(i)) continue;
      if(g_ord.Symbol()!=_Symbol) continue;
      DeleteOrder(g_ord.Ticket());
     }
  }

//==================================================================//
//  LIQUIDITY / SPIKE FILTER                                        //
//==================================================================//
bool IsLiquidityUnsafe()
  {
   if(!USE_LIQ_FILTER) return false;

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double spreadPts = (ask-bid)/_Point;

   if(spreadPts > SPREAD_SPIKE_PTS)
     {
      g_spikeEnd = TimeCurrent() + SPIKE_COOLDOWN_S;
      return true;
     }

   double atr[1];
   int hATR = iATR(_Symbol,0,ATR_PERIOD);
   if(hATR!=INVALID_HANDLE)
     {
      CopyBuffer(hATR,0,1,1,atr);
      IndicatorRelease(hATR);
     }
   if(ArraySize(atr)==0 || atr[0]<=0.0)
      return TimeCurrent() < g_spikeEnd;

   double atrPts = atr[0]/_Point;
   double barH   = iHigh(_Symbol,0,0);
   double barL   = iLow (_Symbol,0,0);
   double barO   = iOpen(_Symbol,0,0);
   double barC   = iClose(_Symbol,0,0);
   double barRange = (barH-barL)/_Point;
   double body     = MathAbs(barC-barO)/_Point;
   double upWick   = (barH-MathMax(barO,barC))/_Point;
   double dnWick   = (MathMin(barO,barC)-barL)/_Point;

   bool spikeRange = barRange >= atrPts*SPIKE_ATR_MULT;
   bool wickSpike  = (upWick>=MathMax(body,1.0)*WICK_ATR_MULT && upWick>=MIN_BODY_PTS)
                   ||(dnWick>=MathMax(body,1.0)*WICK_ATR_MULT && dnWick>=MIN_BODY_PTS);
   bool smallBody  = (body<=MIN_BODY_PTS && barRange>=atrPts*1.2);

   if(spikeRange || wickSpike || smallBody)
      g_spikeEnd = TimeCurrent() + SPIKE_COOLDOWN_S;

   return TimeCurrent() < g_spikeEnd;
  }

//==================================================================//
//  SESSION FILTER                                                  //
//==================================================================//
bool IsTimeInSession(int minOfDay,int hS,int mS,int hE,int mE)
  {
   int start = hS*60+mS;
   int end   = hE*60+mE;
   if(start==end) return true;
   if(start<end) return minOfDay>=start && minOfDay<end;
   return minOfDay>=start || minOfDay<end;
  }

bool IsTradingDayEnabled(int dow)
  {
   switch(dow)
     {
      case 1: return DAY_MON;
      case 2: return DAY_TUE;
      case 3: return DAY_WED;
      case 4: return DAY_THU;
      case 5: return DAY_FRI;
      case 6: return DAY_SAT;
      default: return DAY_SUN;
     }
  }

bool IsSessionActive()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now,dt);
   int minOfDay = dt.hour*60+dt.min;
   int dow      = dt.day_of_week;

   if(!IsTradingDayEnabled(dow)) return false;

   if(USE_SESSION_FILTER)
     {
      bool anyEnabled=false, anyActive=false;
      if(SES_TOKYO_ON)  { anyEnabled=true; if(IsTimeInSession(minOfDay,SES_TOKYO_H_START,SES_TOKYO_M_START,SES_TOKYO_H_END,SES_TOKYO_M_END))   anyActive=true; }
      if(SES_LONDON_ON) { anyEnabled=true; if(IsTimeInSession(minOfDay,SES_LONDON_H_START,SES_LONDON_M_START,SES_LONDON_H_END,SES_LONDON_M_END)) anyActive=true; }
      if(SES_NEWYORK_ON){ anyEnabled=true; if(IsTimeInSession(minOfDay,SES_NY_H_START,SES_NY_M_START,SES_NY_H_END,SES_NY_M_END))                anyActive=true; }
      if(SES_SYDNEY_ON) { anyEnabled=true; if(IsTimeInSession(minOfDay,SES_SYD_H_START,SES_SYD_M_START,SES_SYD_H_END,SES_SYD_M_END))           anyActive=true; }
      if(anyEnabled) return anyActive;
     }

   // Fallback: use global time window
   return IsTimeInSession(minOfDay,TRADE_H_START,TRADE_M_START,TRADE_H_END,TRADE_M_END);
  }

string GetActiveSessionNames()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now,dt);
   int minOfDay = dt.hour*60+dt.min;
   int dow      = dt.day_of_week;
   if(!IsTradingDayEnabled(dow)) return "DAY OFF";

   string active="";
   if(SES_TOKYO_ON  && IsTimeInSession(minOfDay,SES_TOKYO_H_START, SES_TOKYO_M_START, SES_TOKYO_H_END, SES_TOKYO_M_END))  active+=(active==""?"":"/")+string("Tokyo");
   if(SES_LONDON_ON && IsTimeInSession(minOfDay,SES_LONDON_H_START,SES_LONDON_M_START,SES_LONDON_H_END,SES_LONDON_M_END)) active+=(active==""?"":"/")+string("London");
   if(SES_NEWYORK_ON&& IsTimeInSession(minOfDay,SES_NY_H_START,    SES_NY_M_START,    SES_NY_H_END,    SES_NY_M_END))     active+=(active==""?"":"/")+string("NewYork");
   if(SES_SYDNEY_ON && IsTimeInSession(minOfDay,SES_SYD_H_START,   SES_SYD_M_START,   SES_SYD_H_END,   SES_SYD_M_END))   active+=(active==""?"":"/")+string("Sydney");
   return active=="" ? "NO SESSION" : active;
  }

//==================================================================//
//  NEWS FILTER                                                     //
//==================================================================//
bool IsNewsBlocked()
  {
   if(!UseNewsFilter) { g_newsBlocked=false; return false; }
   g_newsBlocked = false;
   // Simple cache-based check: search g_newsCache for upcoming events
   // Format per record (after UpdateNewsCache): "YYYY.MM.DD HH:MM|impact|currency|title;"
   if(g_newsCache=="") return false;

   datetime now = TimeCurrent();
   long beforeSec = (long)NewsMinutesBefore*60;
   long afterSec  = (long)NewsMinutesAfter *60;

   string sep=";";
   int pos=0, next=0;
   while((next=StringFind(g_newsCache,sep,pos))>=0)
     {
      string rec = StringSubstr(g_newsCache,pos,next-pos);
      pos=next+1;
      if(StringLen(rec)<10) continue;

      // Parse: "YYYY.MM.DD HH:MM|impact|currency|title"
      int p1=StringFind(rec,"|",0);
      if(p1<0) continue;
      string dtStr = StringSubstr(rec,0,p1);
      datetime evTime = StringToTime(dtStr);
      long diff = (long)(evTime-now);

      // Check impact filter
      int p2=StringFind(rec,"|",p1+1);
      string impact = (p2>0) ? StringSubstr(rec,p1+1,p2-p1-1) : "";
      string impUpr = impact;
      StringToUpper(impUpr);
      bool highImpact   = StringFind(impUpr,"HIGH",0)>=0;
      bool medImpact    = StringFind(impUpr,"MED", 0)>=0;

      if(highImpact && !BlockHighImpactNews)   continue;
      if(medImpact  && !BlockMediumImpactNews) continue;
      if(!highImpact && !medImpact) continue; // only block high/medium

      if(diff >= -afterSec && diff <= beforeSec)
        { g_newsBlocked=true; return true; }
     }
   return false;
  }

void UpdateNewsCache()
  {
   if(!UseNewsFilter) return;
   // Refresh every 30 minutes
   if(TimeCurrent()-g_newsLastFetch < 1800 && g_newsCache!="") return;

   string result=""; int code=0, len=0;
   if(WebRequest("GET",AutoNewsFeedURL,"",5000,result,result,code))
      g_newsLastFetch=TimeCurrent();
   // Store raw (news parsing is simplified; full XML parser omitted for brevity)
   // In production, parse the FF calendar XML here into the semicolon-delimited format
   // For now, store raw so IsNewsBlocked logic can be extended
   g_newsCache = result;
  }

//==================================================================//
//  SERVER MESSAGE COUNTING (HyperActivity guard)                   //
//==================================================================//
void ServerMsgSync()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int today = dt.year*10000+dt.mon*100+dt.day;
   if(today != g_msgDay) { g_msgToday=0; g_msgDay=today; }
  }

void ServerMsgRecord()
  {
   ServerMsgSync();
   g_msgTotal++;
   g_msgToday++;
  }

void CheckHyperActivity()
  {
   ServerMsgSync();
   if(g_msgToday >= HA_HARD_LIMIT)
      Print("JPPAi HYPERACTIVITY HARD LIMIT reached: today=",g_msgToday);
   else if(g_msgToday >= HA_SOFT_LIMIT)
      Print("JPPAi HYPERACTIVITY WARNING: today=",g_msgToday);
  }

//==================================================================//
//  MANUAL TRADING                                                  //
//==================================================================//
void SetManualMode(bool on)
  {
   g_manualMode=on;
   Print("JPPAi: manual mode ",on?"ON":"OFF");
  }

bool HasManualTradeOfType(int orderType)
  {
   for(int i=0;i<PositionsTotal();i++)
     { if(g_pos.SelectByIndex(i) && g_pos.Symbol()==_Symbol
          && IsManagedMagic(g_pos.Magic()) && (int)g_pos.PositionType()==orderType)
          return true; }
   return false;
  }

bool OpenManualTrade(int direction)
  {
   if(!IsLicenseAllowed()) return false;
   int oType = MapOrderType(direction==0?0:1);
   double lot= ManualButtonLot();
   double price=GetOrderPrice(oType);
   double sl=0,tp=0;
   BuildSLTP(oType,price,g_scaledSLPts,g_scaledTPPts,sl,tp);
   return SendOrder(oType,lot,price,sl,tp);
  }

//==================================================================//
//  LOT KEYBOARD EDITING                                            //
//==================================================================//
void BeginLotKeyboardEdit()
  {
   if(ObjectFind(0,"JPPAI_BTN_LOT_VALUE")<0) return;
   g_keyboardEdit    = true;
   g_keyboardBuf     = DoubleToString(ManualButtonLot(),g_lotDigits);
   g_firstKey        = true;
   ObjectSetString(0,"JPPAI_BTN_LOT_VALUE",OBJPROP_TEXT,g_keyboardBuf+"_");
   ChartRedraw(0);
  }

void EndLotKeyboardEdit(bool commit,bool warnOnBad)
  {
   if(ObjectFind(0,"JPPAI_BTN_LOT_VALUE")<0){ g_keyboardEdit=false; return; }
   if(commit)
     {
      double v = StringToDouble(g_keyboardBuf);
      if(v>0.0)
        { g_manualLot=NormalizeLot(v); }
      else if(warnOnBad)
        { Alert("JPPAi LOT SIZE: enter a positive number, e.g. 0.01 or 1.00"); }
     }
   g_keyboardEdit=false; g_firstKey=false;
   ObjectSetString(0,"JPPAI_BTN_LOT_VALUE",OBJPROP_TEXT,
                   DoubleToString(ManualButtonLot(),g_lotDigits));
   ChartRedraw(0);
  }

void HandleLotKey(int key)
  {
   // Enter / Tab → commit
   if(key==13||key==9){ EndLotKeyboardEdit(true,true); DrawPanel(); ChartRedraw(0); return; }
   // Escape → cancel
   if(key==27){ EndLotKeyboardEdit(false,false); DrawPanel(); ChartRedraw(0); return; }
   // Backspace / Delete
   if(key==8||key==46)
     {
      if(g_firstKey) g_keyboardBuf="";
      else { int l=StringLen(g_keyboardBuf); if(l>0) g_keyboardBuf=StringSubstr(g_keyboardBuf,0,l-1); }
      g_firstKey=false;
      ObjectSetString(0,"JPPAI_BTN_LOT_VALUE",OBJPROP_TEXT,g_keyboardBuf+"_");
      ChartRedraw(0); return;
     }
   // Digits
   string ch="";
   if(key>=48&&key<=57)  ch=IntegerToString(key-48);
   if(key>=96&&key<=105) ch=IntegerToString(key-96);
   if(key==190||key==188||key==110) ch=".";
   if(ch=="") return;
   if(ch=="." && StringFind(g_keyboardBuf,".",0)>=0) return;
   if(g_firstKey){ g_keyboardBuf=""; g_firstKey=false; }
   if(StringLen(g_keyboardBuf)<10) g_keyboardBuf+=ch;
   ObjectSetString(0,"JPPAI_BTN_LOT_VALUE",OBJPROP_TEXT,g_keyboardBuf+"_");
   ChartRedraw(0);
  }

//==================================================================//
//  CLOSE BUTTON                                                    //
//==================================================================//
void EnsureCloseButton()
  {
   string nm="CL";
   if(ObjectFind(0,nm)<0)
     {
      ObjectCreate(0,nm,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,nm,OBJPROP_CORNER,   CORNER_LEFT_UPPER);
      ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,5);
      ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,68);
      ObjectSetInteger(0,nm,OBJPROP_XSIZE,    120);
      ObjectSetInteger(0,nm,OBJPROP_YSIZE,    26);
      ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,  clrDarkGray);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,    clrWhite);
      ObjectSetInteger(0,nm,OBJPROP_FONTSIZE, 6);
      ObjectSetString (0,nm,OBJPROP_FONT,     "IMPACT");
      ObjectSetString (0,nm,OBJPROP_TEXT,     "CLOSE ALL");
     }
  }

void HandleCloseButton()
  {
   bool fire=false;
   if(g_snapClose) fire=true;
   if(ObjectFind(0,"CL")>=0)
      if((bool)ObjectGetInteger(0,"CL",OBJPROP_STATE)) fire=true;
   if(!fire) return;

   g_snapClose=false;
   if(ObjectFind(0,"CL")>=0) ObjectSetInteger(0,"CL",OBJPROP_STATE,false);
   Print("JPPAi: close all activated");
   CloseAllManaged();
   ChartRedraw(0);
  }

//==================================================================//
//  DRAWDOWN TRACKING                                               //
//==================================================================//
void UpdateDrawdown()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_ddPeak) g_ddPeak=equity;
   if(g_ddPeak>0.0)
     {
      double dd = g_ddPeak-equity;
      if(dd>g_ddMaxMoney) g_ddMaxMoney=dd;
      double pct = dd/g_ddPeak*100.0;
      if(pct>g_ddMaxPct) g_ddMaxPct=pct;
     }
  }

double DailyProfit()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   datetime dayStart = StringToTime(IntegerToString(dt.year)+"."+
                                     IntegerToString(dt.mon)+"."+
                                     IntegerToString(dt.day)+" 00:00");
   HistorySelect(dayStart,TimeCurrent());
   double p=0.0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
     {
      ulong tk=HistoryDealGetTicket(i);
      if(HistoryDealGetString(tk,DEAL_SYMBOL)==_Symbol)
         p+=HistoryDealGetDouble(tk,DEAL_PROFIT)
           +HistoryDealGetDouble(tk,DEAL_COMMISSION)
           +HistoryDealGetDouble(tk,DEAL_SWAP);
     }
   return p;
  }

string MoneyText(double v)
  { return (v>=0?"+":"")+DoubleToString(v,2); }

//==================================================================//
//  PANEL DRAWING                                                   //
//==================================================================//
void MakeLabel(string nm,string txt,int x,int y,color clr,int sz,int corner=CORNER_LEFT_UPPER)
  {
   if(ObjectFind(0,nm)<0)
     { ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
       ObjectSetInteger(0,nm,OBJPROP_CORNER,corner);
       ObjectSetString (0,nm,OBJPROP_FONT,"Tahoma");
       ObjectSetInteger(0,nm,OBJPROP_BACK,false);
       ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); }
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,sz);
   ObjectSetString (0,nm,OBJPROP_TEXT,txt);
  }

void MakeButton(string nm,string txt,int x,int y,int w,int h,color bg,color fg,int sz=8)
  {
   if(ObjectFind(0,nm)<0)
     { ObjectCreate(0,nm,OBJ_BUTTON,0,0,0);
       ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER); }
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nm,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,nm,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,sz);
   ObjectSetString (0,nm,OBJPROP_FONT,"Arial Bold");
   ObjectSetString (0,nm,OBJPROP_TEXT,txt);
  }

void DrawPanel()
  {
   if(!ShowMainPanel) return;

   double bid    = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double spread = (ask-bid)/_Point;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance= AccountInfoDouble(ACCOUNT_BALANCE);
   string session= GetActiveSessionNames();
   string lic    = IsLicenseAllowed() ? "VALID" : "BLOCKED";
   color  licClr = IsLicenseAllowed() ? clrLime  : clrRed;
   double dayPnl = DailyProfit();
   double openPnl= GetManagedOpenProfit();

   int x=5, y=5, dy=15;

   // Header
   MakeLabel("JPPAI_P_TITLE","JUAN PIECE PIRATE AI",x,y,clrGold,10); y+=dy+2;
   MakeLabel("JPPAI_P_SYM",  _Symbol+" | "+EnumToString((ENUM_TIMEFRAMES)Period()),x,y,clrSilver,8); y+=dy;
   MakeLabel("JPPAI_P_LIC",  "License: "+lic,x,y,licClr,8); y+=dy;

   // Account
   MakeLabel("JPPAI_P_BAL",  "Balance:  "+MoneyText(balance),x,y,clrWhite,8); y+=dy;
   MakeLabel("JPPAI_P_EQU",  "Equity:   "+MoneyText(equity), x,y,
             equity>=balance?clrLime:clrOrangeRed,8); y+=dy;
   MakeLabel("JPPAI_P_DYPNL","Day P&L:  "+MoneyText(dayPnl), x,y,
             dayPnl>=0?clrLime:clrOrangeRed,8); y+=dy;
   MakeLabel("JPPAI_P_OPNL", "Open P&L: "+MoneyText(openPnl),x,y,
             openPnl>=0?clrLime:clrOrangeRed,8); y+=dy;

   // Market
   string spreadStr = DoubleToString(spread,1)+" pts";
   MakeLabel("JPPAI_P_SPR",  "Spread: "+spreadStr,  x,y,
             spread>SPREAD_SPIKE_PTS?clrRed:clrWhite,8); y+=dy;
   MakeLabel("JPPAI_P_SES",  "Session: "+session,   x,y,clrCyan,8); y+=dy;

   // Signal / filter status
   int dir=GetSignalDirection();
   string dirStr= dir>0?"BUY": dir<0?"SELL":"FLAT";
   MakeLabel("JPPAI_P_DIR",  "Signal: "+dirStr,x,y,
             dir>0?clrLime:dir<0?clrRed:clrGray,8); y+=dy;
   MakeLabel("JPPAI_P_NEWS", "News: "+(g_newsBlocked?"BLOCKED":"clear"),x,y,
             g_newsBlocked?clrRed:clrLime,8); y+=dy;
   MakeLabel("JPPAI_P_MODE", "Mode: "+(g_manualMode?"MANUAL":"AUTO"), x,y,
             g_manualMode?clrOrange:clrLime,8); y+=dy;

   // Counts
   int buyPos =CountBasketByType(ORDER_TYPE_BUY);
   int sellPos=CountBasketByType(ORDER_TYPE_SELL);
   MakeLabel("JPPAI_P_POS",  "Pos B:"+IntegerToString(buyPos)+" S:"+IntegerToString(sellPos),
             x,y,clrWhite,8); y+=dy;

   // Max DD
   MakeLabel("JPPAI_P_DD",   "MaxDD: "+DoubleToString(g_ddMaxPct,1)+"%",x,y,clrOrange,8); y+=dy+5;

   // Buttons
   if(ShowMainPanel)
     {
      int bx=x, by=y;
      MakeButton("JPPAI_BTN_MANUAL", g_manualMode?"AUTO":"MANUAL",bx,by,80,20,
                 g_manualMode?clrDarkOrange:clrDarkGreen,clrWhite,8);
      bx+=85;
      MakeButton("JPPAI_BTN_LOT_MINUS","-",bx,by,20,20,clrDimGray,clrWhite,10);
      bx+=22;

      // Track lot editor position for mouse hit-test
      g_lotBtnX=bx; g_lotBtnY=by; g_lotBtnW=60; g_lotBtnH=20;
      MakeButton("JPPAI_BTN_LOT_VALUE",
                 g_keyboardEdit?g_keyboardBuf+"_":DoubleToString(ManualButtonLot(),g_lotDigits),
                 bx,by,60,20,clrDimGray,g_keyboardEdit?clrYellow:clrWhite,8);
      bx+=62;
      MakeButton("JPPAI_BTN_LOT_PLUS","+",bx,by,20,20,clrDimGray,clrWhite,10);
      by+=25;
      bx=x;
      MakeButton("JPPAI_BTN_BUY", "BUY",  bx,by,60,24,clrDarkGreen,clrWhite,9);
      bx+=65;
      MakeButton("JPPAI_BTN_SELL","SELL", bx,by,60,24,clrDarkRed,  clrWhite,9);
     }

   EnsureCloseButton();
  }

void DeleteAllPanelObjects()
  {
   string pfxs[] = {"JPPAI_P_","JPPAI_BTN_","JPPAI_NEWS_","CL","JPPAI_LevelLine"};
   for(int i=ObjectsTotal(0,0,-1)-1; i>=0; i--)
     {
      string nm=ObjectName(0,i,0,-1);
      for(int k=0;k<ArraySize(pfxs);k++)
         if(StringFind(nm,pfxs[k],0)==0){ ObjectDelete(0,nm); break; }
     }
  }
//+------------------------------------------------------------------+
