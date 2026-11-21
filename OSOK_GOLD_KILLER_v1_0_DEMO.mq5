//+------------------------------------------------------------------+
//|                                   OSOK_GOLD_KILLER_v1_0_DEMO.mq5  |
//|                 OSOK_GOLD_KILLER_v1_0_DEMO                        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "https://t.me/DRmus4vi"
#property version   "1.10"
#property strict

//==================================================================
//  Inputs  
//==================================================================
input group "=== Trading ==="
input long    InpMagic            = 26071702; // Magic number (magic filter, 0 = off)
input double  InpStartLot         = 0.10;     // Start lot                 [gv44]
input double  InpLotFactor        = 1.60;     // Recovery lot multiplier   [gv43=0.6 -> 1.6]
input double  InpZoneGapPips      = 25.0;     // Zone gap, pips            [gv41 / gi8_24]
input double  InpZoneTargetPips   = 10.0;     // Basket take-profit, pips  [gv45 / gi8_21]
input int     InpMaxZoneLegs      = 8;        // Max recovery legs
input int     InpDeviation        = 10;       // Slippage, points          [unk_1001D]
input bool    InpStartWithBuy     = true;     // First order direction: true=BUY / false=SELL
input bool    InpReenterAfterTP   = true;     // Start a new cycle after basket TP (fu5401)

input group "=== Spread guard ==="
input double  InpMaxSpreadPips    = 100.0;    // Max spread, pips (0 = UNLIMITED) [gv33]

input group "=== Daily profit target ==="
input bool    InpUseDailyTarget   = true;     // Stop when reached         [gv39]
input double  InpDailyTargetPct   = 10.0;     // Daily target, % of equity (0 = unlimited) [gv67]

input group "=== News filter ==="
input bool    InpNewsEnabled      = true;     // Enable news filter        [gi1_26]
input int     InpNewsMinImportance= 2;        // Min importance 1..3       [gi4_27]
input int     InpNewsBeforeMin    = 30;       // Block before news, min    [gi4_28]
input int     InpNewsAfterMin     = 30;       // Block after news, min     [gi4_29]
input uint    InpRefreshSeconds   = 30;       // Scan interval, sec (>=5)  [gi4_30]

input group "=== Dashboard ==="
input bool    InpShowDashboard    = true;     // Show dashboard            [gv49]
input bool    InpAutoScale        = true;     // Auto-scale with chart size[gv58]
input double  InpScaleMin         = 0.8;      // Min scale factor          [gv102]
input int     InpCorner           = 0;        // Chart corner (0..3)
input int     InpX                = 20;       // Panel X offset
input int     InpY                = 10;       // Panel Y offset

//==================================================================
//  Palette 
//==================================================================
#define CLR_PANEL   C'24,28,38'
#define CLR_HEADER  C'34,40,56'
#define CLR_ROW     C'30,36,48'
#define CLR_ROW2    C'27,33,44'
#define CLR_TEXT    clrWhite
#define CLR_MUTED   C'158,163,175'
#define CLR_GREEN   C'46,183,102'   // 3649254
#define CLR_RED     C'224,82,82'
#define CLR_ORANGE  C'214,137,56'   // ~3749590
#define CLR_BLUE    C'66,120,190'
#define CLR_EDGEBG  C'18,21,30'

#define OBJ_PREFIX  "OSK_"                 // [InpPrefix / unk_10E30]

//==================================================================
//  Small utilities
//==================================================================
double PipPoint(const string sym=NULL)
{
   const string s = (sym==NULL ? _Symbol : sym);
   const long digits = SymbolInfoInteger(s, SYMBOL_DIGITS);
   return (digits==3 || digits==5) ? 10.0*_Point : _Point;   // [gp[8] 3/5-digit rule]
}

double NormalizeLot(const string sym, const double lots)
{
   double mn=0, mx=0, st=0;
   SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, mn);
   SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX, mx);
   SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP, st);
   if(st<=0) st=0.01;
   double v = MathFloor(lots/st)*st;
   v = MathMax(mn, MathMin(mx, v));
   return NormalizeDouble(v, 8);
}

// Short timeframe label, e.g. "M15","H1"  (replaces unk_15850 binary search + itoa fallback)
string TFShort(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);          // "PERIOD_M15"
   StringReplace(s, "PERIOD_", "");
   if(StringLen(s)>=2 && s[0]=='M' && s[1]=='N') s="MN"+StringSubstr(s,2);
   return s;
}

string Money(const double v, const int d=2) { return DoubleToString(v, d); }

double Equity()  { return AccountInfoDouble(ACCOUNT_EQUITY); }
double Balance() { return AccountInfoDouble(ACCOUNT_BALANCE); }

double SpreadPips()
{
   const long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return sp * _Point / PipPoint();
}

bool TerminalTradeOK()
{
   return TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
       && MQLInfoInteger(MQL_TRADE_ALLOWED)
       && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
}

//==================================================================
//  CTradeHelper  — order sending, filling policy, result texts
//==================================================================
class CTradeHelper
{
   ENUM_ORDER_TYPE_FILLING m_fill;
   string m_sym;
public:
   bool Init(const string sym)
   {
      m_sym = sym;
      // [fu5347] map SYMBOL_FILLING_MODE bitmask onto a policy the
      // server accepts; prefer IOC on exchange-style symbols.
      const long fm = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
      if((fm & ORDER_FILLING_IOC) != 0)        m_fill = ORDER_FILLING_IOC;   // bit 2
      else if((fm & ORDER_FILLING_FOK) != 0)   m_fill = ORDER_FILLING_FOK;   // bit 1
      else                                     m_fill = ORDER_FILLING_RETURN;
      return true;
   }

   // [fu5336] send and verify; returns true on 10008/10009
   bool Send(MqlTradeRequest &req, MqlTradeResult &res)
   {
      ZeroMemory(res);
      req.type_filling = m_fill;                 // policy from Init()   [fu5347]
      if(req.deviation == 0)
         req.deviation = InpDeviation;
      if(InpMagic != 0 && req.magic == 0)
         req.magic = (ulong)InpMagic;

      const bool sent = OrderSend(req, res);        // fs240 path (sync)
      if(!sent)
      {
         Print("OSK: OrderSend failed, retcode=", res.retcode,
               " (", RetcodeText(res.retcode), ")");
         return false;
      }
      // fu5336 retcode gate: success only on PLACED / DONE
      const bool ok = (res.retcode == TRADE_RETCODE_PLACED ||
                       res.retcode == TRADE_RETCODE_DONE   ||
                       res.retcode == TRADE_RETCODE_DONE_PARTIAL);
      if(!ok)
         PrintFormat("OSK: order rejected: %s (%d) — %s",
                     RetcodeText(res.retcode), res.retcode, RequestText(req));
      return ok;
   }

   // convenience wrapper for a DEAL request (also used to close by ticket)
   bool Deal(const ENUM_ORDER_TYPE type, const double lots,
             const string comment, const ulong position_ticket=0)
   {
      MqlTradeRequest req;  ZeroMemory(req);
      MqlTradeResult  res;
      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = m_sym;
      req.type     = type;
      req.volume   = NormalizeLot(m_sym, lots);
      req.comment  = comment;
      req.position = position_ticket;
      req.price    = (type==ORDER_TYPE_BUY) ? SymbolInfoDouble(m_sym, SYMBOL_ASK)
                                            : SymbolInfoDouble(m_sym, SYMBOL_BID);
      if(req.volume < SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN)) { Print("OSK: lot below SYMBOL_VOLUME_MIN"); return false; }
      return Send(req, res);
   }

   static string TypeName(const int type)          // [fu5340]
   {
      switch(type)
      {
         case ORDER_TYPE_BUY:            return "Buy";
         case ORDER_TYPE_SELL:           return "Sell";
         case ORDER_TYPE_BUY_LIMIT:      return "Buy Limit";
         case ORDER_TYPE_SELL_LIMIT:     return "Sell Limit";
         case ORDER_TYPE_BUY_STOP:       return "Buy Stop";
         case ORDER_TYPE_SELL_STOP:      return "Sell Stop";
         case ORDER_TYPE_BUY_STOP_LIMIT: return "Buy Stop Limit";
         case ORDER_TYPE_SELL_STOP_LIMIT:return "Sell Stop Limit";
         default:                        return StringFormat("Type(%d)", type);
      }
   }

   string RequestText(const MqlTradeRequest &r) const   // [fu5345]
   {
      return StringFormat("%s %s %s @ %s vol=%.2f sl=%s tp=%s",
                          m_sym, (r.action==TRADE_ACTION_DEAL?"DEAL":"#"+(string)r.action),
                          TypeName((int)r.type),
                          DoubleToString(r.price, _Digits), r.volume,
                          (r.sl>0 ? DoubleToString(r.sl,_Digits) : "-"),
                          (r.tp>0 ? DoubleToString(r.tp,_Digits) : "-"));
   }

   static string RetcodeText(const uint code)            // [fu5346]
   {
      switch(code)
      {
         case TRADE_RETCODE_REQUOTE:            return "Requote";
         case TRADE_RETCODE_REJECT:             return "Request rejected";
         case TRADE_RETCODE_CANCEL:             return "Request cancelled by trader";
         case TRADE_RETCODE_PLACED:             return "Order placed";           // 10008
         case TRADE_RETCODE_DONE:               return "Request completed";      // 10009
         case TRADE_RETCODE_DONE_PARTIAL:       return "Partially completed";
         case TRADE_RETCODE_ERROR:              return "Request processing error";
         case TRADE_RETCODE_TIMEOUT:            return "Request timeout";
         case TRADE_RETCODE_INVALID:            return "Invalid request";
         case TRADE_RETCODE_INVALID_VOLUME:     return "Invalid volume";
         case TRADE_RETCODE_INVALID_PRICE:      return "Invalid price";
         case TRADE_RETCODE_INVALID_STOPS:      return "Invalid stops";
         case TRADE_RETCODE_TRADE_DISABLED:     return "Trade disabled";
         case TRADE_RETCODE_MARKET_CLOSED:      return "Market closed";
         case TRADE_RETCODE_NO_MONEY:           return "Not enough money";
         case TRADE_RETCODE_PRICE_CHANGED:      return "Price changed";
         case TRADE_RETCODE_PRICE_OFF:          return "No quotes";
         case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
         case TRADE_RETCODE_ORDER_CHANGED:      return "Order state changed";
         case TRADE_RETCODE_TOO_MANY_REQUESTS:  return "Too many requests";
         case TRADE_RETCODE_NO_CHANGES:         return "No changes";
         case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
         case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client";
         case TRADE_RETCODE_LOCKED:             return "Request locked";
         case TRADE_RETCODE_FROZEN:             return "Order/position frozen";
         case TRADE_RETCODE_INVALID_FILL:       return "Invalid filling mode";   // 10030
         case TRADE_RETCODE_CONNECTION:         return "No connection";
         case TRADE_RETCODE_ONLY_REAL:          return "Only real accounts";
         case TRADE_RETCODE_LIMIT_ORDERS:       return "Order limit reached";
         case TRADE_RETCODE_LIMIT_VOLUME:       return "Volume limit reached";
         case TRADE_RETCODE_INVALID_ORDER:      return "Invalid order type";     // 10035
         case TRADE_RETCODE_POSITION_CLOSED:    return "Position already closed";
         default:                               return StringFormat("Retcode %u", code);
      }
   }
};

//==================================================================
//  CNewsFilter — economic calendar window guard
//==================================================================
class CNewsFilter
{
   datetime m_nextScan;      // [gv77]
   datetime m_nearest;       // [gv75]
   datetime m_winEnd;        // [gv76]
public:
   bool     active;          // [gv74[0]]
   string   eventName;       // [gv79]
   string   eventCurrency;   // [gv78]

   CNewsFilter() : m_nextScan(0), m_nearest(0), m_winEnd(0), active(false) {}

   void Reset()
   {
      active=false; m_nearest=0; m_winEnd=0;
      eventName=""; eventCurrency=""; m_nextScan=0;
   }

   void Update()                                          // [fu5382]
   {
      if(!InpNewsEnabled) { Reset(); return; }
      const datetime now = TimeCurrent();
      if(now < m_nextScan) return;                       // cached between scans
      const uint cadence = (uint)MathMax(5, (int)InpRefreshSeconds);
      m_nextScan = now + (datetime)cadence;

      const datetime from = now - (datetime)(InpNewsAfterMin  * 60);   // [t-60*gi4_29]
      const datetime to   = now + (datetime)(InpNewsBeforeMin * 60);   // [t+60*gi4_28]

      active=false; m_nearest=0; m_winEnd=0; eventName=""; eventCurrency="";

      // scan the symbol's base & quote currencies (fs47(22)/fs47(23) lists)
      string cur[2];
      cur[0] = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
      cur[1] = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
      if(cur[1] == cur[0]) cur[1] = "";

      datetime best = LONG_MAX;
      for(int c=0; c<2; c++)
      {
         if(cur[c]=="") continue;
         ScanCurrency(cur[c], from, to, best);
      }
      active = (m_winEnd > 0 && now <= m_winEnd);
   }

   string StatusText() const
   {
      if(!InpNewsEnabled) return "OFF";
      if(active)          return StringFormat("BLOCKED: %s (%s)", eventName, eventCurrency);
      if(m_nearest>0)     return StringFormat("clear (next: %s @ %s)",
                                              eventName, TimeToString(m_nearest, TIME_DATE|TIME_MINUTES));
      return "clear";
   }

private:
   void ScanCurrency(const string currency, const datetime from, const datetime to, datetime &best)  // [fu5381]
   {
      MqlCalendarValue vals[];
      const int n = CalendarValueHistory(vals, from, to, NULL, currency);
      for(int i=0; i<n; i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id, ev))      continue;
         if((int)ev.importance < InpNewsMinImportance)     continue;     // [gi4_27]
         const datetime t = vals[i].time;
         if(t >= from && t <= to)                                        // inside block window
         {
            active = true;
            const datetime end = t + (datetime)(InpNewsAfterMin*60);
            if(end > m_winEnd) m_winEnd = end;                           // [gv76]
         }
         const long d = (long)MathAbs((double)((long)t - (long)TimeCurrent()));
         if(d < best)
         {
            best = d;
            m_nearest    = t;                                            // [gv75]
            eventName    = ev.name;                                      // [gv79]
            eventCurrency= currency;                                     // [gv78]
         }
      }
   }
};

//==================================================================
//  Basket snapshot (single-pass scan)  [fu5396 / fu5372]
//==================================================================
struct SBasket
{
   int      count;        // legs
   int      dir;          // +1 net long, -1 net short, 0 none
   double   lotsLong, lotsShort;
   double   profit;       // profit + swap
   double   lastPrice;    // open price of the LATEST leg
   datetime lastTime;
   double   bePrice;      // volume-weighted break-even
   double   tpPrice;      // basket take-profit price            [gv63]
   double   recoveryPrice;// price that triggers the next leg
};

bool ScanBasket(SBasket &b)
{
   ZeroMemory(b);
   double pvLong=0, pvShort=0;
   const ulong magic = (ulong)InpMagic;

   for(int i=PositionsTotal()-1; i>=0; i--)                       // [fs217 loop]
   {
      const ulong ticket = PositionGetTicket(i);                 // [fs525 select]
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(magic!=0 && PositionGetInteger(POSITION_MAGIC) != (long)magic) continue;

      const double   vol = PositionGetDouble(POSITION_VOLUME);
      const double   op  = PositionGetDouble(POSITION_PRICE_OPEN);
      const long     ty  = PositionGetInteger(POSITION_TYPE);
      const datetime ti  = (datetime)PositionGetInteger(POSITION_TIME);

      b.count++;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(ty==POSITION_TYPE_BUY) { b.lotsLong  += vol; pvLong  += op*vol; }
      else                      { b.lotsShort += vol; pvShort += op*vol; }

      if(ti >= b.lastTime) { b.lastTime=ti; b.lastPrice=op; }    // [fs221(14) latest]
   }
   if(b.count==0) return false;

   const double net = b.lotsLong - b.lotsShort;
   b.dir = (net>0 ? 1 : (net<0 ? -1 : (b.lotsLong>0 ? 1 : -1)));  // flat hedge -> latest wins
   const double totLots = MathMax(b.lotsLong, b.lotsShort);
   b.bePrice = (b.dir>0 ? pvLong/b.lotsLong : pvShort/b.lotsShort);

   const double gap = InpZoneGapPips   * PipPoint();
   const double tgt = InpZoneTargetPips* PipPoint();
   b.tpPrice = NormalizeDouble(b.bePrice + (b.dir>0 ? tgt : -tgt), _Digits);   // [gv63]
   // recovery trigger: gap beyond the edge opposing the current lead side
   const double edge = (b.dir>0) ? (b.lotsShort>0 ? pvShort/b.lotsShort : b.lastPrice)
                                 : (b.lotsLong >0 ? pvLong /b.lotsLong  : b.lastPrice);
   b.recoveryPrice = NormalizeDouble((b.dir>0 ? edge - gap : edge + gap), _Digits);
   return true;
}

//==================================================================
//  CDashboard — fixed object set, dirty-flag updates
//  (fu5412 create / fu5415+fu904+fu905 update / fu5407..fu5411 primitives)
//==================================================================
class CDashboard
{
public:
   enum RowId { R_STATUS=0, R_ACCOUNT, R_LICENSE, R_SYMBOL, R_SPREAD,
                R_NEWS, R_BALEQ, R_BASKET, R_ZONE, R_POS, R_COUNT };
private:
   struct SRowDef { string key; string caption; };
   SRowDef m_rows[R_COUNT];
   string  m_cache[R_COUNT];
   color   m_color[R_COUNT];
   double  m_scale;
   int     m_x, m_y;

public:
   CDashboard() : m_scale(1.0), m_x(0), m_y(0)
   {
      for(int i=0;i<R_COUNT;i++) { m_cache[i]=""; m_color[i]=CLR_TEXT; }
   }

   void Create()                                                  // [fu5412]
   {
      if(!InpShowDashboard) return;
      m_rows[R_STATUS ].key="status";        m_rows[R_STATUS ].caption="STATUS";
      m_rows[R_ACCOUNT].key="account";       m_rows[R_ACCOUNT].caption="ACCOUNT";
      m_rows[R_LICENSE].key="license";       m_rows[R_LICENSE].caption="LICENSE";
      m_rows[R_SYMBOL ].key="symbol_tf";     m_rows[R_SYMBOL ].caption="SYMBOL / TF";
      m_rows[R_SPREAD ].key="spread";        m_rows[R_SPREAD ].caption="SPREAD";
      m_rows[R_NEWS   ].key="news_filter";   m_rows[R_NEWS   ].caption="NEWS FILTER";
      m_rows[R_BALEQ  ].key="balance_equity";m_rows[R_BALEQ  ].caption="BALANCE / EQUITY";
      m_rows[R_BASKET ].key="basket_pl";     m_rows[R_BASKET ].caption="BASKET P/L";
      m_rows[R_ZONE   ].key="trail_start";   m_rows[R_ZONE   ].caption="ZONE GAP / TARGET";
      m_rows[R_POS    ].key="orders";        m_rows[R_POS    ].caption="OPEN POSITIONS";

      m_x = InpX; m_y = InpY;
      const int W = (int)(300*m_scale), rowH=(int)(24*m_scale), pad=(int)(10*m_scale);
      const int H = pad*2 + (int)(34*m_scale) + R_COUNT*(rowH+2) + (int)(34*m_scale);

      Panel(OBJ_PREFIX+"bg",  m_x,    m_y, W, H, CLR_PANEL);
      Panel(OBJ_PREFIX+"hdr", m_x,    m_y, W, (int)(32*m_scale), CLR_HEADER);
      Text (OBJ_PREFIX+"hdr_txt", m_x+pad, m_y+(int)(7*m_scale), "OSK  •  ZONE RECOVERY", CLR_TEXT, (int)(10*m_scale));

      for(int r=0; r<R_COUNT; r++)
      {
         const int y = m_y + (int)(34*m_scale) + pad + r*(rowH+2);
         Panel(OBJ_PREFIX+"row_"+m_rows[r].key, m_x, y, W, rowH, (r%2?CLR_ROW2:CLR_ROW));
         Text(OBJ_PREFIX+"lbl_"+m_rows[r].key, m_x+pad, y+(int)(5*m_scale),
              m_rows[r].caption, CLR_MUTED, (int)(8*m_scale));
         Edit(OBJ_PREFIX+"val_"+m_rows[r].key, m_x+(int)(150*m_scale), y,
              W-(int)(150*m_scale)-pad, rowH);                       // value cells
      }
      const int by = m_y + H - (int)(30*m_scale) - 2;
      Button(OBJ_PREFIX+"btn_trade", m_x+pad, by, (W-3*pad)/2, (int)(28*m_scale), "TRADING: ON", CLR_GREEN);
      Button(OBJ_PREFIX+"btn_reset", m_x+2*pad+(W-3*pad)/2, by, (W-3*pad)/2, (int)(28*m_scale), "RESET DAY", CLR_BLUE);
      for(int i=0;i<R_COUNT;i++) m_cache[i]="";
      ChartRedraw();
   }

   void Destroy() { ObjectsDeleteAll(0, OBJ_PREFIX); ChartRedraw(); }

   // recreate with new scale if chart size changed enough  [fu908 id==9]
   void AutoScale()
   {
      if(!InpShowDashboard || !InpAutoScale) return;
      const long w = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      const long h = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      if(w<=0 || h<=0) return;
      double s = MathMin(w/1100.0, h/700.0);
      s = MathMax(InpScaleMin, MathMin(2.0, s));                  // clamp [base .. 2]
      if(MathAbs(s - m_scale) > 0.04) { m_scale = s; Destroy(); Create(); }
   }

   void SetStatusButton(const bool tradingOn)
   {
      const string n = OBJ_PREFIX+"btn_trade";
      ObjectSetString (0, n, OBJPROP_TEXT, tradingOn ? "TRADING: ON" : "TRADING: OFF");
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, tradingOn ? CLR_GREEN : CLR_RED);
      ObjectSetInteger(0, n, OBJPROP_STATE, false);
   }

   // [fu5415 / fu904 / fu905] rows with change detection (cheap)
   void Row(const int r, const string text, const color c)
   {
      if(!InpShowDashboard) return;
      if(text == m_cache[r] && c == m_color[r]) return;           // skip redundant redraw
      m_cache[r] = text; m_color[r] = c;
      const string n = OBJ_PREFIX+"val_"+m_rows[r].key;
      ObjectSetString (0, n, OBJPROP_TEXT, text);
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   }

   static bool IsButton(const string &sp, string &which)
   {
      if(sp == OBJ_PREFIX+"btn_trade") { which="trade"; return true; }
      if(sp == OBJ_PREFIX+"btn_reset") { which="reset"; return true; }
      return false;
   }

private:
   static void Panel(const string n,const int x,const int y,const int w,const int h,const color bg)
   {
      if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,(ENUM_BASE_CORNER)InpCorner);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);  ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,n,OBJPROP_COLOR,CLR_EDGEBG);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
   }
   static void Text(const string n,const int x,const int y,const string t,const color c,const int fs)
   {
      if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,(ENUM_BASE_CORNER)InpCorner);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
      ObjectSetString(0,n,OBJPROP_FONT,"Segoe UI"); ObjectSetString(0,n,OBJPROP_TEXT,t);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   }
   static void Edit(const string n,const int x,const int y,const int w,const int h)
   {
      if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_EDIT,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,(ENUM_BASE_CORNER)InpCorner);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_COLOR,CLR_TEXT); ObjectSetInteger(0,n,OBJPROP_BGCOLOR,CLR_ROW);
      ObjectSetInteger(0,n,OBJPROP_READONLY,true); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,n,OBJPROP_FONT,"Segoe UI"); ObjectSetInteger(0,n,OBJPROP_ALIGN,ALIGN_LEFT);
      ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,CLR_ROW);
   }
   static void Button(const string n,const int x,const int y,const int w,const int h,const string t,const color bg)
   {
      if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,(ENUM_BASE_CORNER)InpCorner);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetString (0,n,OBJPROP_TEXT,t); ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bg);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,n,OBJPROP_STATE,false);
   }
};

//==================================================================
//  CZoneEngine — state machine: IDLE -> IN_ZONE -> TP -> re-enter
//  (fu5396 compute / fu5401 restart / fu5395 zone lines / fu5386 persistence)
//==================================================================
enum EState { ST_IDLE=0, ST_IN_ZONE, ST_NEWS_BLOCK, ST_DAILY_BLOCK, ST_DISABLED };

class CZoneEngine
{
   CTradeHelper m_trade;
   SBasket      m_b;
   EState       m_state;
   bool         m_enabled;       // [gv65] dashboard button
   int          m_prevCount;
   // daily target                                             [gv66/gv67]
   double       m_dayBaseEquity; datetime m_day;
   bool         m_dailyReached;
public:
   CZoneEngine() : m_state(ST_IDLE), m_enabled(true), m_prevCount(0),
                   m_dayBaseEquity(0), m_dailyReached(false) {}

   bool Init()
   {
      if(!m_trade.Init(_Symbol)) return false;
      LoadDay();
      return true;
   }

   void SetEnabled(const bool v) { m_enabled=v; }
   bool Enabled() const { return m_enabled; }
   const SBasket& Basket() const { return m_b; }
   EState State() const { return m_state; }
   bool DailyReached() const { return m_dailyReached; }

   // ---- per-tick drive ----
   void OnTick(CNewsFilter &news)
   {
      RollDay();

      const bool newsBlock = news.active;

      ScanBasket(m_b);

      if(!m_enabled)                    { m_state=ST_DISABLED;  SyncLines(false); return; }
      if(InpUseDailyTarget && m_dailyReached){ m_state=ST_DAILY_BLOCK; SyncLines(m_b.count>0); return; }
      if(newsBlock)                     { m_state=(m_b.count>0?ST_IN_ZONE:ST_NEWS_BLOCK); }
      else                              { m_state=(m_b.count>0?ST_IN_ZONE:ST_IDLE); }

      // daily target check on closed+floating distance from day base
      if(InpUseDailyTarget && InpDailyTargetPct>0 && m_dayBaseEquity>0 && !m_dailyReached)
      {
         const double pct = 100.0*(Equity()-m_dayBaseEquity)/m_dayBaseEquity;
         if(pct >= InpDailyTargetPct)
         {
            m_dailyReached = true; SaveDay();
            if(m_b.count>0) CloseAll("daily target");
            Print("OSK: daily target reached, trading paused until tomorrow");
         }
      }

      // basket closed between ticks -> restart cycle          [fu5401]
      if(m_prevCount>0 && m_b.count==0 && InpReenterAfterTP && m_enabled && !newsBlock && !m_dailyReached)
         EnterInitial();

      m_prevCount = m_b.count;
      if(m_b.count==0) { SyncLines(false); return; }

      ManageZone();
      SyncLines(true);
   }

   void OnTransaction(const MqlTradeTransaction &trans, CNewsFilter &news) // [fu5401]
   {
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
      if(!HistoryDealSelect(trans.deal)) return;
      if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
      if(InpMagic!=0 && HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
      if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

      // something of ours closed -> rescan and, if basket flat, restart
      SBasket b; ScanBasket(b);
      if(b.count==0 && InpReenterAfterTP && m_enabled && !news.active && !m_dailyReached)
         EnterInitial();
   }

   void ResetDay()                                            // [fu5418]
   {
      m_dailyReached=false; m_dayBaseEquity=Equity(); m_day=DayStamp(); SaveDay();
      Print("OSK: day counters reset (button)");
   }

   double DailyPct() const
   {
      if(m_dayBaseEquity<=0) return 0;
      return 100.0*(Equity()-m_dayBaseEquity)/m_dayBaseEquity;
   }

private:
   void EnterInitial()
   {
      if(InpMaxSpreadPips>0 && SpreadPips()>InpMaxSpreadPips) { Print("OSK: spread guard"); return; }
      const ENUM_ORDER_TYPE t = InpStartWithBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      m_trade.Deal(t, InpStartLot, "OSK zone L0");
   }

   void ManageZone()
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // TP hit -> close basket
      if( (m_b.dir>0 && bid >= m_b.tpPrice) || (m_b.dir<0 && ask <= m_b.tpPrice) )
      {
         CloseAll("basket TP");              // restart handled by OnTransaction
         return;
      }
      // recovery trigger -> add opposite leg with grown lot
      if(m_b.count < InpMaxZoneLegs)
      {
         if( (m_b.dir>0 && bid <= m_b.recoveryPrice) ||
             (m_b.dir<0 && ask >= m_b.recoveryPrice) )
         {
            const double nextLots = NormalizeLot(_Symbol, m_b.dir>0 ? m_b.lotsLong*InpLotFactor
                                                                     : m_b.lotsShort*InpLotFactor);
            const ENUM_ORDER_TYPE t = (m_b.dir>0) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            m_trade.Deal(t, nextLots, StringFormat("OSK zone L%d", m_b.count));
         }
      }
   }

   void CloseAll(const string why)
   {
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(InpMagic!=0 && PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
         const ENUM_ORDER_TYPE close =
            (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         m_trade.Deal(close, PositionGetDouble(POSITION_VOLUME),
                      "OSK close: "+why, ticket);
      }
   }

   // zone_tp_line / zone_recovery_line   [fu5395 deletes then redraws]
   void SyncLines(const bool show)
   {
      const string tp = OBJ_PREFIX+"zone_tp_line", rc = OBJ_PREFIX+"zone_recovery_line";
      if(!show || m_b.count==0)
      {
         ObjectDelete(0,tp); ObjectDelete(0,rc);
         return;
      }
      HLine(tp, m_b.tpPrice,       clrSeaGreen);
      HLine(rc, m_b.recoveryPrice, clrTomato);
   }
   static void HLine(const string n,const double p,const color c)
   {
      if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_HLINE,0,0,p);
      ObjectSetDouble(0,n,OBJPROP_PRICE,p);
      ObjectSetInteger(0,n,OBJPROP_COLOR,c);
      ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   }

   // ---- persistence: one day slot per symbol+magic        [fu5386] ----
   static datetime DayStamp() { return iTime(_Symbol, PERIOD_D1, 0); }
   static string   GVKey()    { return StringFormat("OSK.DAY.%s.%llu", _Symbol, (ulong)InpMagic); }

   void RollDay()
   {
      if(DayStamp()!=m_day) { m_dailyReached=false; m_dayBaseEquity=Equity(); m_day=DayStamp(); SaveDay(); }
   }
   void SaveDay()
   {
      const string k=GVKey();
      GlobalVariableSet(k,      (double)m_day);
      GlobalVariableSet(k+".E", m_dayBaseEquity);
      GlobalVariableSet(k+".R", m_dailyReached?1:0);
   }
   void LoadDay()
   {
      const string k=GVKey();
      if(!GlobalVariableCheck(k)) { m_day=DayStamp(); m_dayBaseEquity=Equity(); SaveDay(); return; }
      m_day           = (datetime)(long)GlobalVariableGet(k);
      m_dayBaseEquity = GlobalVariableGet(k+".E");
      m_dailyReached  = GlobalVariableGet(k+".R")>0;
      if(m_day!=DayStamp()) { m_dailyReached=false; m_dayBaseEquity=Equity(); m_day=DayStamp(); }
   }
};

//==================================================================
//  Globals 
//==================================================================
CZoneEngine   g_engine;
CNewsFilter   g_news;
CDashboard    g_dash;

string StringRepeat(const string s, const int n);   // defined below

//==================================================================
int OnInit()                                                       // [fu998]
{
   if(!g_engine.Init()) return INIT_FAILED;

   if(InpNewsEnabled)
   {
      // calendar needs terminal connectivity; warn instead of failing
      g_news.Update();
   }

   g_dash.Create();
   g_dash.SetStatusButton(g_engine.Enabled());
   EventSetTimer((int)MathMax(1, (int)MathMin(60, InpRefreshSeconds)));   // dashboard/news cadence
   Print("OSK EA ready — magic=", InpMagic, " gap=", InpZoneGapPips,
         "p tp=", InpZoneTargetPips, "p lot=", InpStartLot);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)                                    // [fu999]
{
   EventKillTimer();
   g_dash.Destroy();
}

void OnTick()
{
   g_engine.OnTick(g_news);
   RefreshDashboard(false);
}

void OnTimer()
{
   g_news.Update();             // throttled internally (>=5s)     [fu5382]
   g_dash.AutoScale();          // cheap size probe                [fu908]
   RefreshDashboard(true);
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& req, const MqlTradeResult& res)
{
   g_engine.OnTransaction(trans, g_news);                          // [fu5401]
}

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
{
   if(id==CHARTEVENT_CHART_CHANGE) { g_dash.AutoScale(); return; } // [fu908 a1==9]
   if(id!=CHARTEVENT_OBJECT_CLICK) return;                         // [fu908 a1==1]

   string which;
   if(!CDashboard::IsButton(sp, which)) return;

   if(which=="trade")
      g_engine.SetEnabled(!g_engine.Enabled());                    // [gv65 toggle]
   else if(which=="reset")
   {
      g_engine.ResetDay();                                         // [fu5418]
      ObjectSetInteger(0, sp, OBJPROP_STATE, false);               // un-press
   }

   g_dash.SetStatusButton(g_engine.Enabled());
   RefreshDashboard(true);
   ChartRedraw();
}

//==================================================================
//  Dashboard row refresh  [fu5415/fu904/fu905 + fu5359]
//==================================================================
void RefreshDashboard(const bool force)
{
   if(!InpShowDashboard) return;

   const SBasket &b = g_engine.Basket();

   // STATUS
   color sc = CLR_GREEN; string st = "ACTIVE";
   switch(g_engine.State())
   {
      case ST_DISABLED:     st="PAUSED (button)";       sc=CLR_RED;    break;
      case ST_DAILY_BLOCK:  st="DAILY TARGET REACHED";  sc=CLR_ORANGE; break;
      case ST_NEWS_BLOCK:   st="NEWS BLOCK";            sc=CLR_ORANGE; break;
      case ST_IN_ZONE:      st="IN TRADE";              sc=CLR_GREEN;  break;
      default: break;
   }
   if(!TerminalTradeOK()) { st="TRADE NOT ALLOWED"; sc=CLR_RED; }
   g_dash.Row(CDashboard::R_STATUS, st, sc);

   // ACCOUNT
   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   g_dash.Row(CDashboard::R_ACCOUNT, StringFormat("%lld • %s", login,
              AccountInfoString(ACCOUNT_SERVER)), CLR_TEXT);

   // LICENSE row = account mode + daily progress bar           [gv31 path]
   const bool demo = (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);
   string bar;
   if(InpUseDailyTarget && InpDailyTargetPct>0)
   {
      const double p = MathMax(-999, g_engine.DailyPct());
      const int fill = (int)MathMin(10, MathMax(0, MathFloor(10.0*p/InpDailyTargetPct)));
      bar = StringFormat("  [%s%s] %+.1f%%", StringRepeat("█", fill),
                         StringRepeat("░", 10-fill), p);
   }
   g_dash.Row(CDashboard::R_LICENSE, (demo?"DEMO":"REAL")+bar, CLR_MUTED);

   // SYMBOL / TF + SPREAD
   g_dash.Row(CDashboard::R_SYMBOL, _Symbol+"  |  "+TFShort(Period()), CLR_TEXT);
   g_dash.Row(CDashboard::R_SPREAD, DoubleToString(SpreadPips(),1)+" pips",
              (InpMaxSpreadPips>0 && SpreadPips()>InpMaxSpreadPips)?CLR_RED:CLR_TEXT);

   // NEWS FILTER
   g_dash.Row(CDashboard::R_NEWS, g_news.StatusText(), g_news.active?CLR_ORANGE:CLR_TEXT);

   // BALANCE / EQUITY
   g_dash.Row(CDashboard::R_BALEQ, Money(Balance())+" / "+Money(Equity()), CLR_TEXT);

   // BASKET P/L  (profit+swap, with daily % context)          [fu904 ' / UNLIMITED']
   {
      color c = (b.profit>0?CLR_GREEN:(b.profit<0?CLR_RED:CLR_TEXT));
      string t = Money(b.profit);
      if(!InpUseDailyTarget || InpDailyTargetPct==0) t += " / UNLIMITED";
      else t += StringFormat("  (%+.1f%% of day)", g_engine.DailyPct());
      g_dash.Row(CDashboard::R_BASKET, t, c);
   }

   // ZONE GAP / TARGET
   g_dash.Row(CDashboard::R_ZONE,
              StringFormat("%.1f / %.1f pips", InpZoneGapPips, InpZoneTargetPips), CLR_TEXT);

   // OPEN POSITIONS
   g_dash.Row(CDashboard::R_POS, (string)b.count, b.count>0?CLR_GREEN:CLR_MUTED);

   if(force) ChartRedraw();
}

//+------------------------------------------------------------------+
//| helper kept out of the class: MQL5 lacks str-repeat              |
//+------------------------------------------------------------------+
string StringRepeat(const string s, const int n)
{
   string r="";
   for(int i=0;i<n;i++) r+=s;
   return r;
}
//+------------------------------------------------------------------+
