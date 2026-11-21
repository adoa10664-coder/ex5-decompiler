//+------------------------------------------------------------------+
//|                                          ICT_Mentorship_Suite.mq5 |
//|  ICT Mentorship (Months 1-10) concepts on chart + dashboard       |
//|  Structure, OB, Breaker, FVG, Premium/Discount, OTE, Liquidity,   |
//|  IPDA, Po3 opens, Asian range / CBDR + SD, Kill zones, Judas,     |
//|  Turtle Soup, Sweep+MSS, SMT, HTF bias, trade management, stats   |
//|                                                                    |
//|  v2.10 fixes (verified against ICT 2016 Mentorship M1-M10):       |
//|   - OB zones now use body (open/close) not wicks  [M4-V3]         |
//|   - Breaker zones inherit body-only boundaries    [M4-V5]         |
//|   - CheckSignals: HTF bias (g_bias) now gates all entries [M3]    |
//|   - CheckSignals: weekly open filter added        [M8-V1]         |
//|   - OTE: HTF bias gate added                      [M3]            |
//|   - Turtle Soup: HTF bias gate added              [M2]            |
//|   - Judas: CBDR < 40pip + Asian range width gate [M8-V5]         |
//|   - Dashboard: weekly open vs price, CBDR >40pip warning [M8-V3] |
//+------------------------------------------------------------------+
#property copyright   "ICT Mentorship Suite"
#property link        ""
#property version     "2.10"
#property indicator_chart_window
#property indicator_plots 0

#define PFX        "ICT_"
#define DPFX       "ICTD_"
#define DASH_LINES 26
#define MAX_SETUPS 8

enum ENUM_SETUP_TYPE
  {
   ST_NONE=0,
   ST_OB,          // M1  Order block retest
   ST_FVG,         // M1  Fair value gap retest
   ST_BREAKER,     // M1/M8 Breaker retest
   ST_OTE,         // M1/M8 Optimal Trade Entry 62-79%
   ST_SWEEP_MSS,   // M7  Market maker model: sweep -> MSS -> OB
   ST_TURTLE,      // M6  Turtle soup (stop hunt) reversal
   ST_JUDAS        // M3  Judas swing vs Asian range in London
  };

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
input group "=== General ==="
input int      InpLookback      = 1500;     // Bars to analyse
input int      InpSwingLen      = 5;        // Swing strength (bars each side)
input int      InpMaxZones      = 5;        // Max active zones per type/direction
input bool     InpShowMitigated = false;    // Show mitigated zones (dotted)
input int      InpDaysDraw      = 5;        // Days of sessions/opens to draw

input group "=== M1: Structure / Order Blocks / FVG / Breakers ==="
input bool     InpShowStructure = true;
input color    InpBOSColor      = clrDodgerBlue;
input color    InpMSSColor      = clrOrangeRed;
input bool     InpShowOB        = true;
input color    InpBullOB        = C'0,90,70';
input color    InpBearOB        = C'110,30,30';
input bool     InpShowBreaker   = true;
input color    InpBullBreaker   = C'60,60,130';
input color    InpBearBreaker   = C'110,50,130';
input bool     InpShowFVG       = true;
input double   InpMinFVGATR     = 0.10;     // Min FVG size (x ATR14)
input color    InpBullFVG       = C'0,70,90';
input color    InpBearFVG       = C'90,40,60';

input group "=== M1/M9: Premium-Discount / Dealing range / OTE ==="
input bool     InpShowPD        = true;     // Show premium/discount + EQ
input int      InpDealBars      = 120;      // Dealing range lookback (bars)
input color    InpPremColor     = C'38,22,22';
input color    InpDiscColor     = C'22,38,22';
input bool     InpShowOTE       = true;     // Show live OTE band
input double   InpMinLegATR     = 2.0;      // Min impulse leg size for OTE (x ATR14)
input color    InpOTEColor      = clrDarkOrange;

input group "=== M2: Liquidity / SMT / IPDA / Power of Three ==="
input bool     InpShowLiq       = true;     // Equal highs/lows
input double   InpEqTolATR      = 0.15;     // EQH/EQL tolerance (x ATR14)
input color    InpLiqColor      = clrGold;
input bool     InpShowPDHL      = true;     // Previous day high/low
input bool     InpShowPWHL      = true;     // Previous week high/low
input string   InpSMTSymbol     = "";       // SMT correlated symbol (e.g. EURUSD, DXY)
input bool     InpSMTInverse    = false;    // Correlated symbol is inversely correlated
input bool     InpShowIPDA      = true;     // IPDA 20/40/60 day highs/lows
input bool     InpShowDayOpen   = true;     // True day open (Po3)
input string   InpDayOpen       = "07:00";  // True day open, server time (=00:00 NY)
input bool     InpShowWeekOpen  = true;     // Weekly open line

input group "=== M3: Sessions (server HH:MM-HH:MM) / Kill zones / Asia / CBDR ==="
input bool     InpShowKZ        = true;
input string   InpAsiaKZ        = "02:00-07:00";  // Asia KZ / Asian range
input string   InpLondonKZ      = "09:00-12:00";  // London open KZ
input string   InpNYKZ          = "14:00-17:00";  // New York open KZ
input string   InpLCKZ          = "17:00-19:00";  // London close KZ
input color    InpKZColor       = C'28,28,42';
input bool     InpShowAsia      = true;
input color    InpAsiaColor     = clrSlateGray;
input bool     InpShowCBDR      = true;
input string   InpCBDR          = "21:00-02:00";  // CBDR (14:00-20:00 NY)
input color    InpCBDRColor     = clrSteelBlue;
input int      InpSDCount       = 2;              // Std-dev projections (0=off)
input int      InpSDHours       = 12;             // Hours to project SD lines

input group "=== M4/M6: HTF bias / Turtle soup / Judas swing ==="
input ENUM_TIMEFRAMES InpBiasTF = PERIOD_D1;      // HTF bias timeframe
input int      InpTSPeriod      = 20;             // Turtle soup lookback (bars)
input int      InpJudasKZ       = 1;              // Judas kill zone (0 Asia,1 London,2 NY,3 LC)

input group "=== M5: Signals & Trade management ==="
input bool     InpSignals       = true;
input bool     InpRequireKZ     = true;     // Only signal inside kill zones
input bool     InpUseOB         = true;
input bool     InpUseFVG        = true;
input bool     InpUseBreaker    = true;
input bool     InpUseOTE        = true;
input bool     InpUseSweepMSS   = true;
input bool     InpUseTurtle     = true;
input bool     InpUseJudas      = true;
input double   InpTP1R          = 1.0;      // TP1 (partial) in R
input double   InpRR            = 2.0;      // TP2 (final) in R
input bool     InpMoveBE        = true;     // Move SL to entry after TP1
input double   InpSLBufferATR   = 0.20;     // SL buffer beyond zone (x ATR14)
input int      InpSweepWindow   = 15;       // Max bars between sweep and MSS
input bool     InpAlerts        = true;
input bool     InpPush          = false;

input group "=== Dashboard ==="
input bool     InpShowDash      = true;
input int      InpDashX         = 10;
input int      InpDashY         = 25;
input int      InpFontSize      = 9;
input color    InpDashBg        = C'18,18,28';
input color    InpDashText      = clrWhiteSmoke;

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct Swing { int bar; datetime time; double price; bool broken; };

struct Zone
  {
   ENUM_SETUP_TYPE type; bool bull;
   int barStart; int barCreated; datetime tStart; datetime tEnd;
   double top; double bottom; bool mitigated; bool used;
  };

struct Trade
  {
   ENUM_SETUP_TYPE type; bool bull; int barEntry; datetime tEntry;
   double entry, sl, tp1, tp2; bool tp1Hit;
   int result;               // 0 open, 1 TP2, 2 BE after TP1, -1 SL
   datetime tExit;
  };

struct LiqLevel { bool high; double price; datetime t1; datetime t2; bool swept; datetime tSwept; };

//+------------------------------------------------------------------+
//| Globals                                                           |
//+------------------------------------------------------------------+
MqlRates  g_r[];
int       g_n=0;
double    g_atr=0;
Swing     g_sh[], g_sl[];
Zone      g_zones[];
Trade     g_trades[];
LiqLevel  g_liq[];
int       g_trend=0;
string    g_lastEvent="-";
datetime  g_lastEventTime=0;
datetime  g_lastBarTime=0, g_lastAlertTime=0;
int       g_objId=0;
int       g_kzS[4], g_kzE[4];
string    g_kzName[4]={"Asia","London","New York","Ldn Close"};
int       g_cbS=-1, g_cbE=-1, g_dayOpenSec=-1;
double    g_pdh=0,g_pdl=0,g_pwh=0,g_pwl=0;
double    g_eq=0,g_dHi=0,g_dLo=0;
int       g_bias=0; string g_biasEvent="-";
string    g_smt="off";
double    g_ipdaH[3], g_ipdaL[3];

// per-day session data
datetime  g_dayT[]; bool g_aOK[]; double g_aHi[], g_aLo[]; datetime g_aT1[], g_aT2[];
bool      g_cOK[]; double g_cHi[], g_cLo[]; datetime g_cT1[], g_cT2[]; bool g_judas[];

// rolling extremes
double    g_tsHH[], g_tsLL[], g_dHH[], g_dLL[];

// weekly open (Po3 bias gate — ICT M8-V1)
double    g_weekOpen=0;

// CBDR pip size for London/Judas gate (ICT M8-V3/M8-V5: must be < 40 pips)
double    g_cbdrPips=0;
// Asian range pip size for Judas gate (ICT M8-V5: 20-30 pips ideal)
double    g_asiaPips=0;

// impulse leg for OTE
bool g_legActive=false, g_legBull=false, g_legUsed=false;
int  g_legOBar=0, g_legEBar=0; double g_legO=0, g_legE=0;

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
string SetupName(ENUM_SETUP_TYPE t)
  {
   switch(t)
     {
      case ST_OB:        return "OB";
      case ST_FVG:       return "FVG";
      case ST_BREAKER:   return "BREAKER";
      case ST_OTE:       return "OTE";
      case ST_SWEEP_MSS: return "SWEEP+MSS";
      case ST_TURTLE:    return "TURTLE SOUP";
      case ST_JUDAS:     return "JUDAS";
     }
   return "-";
  }

bool SetupEnabled(ENUM_SETUP_TYPE t)
  {
   switch(t)
     {
      case ST_OB:        return InpUseOB;
      case ST_FVG:       return InpUseFVG;
      case ST_BREAKER:   return InpUseBreaker;
      case ST_OTE:       return InpUseOTE;
      case ST_SWEEP_MSS: return InpUseSweepMSS;
      case ST_TURTLE:    return InpUseTurtle;
      case ST_JUDAS:     return InpUseJudas;
     }
   return false;
  }

int ParseHM(string s)
  {
   string p[]; if(StringSplit(s,':',p)!=2) return -1;
   return (int)StringToInteger(p[0])*3600+(int)StringToInteger(p[1])*60;
  }

bool ParseSess(string s,int &st,int &en)
  {
   string p[]; st=-1; en=-1;
   if(StringSplit(s,'-',p)!=2) return false;
   st=ParseHM(p[0]); en=ParseHM(p[1]);
   return (st>=0 && en>=0);
  }

int KZIndex(datetime t)
  {
   int tod=(int)(t%86400);
   for(int i=0;i<4;i++)
     {
      if(g_kzS[i]<0) continue;
      if(g_kzS[i]<=g_kzE[i]) { if(tod>=g_kzS[i] && tod<g_kzE[i]) return i; }
      else                   { if(tod>=g_kzS[i] || tod<g_kzE[i]) return i; }
     }
   return -1;
  }

string NextKZText()
  {
   int tod=(int)(TimeCurrent()%86400), best=INT_MAX, bi=-1;
   for(int k=0;k<4;k++)
     {
      if(g_kzS[k]<0) continue;
      int d=g_kzS[k]-tod; if(d<=0) d+=86400;
      if(d<best){best=d;bi=k;}
     }
   if(bi<0) return "n/a";
   return g_kzName[bi]+" in "+IntegerToString(best/3600)+"h "+IntegerToString((best%3600)/60)+"m";
  }

double CalcATR(int period)
  {
   if(g_n<period+1) return 0;
   double sum=0;
   for(int i=g_n-period;i<g_n;i++)
      sum+=MathMax(g_r[i].high-g_r[i].low,MathMax(MathAbs(g_r[i].high-g_r[i-1].close),MathAbs(g_r[i].low-g_r[i-1].close)));
   return sum/period;
  }

string TF(){ string s=EnumToString(_Period); return StringSubstr(s,7); }
string P(double v){ return DoubleToString(v,_Digits); }
string DOW(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); string d[7]={"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}; return d[dt.day_of_week]; }

int DayIdx(datetime t)
  {
   datetime d=t-(t%86400);
   for(int i=ArraySize(g_dayT)-1;i>=0;i--) if(g_dayT[i]==d) return i;
   return -1;
  }

//+------------------------------------------------------------------+
//| Drawing primitives                                                |
//+------------------------------------------------------------------+
string NewName(string tag){ return PFX+tag+IntegerToString(g_objId++); }

void Rect(datetime t1,double p1,datetime t2,double p2,color c,bool fill,ENUM_LINE_STYLE st,string tag)
  {
   string n=NewName(tag);
   ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,p1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);  ObjectSetInteger(0,n,OBJPROP_FILL,fill);
   ObjectSetInteger(0,n,OBJPROP_BACK,true); ObjectSetInteger(0,n,OBJPROP_STYLE,st);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
  }

void Line(datetime t1,double p1,datetime t2,double p2,color c,int w,ENUM_LINE_STYLE st,string tag)
  {
   string n=NewName(tag);
   ObjectCreate(0,n,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_WIDTH,w);
   ObjectSetInteger(0,n,OBJPROP_STYLE,st); ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
  }

void Text(datetime t,double p,string txt,color c,ENUM_ANCHOR_POINT anchor,int size,string tag)
  {
   string n=NewName(tag);
   ObjectCreate(0,n,OBJ_TEXT,0,t,p);
   ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetString(0,n,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
  }

void Arrow(datetime t,double p,ENUM_OBJECT type,color c,string tag)
  {
   string n=NewName(tag);
   ObjectCreate(0,n,type,0,t,p);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
//| Sessions / per-day data                                           |
//+------------------------------------------------------------------+
bool SessionRange(datetime day,int s,int e,double &hi,double &lo,datetime &t1,datetime &t2)
  {
   t1=day+s; t2=day+e; if(e<=s) t1-=86400;
   hi=-DBL_MAX; lo=DBL_MAX; bool any=false;
   for(int j=0;j<=g_n;j++)
     {
      if(g_r[j].time<t1) continue;
      if(g_r[j].time>=t2) break;
      any=true; hi=MathMax(hi,g_r[j].high); lo=MathMin(lo,g_r[j].low);
     }
   return any;
  }

void BuildDays()
  {
   ArrayFree(g_dayT);
   datetime d0=g_r[0].time-(g_r[0].time%86400), dN=g_r[g_n].time-(g_r[g_n].time%86400);
   int nd=(int)((dN-d0)/86400)+1;
   ArrayResize(g_dayT,nd); ArrayResize(g_aOK,nd); ArrayResize(g_aHi,nd); ArrayResize(g_aLo,nd);
   ArrayResize(g_aT1,nd); ArrayResize(g_aT2,nd); ArrayResize(g_cOK,nd); ArrayResize(g_cHi,nd);
   ArrayResize(g_cLo,nd); ArrayResize(g_cT1,nd); ArrayResize(g_cT2,nd); ArrayResize(g_judas,nd);
   for(int i=0;i<nd;i++)
     {
      g_dayT[i]=d0+i*86400; g_judas[i]=false;
      g_aOK[i]=(g_kzS[0]>=0) && SessionRange(g_dayT[i],g_kzS[0],g_kzE[0],g_aHi[i],g_aLo[i],g_aT1[i],g_aT2[i]);
      g_cOK[i]=(g_cbS>=0)    && SessionRange(g_dayT[i],g_cbS,g_cbE,g_cHi[i],g_cLo[i],g_cT1[i],g_cT2[i]);
     }
  }

void DrawSessionBox(datetime t1,double hi,datetime t2,double lo,color c,string name,string sdTag)
  {
   Rect(t1,hi,t2,lo,c,false,STYLE_SOLID,"SB");
   Text(t1,hi,name,c,ANCHOR_LEFT_LOWER,7,"ST");
   if(InpSDCount<=0) return;
   double R=hi-lo; datetime te=t2+InpSDHours*3600;
   for(int k=1;k<=InpSDCount;k++)
     {
      Line(t2,hi+k*R,te,hi+k*R,c,1,STYLE_DOT,"SD"); Text(te,hi+k*R,"+"+IntegerToString(k)+"SD "+sdTag,c,ANCHOR_RIGHT_LOWER,7,"SDT");
      Line(t2,lo-k*R,te,lo-k*R,c,1,STYLE_DOT,"SD"); Text(te,lo-k*R,"-"+IntegerToString(k)+"SD "+sdTag,c,ANCHOR_RIGHT_UPPER,7,"SDT");
     }
  }

void DrawSessions()
  {
   int nd=ArraySize(g_dayT);
   for(int d=MathMax(0,nd-InpDaysDraw);d<nd;d++)
     {
      if(InpShowAsia && g_aOK[d]) DrawSessionBox(g_aT1[d],g_aHi[d],g_aT2[d],g_aLo[d],InpAsiaColor,"Asian range","A");
      if(InpShowCBDR && g_cOK[d]) DrawSessionBox(g_cT1[d],g_cHi[d],g_cT2[d],g_cLo[d],InpCBDRColor,"CBDR","C");
      if(InpShowDayOpen && g_dayOpenSec>=0)
        {
         datetime to=g_dayT[d]+g_dayOpenSec;
         for(int j=0;j<=g_n;j++)
            if(g_r[j].time>=to)
              {
               if(g_r[j].time-to<PeriodSeconds()*2)
                 { Line(to,g_r[j].open,to+86400,g_r[j].open,clrKhaki,1,STYLE_DOT,"DO"); Text(to,g_r[j].open,"day open",clrKhaki,ANCHOR_LEFT_LOWER,7,"DOT"); }
               break;
              }
        }
     }
   if(InpShowWeekOpen)
     {
      datetime tw=iTime(_Symbol,PERIOD_W1,0); double wo=iOpen(_Symbol,PERIOD_W1,0);
      datetime ext=g_r[g_n].time+PeriodSeconds()*15;
      Line(tw,wo,ext,wo,clrOrchid,1,STYLE_DOT,"WO"); Text(ext,wo,"week open",clrOrchid,ANCHOR_RIGHT_LOWER,7,"WOT");
     }
  }

void DrawKillZones()
  {
   if(!InpShowKZ || PeriodSeconds()>3600) return;
   int nd=ArraySize(g_dayT);
   for(int d=MathMax(0,nd-InpDaysDraw);d<nd;d++)
      for(int k=0;k<4;k++)
        {
         if(g_kzS[k]<0) continue;
         double hi,lo; datetime t1,t2;
         if(!SessionRange(g_dayT[d],g_kzS[k],g_kzE[k],hi,lo,t1,t2)) continue;
         Rect(t1,hi,t2,lo,InpKZColor,true,STYLE_SOLID,"KZ");
         Text(t1,lo,g_kzName[k],clrDimGray,ANCHOR_LEFT_UPPER,7,"KT");
        }
  }

//+------------------------------------------------------------------+
//| Zones                                                             |
//+------------------------------------------------------------------+
void AddZone(ENUM_SETUP_TYPE type,bool bull,int barStart,int barCreated,double bottom,double top)
  {
   int n=ArraySize(g_zones); ArrayResize(g_zones,n+1);
   g_zones[n].type=type; g_zones[n].bull=bull; g_zones[n].barStart=barStart; g_zones[n].barCreated=barCreated;
   g_zones[n].tStart=g_r[barStart].time; g_zones[n].tEnd=0; g_zones[n].top=top; g_zones[n].bottom=bottom;
   g_zones[n].mitigated=false; g_zones[n].used=false;
  }

void CreateOB(int j,bool bull,int fromBar,ENUM_SETUP_TYPE type)
  {
   // ICT M4-V3: bullish OB = the LAST down-close candle before the upward displacement.
   // bearish OB = the LAST up-close candle before the downward displacement.
   // Zone uses BODY (open↔close) only, NOT wicks.  M4-V3: "Focus on bodies for OB levels."
   int ob=-1;
   for(int k=j-1;k>=MathMax(fromBar,j-40) && k>=0;k--)
     {
      if( bull && g_r[k].close<g_r[k].open){ob=k;break;}
      if(!bull && g_r[k].close>g_r[k].open){ob=k;break;}
     }
   if(ob<0) return;
   // Body-only zone: MathMin/MathMax of open and close excludes wicks
   double bodyLo=MathMin(g_r[ob].open,g_r[ob].close);
   double bodyHi=MathMax(g_r[ob].open,g_r[ob].close);
   AddZone(type,bull,ob,j,bodyLo,bodyHi);
  }

void UpdateZones(int j)
  {
   int cnt=ArraySize(g_zones);
   for(int k=0;k<cnt;k++)
     {
      if(g_zones[k].mitigated || g_zones[k].barCreated>=j) continue;
      bool isOB=(g_zones[k].type==ST_OB || g_zones[k].type==ST_SWEEP_MSS);
      if(g_zones[k].bull && g_r[j].close<g_zones[k].bottom)
        { g_zones[k].mitigated=true; g_zones[k].tEnd=g_r[j].time; if(isOB) AddZone(ST_BREAKER,false,j,j,g_zones[k].bottom,g_zones[k].top); }
      else if(!g_zones[k].bull && g_r[j].close>g_zones[k].top)
        { g_zones[k].mitigated=true; g_zones[k].tEnd=g_r[j].time; if(isOB) AddZone(ST_BREAKER,true,j,j,g_zones[k].bottom,g_zones[k].top); }
     }
  }

color ZoneColor(const Zone &z)
  {
   switch(z.type)
     {
      case ST_OB: case ST_SWEEP_MSS: return z.bull?InpBullOB:InpBearOB;
      case ST_FVG:                   return z.bull?InpBullFVG:InpBearFVG;
      case ST_BREAKER:               return z.bull?InpBullBreaker:InpBearBreaker;
     }
   return clrGray;
  }

bool ZoneVisible(const Zone &z)
  {
   switch(z.type)
     {
      case ST_OB: case ST_SWEEP_MSS: return InpShowOB;
      case ST_FVG:                   return InpShowFVG;
      case ST_BREAKER:               return InpShowBreaker;
     }
   return false;
  }

void DrawZones()
  {
   int shown[MAX_SETUPS][2]; ArrayInitialize(shown,0);
   datetime ext=g_r[g_n].time+PeriodSeconds()*10;
   for(int k=ArraySize(g_zones)-1;k>=0;k--)
     {
      Zone z=g_zones[k];
      if(!ZoneVisible(z)) continue;
      if(z.mitigated && !InpShowMitigated) continue;
      int d=z.bull?0:1;
      if(!z.mitigated){ if(shown[z.type][d]>=InpMaxZones) continue; shown[z.type][d]++; }
      datetime te=z.mitigated?z.tEnd:ext;
      Rect(z.tStart,z.top,te,z.bottom,ZoneColor(z),true,z.mitigated?STYLE_DOT:STYLE_SOLID,"Z");
      Text(z.tStart,z.bull?z.bottom:z.top,SetupName(z.type)+(z.bull?" +":" -")+(z.mitigated?" (x)":""),clrSilver,z.bull?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,7,"ZT");
     }
  }

//+------------------------------------------------------------------+
//| Impulse leg / OTE                                                 |
//+------------------------------------------------------------------+
void StartLeg(bool bull,int oBar,double oPrice,int j)
  {
   g_legActive=true; g_legBull=bull; g_legOBar=oBar; g_legO=oPrice; g_legUsed=false;
   g_legE=bull?-DBL_MAX:DBL_MAX; g_legEBar=j;
   for(int k=oBar;k<=j;k++)
     {
      if( bull && g_r[k].high>g_legE){g_legE=g_r[k].high; g_legEBar=k;}
      if(!bull && g_r[k].low <g_legE){g_legE=g_r[k].low;  g_legEBar=k;}
     }
  }

void UpdateLeg(int j)
  {
   if(!g_legActive) return;
   if(g_legBull)
     {
      if(g_r[j].close<g_legO){ g_legActive=false; return; }
      if(g_r[j].high>g_legE){ g_legE=g_r[j].high; g_legEBar=j; g_legUsed=false; }
     }
   else
     {
      if(g_r[j].close>g_legO){ g_legActive=false; return; }
      if(g_r[j].low<g_legE){ g_legE=g_r[j].low; g_legEBar=j; g_legUsed=false; }
     }
  }

void OTELevels(double &f62,double &f705,double &f79)
  {
   double rng=g_legE-g_legO;            // signed
   f62=g_legE-0.62*rng; f705=g_legE-0.705*rng; f79=g_legE-0.79*rng;
  }

void DrawLiveOTE()
  {
   if(!InpShowOTE || !g_legActive || g_legUsed) return;
   if(MathAbs(g_legE-g_legO)<InpMinLegATR*g_atr) return;
   double f62,f705,f79; OTELevels(f62,f705,f79);
   datetime ext=g_r[g_n].time+PeriodSeconds()*10;
   Rect(g_r[g_legEBar].time,f62,ext,f79,InpOTEColor,false,STYLE_DASH,"OTE");
   Line(g_r[g_legEBar].time,f705,ext,f705,InpOTEColor,1,STYLE_DOT,"OTEL");
   Text(ext,f62,"OTE 62-79%",InpOTEColor,ANCHOR_RIGHT_LOWER,7,"OTET");
   Line(g_r[g_legOBar].time,g_legO,ext,g_legO,InpOTEColor,1,STYLE_DASHDOT,"OTEO");
   Text(ext,g_legO,"leg 100%",InpOTEColor,g_legBull?ANCHOR_RIGHT_UPPER:ANCHOR_RIGHT_LOWER,7,"OTET");
  }

//+------------------------------------------------------------------+
//| Trades                                                            |
//+------------------------------------------------------------------+
void OpenTrade(int j,ENUM_SETUP_TYPE type,bool bull,double sl)
  {
   double entry=g_r[j].close, risk=MathAbs(entry-sl);
   if(risk<=_Point) return;
   int n=ArraySize(g_trades); ArrayResize(g_trades,n+1);
   g_trades[n].type=type; g_trades[n].bull=bull; g_trades[n].barEntry=j; g_trades[n].tEntry=g_r[j].time;
   g_trades[n].entry=entry; g_trades[n].sl=sl;
   g_trades[n].tp1=bull?entry+InpTP1R*risk:entry-InpTP1R*risk;
   g_trades[n].tp2=bull?entry+InpRR*risk:entry-InpRR*risk;
   g_trades[n].tp1Hit=false; g_trades[n].result=0; g_trades[n].tExit=0;
  }

void UpdateTrades(int j)
  {
   for(int i=0;i<ArraySize(g_trades);i++)
     {
      if(g_trades[i].result!=0 || g_trades[i].barEntry>=j) continue;
      bool b=g_trades[i].bull;
      double hi=g_r[j].high, lo=g_r[j].low;
      bool slHit = b ? (lo<=g_trades[i].sl) : (hi>=g_trades[i].sl);
      if(slHit){ g_trades[i].result=g_trades[i].tp1Hit?2:-1; g_trades[i].tExit=g_r[j].time; continue; }
      bool tp2Hit = b ? (hi>=g_trades[i].tp2) : (lo<=g_trades[i].tp2);
      if(tp2Hit){ g_trades[i].result=1; g_trades[i].tExit=g_r[j].time; continue; }
      bool tp1Hit = b ? (hi>=g_trades[i].tp1) : (lo<=g_trades[i].tp1);
      if(tp1Hit && !g_trades[i].tp1Hit){ g_trades[i].tp1Hit=true; if(InpMoveBE) g_trades[i].sl=g_trades[i].entry; }
     }
  }

void CheckSignals(int j)
  {
   if(!InpSignals) return;
   int kz=KZIndex(g_r[j].time);
   if(InpRequireKZ && kz<0) return;
   double buf=InpSLBufferATR*g_atr;

   bool openBull=false, openBear=false;
   for(int i=0;i<ArraySize(g_trades);i++)
      if(g_trades[i].result==0){ if(g_trades[i].bull) openBull=true; else openBear=true; }

   // --- ICT M8-V1 weekly open bias gate (Po3):
   // In a bullish week (price above weekly open) day-trade longs only;
   // in a bearish week (price below weekly open) day-trade shorts only.
   // When g_weekOpen is unknown (0) the gate passes both sides.
   bool weekBullOK = (g_weekOpen<=0 || g_r[j].close>=g_weekOpen);
   bool weekBearOK = (g_weekOpen<=0 || g_r[j].close<=g_weekOpen);

   //--- zone-based setups: OB / FVG / BREAKER / SWEEP+MSS
   for(int k=ArraySize(g_zones)-1;k>=0;k--)
     {
      Zone z=g_zones[k];
      if(z.mitigated || z.used || z.barCreated>=j || !SetupEnabled(z.type)) continue;
      if(z.bull)
        {
         // ICT M3: LTF trend must be bullish AND HTF bias must not be bearish (top-down alignment)
         // ICT M8-V1: price must be at/above weekly open (bullish week) or HTF bias is bullish
         if(g_trend!=1 || g_bias==-1 || openBull) continue;
         if(!weekBullOK && g_bias!=1) continue;  // skip if below weekly open unless HTF is confirmed bull
         if(g_r[j].low<=z.top && g_r[j].close>=z.bottom && g_r[j].close>g_r[j].open)
           { g_zones[k].used=true; OpenTrade(j,z.type,true,z.bottom-buf); return; }
        }
      else
        {
         // ICT M3: LTF trend must be bearish AND HTF bias must not be bullish
         // ICT M8-V1: price must be at/below weekly open (bearish week) or HTF bias is bearish
         if(g_trend!=-1 || g_bias==1 || openBear) continue;
         if(!weekBearOK && g_bias!=-1) continue;
         if(g_r[j].high>=z.bottom && g_r[j].close<=z.top && g_r[j].close<g_r[j].open)
           { g_zones[k].used=true; OpenTrade(j,z.type,false,z.top+buf); return; }
        }
     }

   //--- OTE (Optimal Trade Entry 62-79% retracement — ICT M1-V4 / M5)
   // ICT M3: requires LTF trend AND HTF bias alignment; M8-V1 weekly open gate applies
   if(InpUseOTE && g_legActive && !g_legUsed && g_legEBar<j-1 && MathAbs(g_legE-g_legO)>=InpMinLegATR*g_atr)
     {
      double f62,f705,f79; OTELevels(f62,f705,f79);
      if(g_legBull && g_trend==1 && g_bias!=-1 && !openBull && weekBullOK &&
         g_r[j].low<=f705 && g_r[j].close>=f79 && g_r[j].close>g_r[j].open)
        {
         g_legUsed=true; OpenTrade(j,ST_OTE,true,g_legO-buf);
         Rect(g_r[g_legEBar].time,f62,g_r[j].time,f79,InpOTEColor,false,STYLE_DASH,"OTEH"); Text(g_r[g_legEBar].time,f62,"OTE",InpOTEColor,ANCHOR_LEFT_LOWER,7,"OTEHT");
         return;
        }
      if(!g_legBull && g_trend==-1 && g_bias!=1 && !openBear && weekBearOK &&
         g_r[j].high>=f705 && g_r[j].close<=f79 && g_r[j].close<g_r[j].open)
        {
         g_legUsed=true; OpenTrade(j,ST_OTE,false,g_legO+buf);
         Rect(g_r[g_legEBar].time,f62,g_r[j].time,f79,InpOTEColor,false,STYLE_DASH,"OTEH"); Text(g_r[g_legEBar].time,f62,"OTE",InpOTEColor,ANCHOR_LEFT_UPPER,7,"OTEHT");
         return;
        }
     }

   //--- Turtle soup (stop hunt of N-bar extreme, in discount/premium — ICT M1/M2/M6)
   // ICT M4-V11: buy the sell-stop raid below old lows (discount); sell the buy-stop raid above old highs (premium).
   // HTF bias gate: don't take turtle-soup buys when HTF is confirmed bearish, and vice versa.
   if(InpUseTurtle && j>InpTSPeriod && j>InpDealBars)
     {
      double eq=(g_dHH[j]+g_dLL[j])/2.0;
      // Bull turtle soup: price below N-bar low (sell stops swept), close back above, price in DISCOUNT (below EQ), HTF not bearish
      if(!openBull && g_bias!=-1 && weekBullOK &&
         g_r[j].low<g_tsLL[j] && g_r[j].close>g_tsLL[j] && g_r[j].close<eq)
        { OpenTrade(j,ST_TURTLE,true,g_r[j].low-buf); Text(g_r[j].time,g_r[j].low,"TS",clrGold,ANCHOR_UPPER,7,"TSM"); return; }
      // Bear turtle soup: price above N-bar high (buy stops swept), close back below, price in PREMIUM (above EQ), HTF not bullish
      if(!openBear && g_bias!=1 && weekBearOK &&
         g_r[j].high>g_tsHH[j] && g_r[j].close<g_tsHH[j] && g_r[j].close>eq)
        { OpenTrade(j,ST_TURTLE,false,g_r[j].high+buf); Text(g_r[j].time,g_r[j].high,"TS",clrGold,ANCHOR_LOWER,7,"TSM"); return; }
     }

   //--- Judas swing (run beyond Asian range against trend, close back inside — ICT M3/M8/M9)
   // ICT M8-V5 intraday profile gates:
   //   • CBDR must be < 40 pips for a London "normal protraction" Judas (skip if CBDR too wide)
   //   • Asian range should be 20-40 pips (provides the order pool; log a relaxed upper bound of 40)
   // HTF bias gate and weekly open gate also apply.
   if(InpUseJudas && kz==InpJudasKZ)
     {
      int d=DayIdx(g_r[j].time);
      if(d>=0 && g_aOK[d] && !g_judas[d] && g_r[j].time>=g_aT2[d])
        {
         // CBDR gate: skip when CBDR > 40 pips (ICT M8-V3: "ranges larger than ~30 pips tend to be unfruitful")
         bool cbdrOK=(g_cbdrPips<=0 || g_cbdrPips<40.0);
         // Asian range gate: skip when Asian range > 40 pips (too volatile; ideal 20-30 per ICT M8-V5)
         bool asiaOK=(g_asiaPips<=0 || g_asiaPips<=40.0);

         if(cbdrOK && asiaOK && g_trend==-1 && g_bias!= 1 && !openBear && weekBearOK &&
            g_r[j].high>g_aHi[d] && g_r[j].close<g_aHi[d])
           { g_judas[d]=true; OpenTrade(j,ST_JUDAS,false,g_r[j].high+buf); Text(g_r[j].time,g_r[j].high,"JUDAS",clrOrange,ANCHOR_LOWER,7,"JM"); return; }
         if(cbdrOK && asiaOK && g_trend==1 && g_bias!=-1 && !openBull && weekBullOK &&
            g_r[j].low<g_aLo[d] && g_r[j].close>g_aLo[d])
           { g_judas[d]=true; OpenTrade(j,ST_JUDAS,true,g_r[j].low-buf); Text(g_r[j].time,g_r[j].low,"JUDAS",clrOrange,ANCHOR_UPPER,7,"JM"); return; }
        }
     }
  }

void DrawTrades()
  {
   datetime ext=g_r[g_n].time+PeriodSeconds()*5;
   for(int i=0;i<ArraySize(g_trades);i++)
     {
      Trade t=g_trades[i];
      datetime te=(t.result==0)?ext:t.tExit;
      color c=t.bull?clrLime:clrRed;
      Arrow(t.tEntry,t.entry,t.bull?OBJ_ARROW_BUY:OBJ_ARROW_SELL,c,"EN");
      Line(t.tEntry,t.entry,te,t.entry,clrSilver,1,STYLE_DOT,"EL");
      Line(t.tEntry,t.sl,te,t.sl,clrRed,1,STYLE_DASH,"SL");
      Line(t.tEntry,t.tp1,te,t.tp1,clrYellowGreen,1,STYLE_DOT,"TP1");
      Line(t.tEntry,t.tp2,te,t.tp2,clrLime,1,STYLE_DASH,"TP2");
      string lbl=(t.bull?"BUY ":"SELL ")+SetupName(t.type)+"  E "+P(t.entry)+" SL "+P(t.sl)+" TP1 "+P(t.tp1)+" TP2 "+P(t.tp2);
      double lp=t.bull?MathMin(t.sl,t.entry):MathMax(t.sl,t.entry);
      Text(t.tEntry,lp,lbl,c,t.bull?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,7,"TL");
      if(t.result!=0)
        {
         double xp=(t.result==1)?t.tp2:(t.result==2?t.entry:t.sl);
         string xs=(t.result==1)?"TP2 HIT":(t.result==2?"BE (TP1 taken)":"SL HIT");
         color xc=(t.result==-1)?clrRed:(t.result==2?clrYellow:clrLime);
         Arrow(t.tExit,xp,(t.result==-1)?OBJ_ARROW_STOP:OBJ_ARROW_CHECK,xc,"EX");
         Text(t.tExit,xp,xs,xc,ANCHOR_LEFT,7,"XT");
        }
     }
  }

//+------------------------------------------------------------------+
//| Liquidity, PD, IPDA, SMT, HTF bias                                |
//+------------------------------------------------------------------+
void AddLiq(bool high,double price,datetime t1,datetime t2,int fromBar)
  {
   int n=ArraySize(g_liq); ArrayResize(g_liq,n+1);
   g_liq[n].high=high; g_liq[n].price=price; g_liq[n].t1=t1; g_liq[n].t2=t2; g_liq[n].swept=false; g_liq[n].tSwept=0;
   for(int j=fromBar+1;j<g_n;j++)
      if((high && g_r[j].high>price) || (!high && g_r[j].low<price)){ g_liq[n].swept=true; g_liq[n].tSwept=g_r[j].time; break; }
  }

void BuildLiquidity()
  {
   double tol=InpEqTolATR*g_atr;
   for(int i=1;i<ArraySize(g_sh);i++)
      if(MathAbs(g_sh[i].price-g_sh[i-1].price)<=tol)
         AddLiq(true,MathMax(g_sh[i].price,g_sh[i-1].price),g_sh[i-1].time,g_sh[i].time,g_sh[i].bar+InpSwingLen);
   for(int i=1;i<ArraySize(g_sl);i++)
      if(MathAbs(g_sl[i].price-g_sl[i-1].price)<=tol)
         AddLiq(false,MathMin(g_sl[i].price,g_sl[i-1].price),g_sl[i-1].time,g_sl[i].time,g_sl[i].bar+InpSwingLen);
  }

void DrawLiquidity()
  {
   if(!InpShowLiq) return;
   datetime ext=g_r[g_n].time+PeriodSeconds()*10;
   for(int i=0;i<ArraySize(g_liq);i++)
     {
      LiqLevel l=g_liq[i]; datetime te=l.swept?l.tSwept:ext;
      Line(l.t1,l.price,te,l.price,InpLiqColor,1,l.swept?STYLE_DOT:STYLE_SOLID,"LQ");
      Text(te,l.price,(l.high?"EQH":"EQL")+(l.swept?" $$ swept":" $$"),InpLiqColor,l.high?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER,7,"LT");
     }
  }

void DrawPDHL()
  {
   if(PeriodSeconds()>=PeriodSeconds(PERIOD_D1)) return;
   g_pdh=iHigh(_Symbol,PERIOD_D1,1); g_pdl=iLow(_Symbol,PERIOD_D1,1);
   g_pwh=iHigh(_Symbol,PERIOD_W1,1); g_pwl=iLow(_Symbol,PERIOD_W1,1);
   datetime ext=g_r[g_n].time+PeriodSeconds()*15;
   if(InpShowPDHL)
     {
      datetime t0=iTime(_Symbol,PERIOD_D1,0);
      Line(t0,g_pdh,ext,g_pdh,clrAqua,1,STYLE_DASHDOT,"PD"); Text(ext,g_pdh,"PDH",clrAqua,ANCHOR_RIGHT_LOWER,7,"PT");
      Line(t0,g_pdl,ext,g_pdl,clrAqua,1,STYLE_DASHDOT,"PD"); Text(ext,g_pdl,"PDL",clrAqua,ANCHOR_RIGHT_UPPER,7,"PT");
     }
   if(InpShowPWHL)
     {
      datetime tw=iTime(_Symbol,PERIOD_W1,0);
      Line(tw,g_pwh,ext,g_pwh,clrMagenta,1,STYLE_DASHDOT,"PW"); Text(ext,g_pwh,"PWH",clrMagenta,ANCHOR_RIGHT_LOWER,7,"PT");
      Line(tw,g_pwl,ext,g_pwl,clrMagenta,1,STYLE_DASHDOT,"PW"); Text(ext,g_pwl,"PWL",clrMagenta,ANCHOR_RIGHT_UPPER,7,"PT");
     }
  }

void Rolling(int period,double &hh[],double &ll[])
  {
   ArrayResize(hh,g_n); ArrayResize(ll,g_n);
   for(int j=0;j<g_n;j++)
     {
      hh[j]=-DBL_MAX; ll[j]=DBL_MAX;
      if(j<period) continue;
      for(int k=j-period;k<j;k++){ hh[j]=MathMax(hh[j],g_r[k].high); ll[j]=MathMin(ll[j],g_r[k].low); }
     }
  }

void DrawPremiumDiscount()
  {
   int s=MathMax(0,g_n-InpDealBars);
   g_dHi=-DBL_MAX; g_dLo=DBL_MAX;
   for(int j=s;j<g_n;j++){ g_dHi=MathMax(g_dHi,g_r[j].high); g_dLo=MathMin(g_dLo,g_r[j].low); }
   g_eq=(g_dHi+g_dLo)/2.0;
   if(!InpShowPD) return;
   datetime t1=g_r[s].time, ext=g_r[g_n].time+PeriodSeconds()*10;
   Rect(t1,g_dHi,ext,g_eq,InpPremColor,true,STYLE_SOLID,"PDR");
   Rect(t1,g_eq,ext,g_dLo,InpDiscColor,true,STYLE_SOLID,"PDR");
   Line(t1,g_eq,ext,g_eq,clrSilver,1,STYLE_DASHDOT,"EQ");
   Text(ext,g_eq,"EQ "+P(g_eq),clrSilver,ANCHOR_RIGHT_LOWER,7,"EQT");
   Text(t1,g_dHi,"PREMIUM",clrIndianRed,ANCHOR_LEFT_UPPER,7,"PDT");
   Text(t1,g_dLo,"DISCOUNT",clrMediumSeaGreen,ANCHOR_LEFT_LOWER,7,"PDT");
  }

void DrawIPDA()
  {
   for(int i=0;i<3;i++){ g_ipdaH[i]=0; g_ipdaL[i]=0; }
   if(!InpShowIPDA) return;
   double h[],l[]; datetime t[];
   ArraySetAsSeries(h,true); ArraySetAsSeries(l,true); ArraySetAsSeries(t,true);
   if(CopyHigh(_Symbol,PERIOD_D1,1,60,h)<60 || CopyLow(_Symbol,PERIOD_D1,1,60,l)<60 || CopyTime(_Symbol,PERIOD_D1,1,60,t)<60) return;
   int per[3]={20,40,60}; color c[3]={clrDeepSkyBlue,clrRoyalBlue,clrMediumPurple};
   datetime ext=g_r[g_n].time+PeriodSeconds()*20;
   for(int i=0;i<3;i++)
     {
      int ih=ArrayMaximum(h,0,per[i]), il=ArrayMinimum(l,0,per[i]);
      g_ipdaH[i]=h[ih]; g_ipdaL[i]=l[il];
      Line(t[ih],h[ih],ext,h[ih],c[i],1,STYLE_DASH,"IP"); Text(ext,h[ih],"IPDA"+IntegerToString(per[i])+" H",c[i],ANCHOR_RIGHT_LOWER,7,"IPT");
      Line(t[il],l[il],ext,l[il],c[i],1,STYLE_DASH,"IP"); Text(ext,l[il],"IPDA"+IntegerToString(per[i])+" L",c[i],ANCHOR_RIGHT_UPPER,7,"IPT");
     }
  }

double CorrExtreme(datetime tFrom,datetime tTo,bool high)
  {
   double a[]; int n=high?CopyHigh(InpSMTSymbol,_Period,tFrom,tTo,a):CopyLow(InpSMTSymbol,_Period,tFrom,tTo,a);
   if(n<=0) return EMPTY_VALUE;
   return high?a[ArrayMaximum(a)]:a[ArrayMinimum(a)];
  }

void ComputeSMT()
  {
   g_smt=(InpSMTSymbol=="")?"off":"none";
   if(InpSMTSymbol=="") return;
   int w=InpSwingLen*PeriodSeconds();
   int nh=ArraySize(g_sh), nl=ArraySize(g_sl);
   if(nh>=2)
     {
      Swing a=g_sh[nh-2], b=g_sh[nh-1];
      if(b.price>a.price)                                   // chart made higher high
        {
         double ca,cb;
         if(!InpSMTInverse){ ca=CorrExtreme(a.time-w,a.time+w,true);  cb=CorrExtreme(b.time-w,b.time+w,true);  if(ca!=EMPTY_VALUE && cb!=EMPTY_VALUE && cb<ca) g_smt="BEARISH (HH not confirmed by "+InpSMTSymbol+")"; }
         else              { ca=CorrExtreme(a.time-w,a.time+w,false); cb=CorrExtreme(b.time-w,b.time+w,false); if(ca!=EMPTY_VALUE && cb!=EMPTY_VALUE && cb>ca) g_smt="BEARISH (no LL on "+InpSMTSymbol+")"; }
        }
     }
   if(nl>=2 && g_smt=="none")
     {
      Swing a=g_sl[nl-2], b=g_sl[nl-1];
      if(b.price<a.price)                                   // chart made lower low
        {
         double ca,cb;
         if(!InpSMTInverse){ ca=CorrExtreme(a.time-w,a.time+w,false); cb=CorrExtreme(b.time-w,b.time+w,false); if(ca!=EMPTY_VALUE && cb!=EMPTY_VALUE && cb>ca) g_smt="BULLISH (LL not confirmed by "+InpSMTSymbol+")"; }
         else              { ca=CorrExtreme(a.time-w,a.time+w,true);  cb=CorrExtreme(b.time-w,b.time+w,true);  if(ca!=EMPTY_VALUE && cb!=EMPTY_VALUE && cb<ca) g_smt="BULLISH (no HH on "+InpSMTSymbol+")"; }
        }
     }
  }

void ComputeBias()
  {
   g_bias=0; g_biasEvent="-";
   MqlRates d[]; ArraySetAsSeries(d,false);
   int n=CopyRates(_Symbol,InpBiasTF,1,200,d);
   int L=3; if(n<L*2+10) return;
   double lastH=0,lastL=0; bool hasH=false,hasL=false,hB=true,lB=true;
   for(int j=L;j<n;j++)
     {
      int p=j-L;
      if(p>=L)
        {
         bool sh=true,sl=true;
         for(int k=1;k<=L;k++)
           {
            if(d[p].high<=d[p-k].high || d[p].high<d[p+k].high) sh=false;
            if(d[p].low >=d[p-k].low  || d[p].low >d[p+k].low ) sl=false;
           }
         if(sh){lastH=d[p].high;hasH=true;hB=false;}
         if(sl){lastL=d[p].low; hasL=true;lB=false;}
        }
      if(hasH && !hB && d[j].close>lastH){ hB=true; g_biasEvent=(g_bias!=1?"MSS":"BOS")+" UP "+TimeToString(d[j].time,TIME_DATE); g_bias=1; }
      if(hasL && !lB && d[j].close<lastL){ lB=true; g_biasEvent=(g_bias!=-1?"MSS":"BOS")+" DOWN "+TimeToString(d[j].time,TIME_DATE); g_bias=-1; }
     }
  }

//+------------------------------------------------------------------+
//| Structure drawing                                                 |
//+------------------------------------------------------------------+
void AddSwing(Swing &arr[],const Swing &s){ int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=s; }

void DrawStructure(datetime t1,double p,datetime t2,bool mss,bool bull)
  {
   if(!InpShowStructure) return;
   color c=mss?InpMSSColor:InpBOSColor;
   Line(t1,p,t2,p,c,1,mss?STYLE_SOLID:STYLE_DASH,"STR");
   Text(t2,p,(mss?"MSS":"BOS"),c,bull?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER,7,"STT");
  }

//+------------------------------------------------------------------+
//| Main analysis                                                     |
//+------------------------------------------------------------------+
void Analyse()
  {
   ObjectsDeleteAll(0,PFX);
   ArrayFree(g_zones); ArrayFree(g_trades); ArrayFree(g_liq); ArrayFree(g_sh); ArrayFree(g_sl);
   g_trend=0; g_lastEvent="-"; g_lastEventTime=0; g_objId=0; g_legActive=false;

   ArraySetAsSeries(g_r,false);
   int total=CopyRates(_Symbol,_Period,0,InpLookback+1,g_r);
   if(total<InpSwingLen*2+30) return;
   g_n=total-1;
   g_atr=CalcATR(14); if(g_atr<=0) return;

   BuildDays();
   Rolling(InpTSPeriod,g_tsHH,g_tsLL);
   Rolling(InpDealBars,g_dHH,g_dLL);

   // --- Compute live filters used by signal gates ---
   // Weekly open (ICT M8-V1 Po3 bias: long above / short below)
   g_weekOpen=iOpen(_Symbol,PERIOD_W1,0);

   // CBDR size in pips for today (ICT M8-V3: must be < 40 pips; M8-V5: ideal 20-30)
   // Asian range size in pips for today (ICT M8-V5: 20-30 pips ideal for Judas gate)
   g_cbdrPips=0; g_asiaPips=0;
   int todayIdx=DayIdx(g_r[g_n].time);
   if(todayIdx>=0)
     {
      if(g_cOK[todayIdx] && g_cbdrPips==0)
         g_cbdrPips=(g_cHi[todayIdx]-g_cLo[todayIdx])/_Point/
                    ((_Digits==3||_Digits==5)?10:1);   // normalise to pips
      if(g_aOK[todayIdx] && g_asiaPips==0)
         g_asiaPips=(g_aHi[todayIdx]-g_aLo[todayIdx])/_Point/
                    ((_Digits==3||_Digits==5)?10:1);
     }

   bool isSH[],isSL[]; ArrayResize(isSH,g_n); ArrayResize(isSL,g_n);
   for(int i=0;i<g_n;i++){ isSH[i]=false; isSL[i]=false; }
   for(int i=InpSwingLen;i<g_n-InpSwingLen;i++)
     {
      bool sh=true,sl=true;
      for(int k=1;k<=InpSwingLen && (sh||sl);k++)
        {
         if(g_r[i].high<=g_r[i-k].high || g_r[i].high<g_r[i+k].high) sh=false;
         if(g_r[i].low >=g_r[i-k].low  || g_r[i].low >g_r[i+k].low ) sl=false;
        }
      isSH[i]=sh; isSL[i]=sl;
     }

   Swing lastSH,lastSL; bool hasSH=false,hasSL=false;
   int lastSweepLow=-1000,lastSweepHigh=-1000;

   for(int j=0;j<g_n;j++)
     {
      int p=j-InpSwingLen;
      if(p>=InpSwingLen)
        {
         if(isSH[p]){ lastSH.bar=p; lastSH.time=g_r[p].time; lastSH.price=g_r[p].high; lastSH.broken=false; hasSH=true; AddSwing(g_sh,lastSH); }
         if(isSL[p]){ lastSL.bar=p; lastSL.time=g_r[p].time; lastSL.price=g_r[p].low;  lastSL.broken=false; hasSL=true; AddSwing(g_sl,lastSL); }
        }

      // liquidity sweeps
      if(hasSL && !lastSL.broken && g_r[j].low<lastSL.price && g_r[j].close>lastSL.price)
        { lastSweepLow=j;  Text(g_r[j].time,g_r[j].low,"$",clrGold,ANCHOR_UPPER,8,"SW"); }
      if(hasSH && !lastSH.broken && g_r[j].high>lastSH.price && g_r[j].close<lastSH.price)
        { lastSweepHigh=j; Text(g_r[j].time,g_r[j].high,"$",clrGold,ANCHOR_LOWER,8,"SW"); }

      // structure
      if(hasSH && !lastSH.broken && g_r[j].close>lastSH.price)
        {
         bool mss=(g_trend!=1); lastSH.broken=true;
         DrawStructure(lastSH.time,lastSH.price,g_r[j].time,mss,true);
         g_trend=1; g_lastEvent=(mss?"MSS":"BOS")+" UP"; g_lastEventTime=g_r[j].time;
         ENUM_SETUP_TYPE t=(mss && j-lastSweepLow<=InpSweepWindow)?ST_SWEEP_MSS:ST_OB;
         int from=hasSL?lastSL.bar:MathMax(0,j-30);
         CreateOB(j,true,from,t);
         StartLeg(true,from,hasSL?lastSL.price:g_r[from].low,j);
        }
      if(hasSL && !lastSL.broken && g_r[j].close<lastSL.price)
        {
         bool mss=(g_trend!=-1); lastSL.broken=true;
         DrawStructure(lastSL.time,lastSL.price,g_r[j].time,mss,false);
         g_trend=-1; g_lastEvent=(mss?"MSS":"BOS")+" DOWN"; g_lastEventTime=g_r[j].time;
         ENUM_SETUP_TYPE t=(mss && j-lastSweepHigh<=InpSweepWindow)?ST_SWEEP_MSS:ST_OB;
         int from=hasSH?lastSH.bar:MathMax(0,j-30);
         CreateOB(j,false,from,t);
         StartLeg(false,from,hasSH?lastSH.price:g_r[from].high,j);
        }
      UpdateLeg(j);

      // FVG
      if(j>=2)
        {
         if(g_r[j].low>g_r[j-2].high && (g_r[j].low-g_r[j-2].high)>=InpMinFVGATR*g_atr) AddZone(ST_FVG,true,j-1,j,g_r[j-2].high,g_r[j].low);
         if(g_r[j].high<g_r[j-2].low && (g_r[j-2].low-g_r[j].high)>=InpMinFVGATR*g_atr) AddZone(ST_FVG,false,j-1,j,g_r[j].high,g_r[j-2].low);
        }

      UpdateZones(j);
      UpdateTrades(j);
      CheckSignals(j);
     }

   BuildLiquidity();
   ComputeBias();
   ComputeSMT();

   DrawKillZones();
   DrawPremiumDiscount();
   DrawSessions();
   DrawZones();
   DrawLiveOTE();
   DrawLiquidity();
   DrawPDHL();
   DrawIPDA();
   DrawTrades();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Alerts                                                            |
//+------------------------------------------------------------------+
void CheckAlerts()
  {
   if(!InpAlerts) return;
   int n=ArraySize(g_trades); if(n==0) return;
   Trade t=g_trades[n-1];
   if(t.barEntry!=g_n-1 || t.tEntry==g_lastAlertTime) return;
   g_lastAlertTime=t.tEntry;
   string msg=_Symbol+" "+TF()+" ICT "+(t.bull?"BUY ":"SELL ")+SetupName(t.type)+" E:"+P(t.entry)+" SL:"+P(t.sl)+" TP1:"+P(t.tp1)+" TP2:"+P(t.tp2);
   Alert(msg); if(InpPush) SendNotification(msg);
  }

//+------------------------------------------------------------------+
//| Dashboard                                                         |
//+------------------------------------------------------------------+
void CreateDash()
  {
   int lineH=InpFontSize+7; string bg=DPFX+"BG";
   ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,InpDashX); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,InpDashY);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,430); ObjectSetInteger(0,bg,OBJPROP_YSIZE,DASH_LINES*lineH+12);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,InpDashBg); ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,clrDimGray); ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   for(int i=0;i<DASH_LINES;i++)
     {
      string n=DPFX+"L"+IntegerToString(i);
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,InpDashX+8); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,InpDashY+6+i*lineH);
      ObjectSetString(0,n,OBJPROP_FONT,"Consolas"); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,InpFontSize);
      ObjectSetInteger(0,n,OBJPROP_COLOR,InpDashText);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
     }
  }

void SetLine(int i,string txt,color c)
  {
   if(i>=DASH_LINES) return;
   string n=DPFX+"L"+IntegerToString(i);
   ObjectSetString(0,n,OBJPROP_TEXT,txt); ObjectSetInteger(0,n,OBJPROP_COLOR,c);
  }

string Pad(string s,int w){ while(StringLen(s)<w) s+=" "; return s; }

void UpdateDash()
  {
   if(g_n==0) return;
   int L=0; double px=g_r[g_n].close;
   SetLine(L++,"ICT MENTORSHIP SUITE v2.10 | "+_Symbol+" "+TF()+" | "+DOW()+" "+TimeToString(TimeCurrent(),TIME_MINUTES),clrGold);

   SetLine(L++,"HTF bias   : "+((g_bias==1)?"BULLISH":(g_bias==-1)?"BEARISH":"NEUTRAL")+"  ("+g_biasEvent+")",(g_bias==1)?clrLime:(g_bias==-1)?clrRed:clrSilver);
   SetLine(L++,"LTF trend  : "+((g_trend==1)?"BULLISH":(g_trend==-1)?"BEARISH":"RANGE")+"  last "+g_lastEvent+" "+TimeToString(g_lastEventTime,TIME_DATE|TIME_MINUTES),(g_trend==1)?clrLime:(g_trend==-1)?clrRed:clrSilver);

   bool disc=(px<g_eq);
   SetLine(L++,"Dealing rng: "+P(g_dLo)+" - "+P(g_dHi)+"  EQ "+P(g_eq)+"  -> "+(disc?"DISCOUNT":"PREMIUM"),disc?clrMediumSeaGreen:clrIndianRed);

   if(g_legActive && MathAbs(g_legE-g_legO)>=InpMinLegATR*g_atr)
     { double f62,f705,f79; OTELevels(f62,f705,f79); SetLine(L++,"OTE leg    : "+(g_legBull?"BULL ":"BEAR ")+"62% "+P(f62)+"  70.5% "+P(f705)+"  79% "+P(f79)+(g_legUsed?"  (used)":""),InpOTEColor); }
   else SetLine(L++,"OTE leg    : none",clrSilver);

   int ob[2]={0,0},fvg[2]={0,0},brk[2]={0,0};
   for(int k=0;k<ArraySize(g_zones);k++)
     {
      if(g_zones[k].mitigated) continue; int d=g_zones[k].bull?0:1;
      if(g_zones[k].type==ST_OB||g_zones[k].type==ST_SWEEP_MSS) ob[d]++; else if(g_zones[k].type==ST_FVG) fvg[d]++; else if(g_zones[k].type==ST_BREAKER) brk[d]++;
     }
   SetLine(L++,"Zones +/-  : OB "+IntegerToString(ob[0])+"/"+IntegerToString(ob[1])+"  FVG "+IntegerToString(fvg[0])+"/"+IntegerToString(fvg[1])+"  BRK "+IntegerToString(brk[0])+"/"+IntegerToString(brk[1]),InpDashText);

   double up=0,dn=0;
   for(int i=0;i<ArraySize(g_liq);i++)
     {
      if(g_liq[i].swept) continue;
      if(g_liq[i].price>px && (up==0||g_liq[i].price<up)) up=g_liq[i].price;
      if(g_liq[i].price<px && (dn==0||g_liq[i].price>dn)) dn=g_liq[i].price;
     }
   SetLine(L++,"Liquidity  : above "+(up>0?P(up):"-")+"  below "+(dn>0?P(dn):"-"),InpLiqColor);
   SetLine(L++,"PDH/PDL    : "+P(g_pdh)+" / "+P(g_pdl)+"   PWH/PWL "+P(g_pwh)+" / "+P(g_pwl),clrAqua);
   SetLine(L++,"IPDA H     : 20 "+P(g_ipdaH[0])+"  40 "+P(g_ipdaH[1])+"  60 "+P(g_ipdaH[2]),clrDeepSkyBlue);
   SetLine(L++,"IPDA L     : 20 "+P(g_ipdaL[0])+"  40 "+P(g_ipdaL[1])+"  60 "+P(g_ipdaL[2]),clrDeepSkyBlue);

   // --- Weekly open bias (ICT M8-V1 Po3 / weekly directional filter) ---
   // Price above weekly open = bullish week context; below = bearish week context.
   if(g_weekOpen>0)
     {
      bool aboveWO=(px>=g_weekOpen);
      string woTxt="Week open  : "+P(g_weekOpen)+(aboveWO?" | price ABOVE (bullish week)":" | price BELOW (bearish week)");
      SetLine(L++,woTxt,aboveWO?clrLime:clrRed);
     }
   else SetLine(L++,"Week open  : -",clrSilver);

   int di=DayIdx(g_r[g_n].time); string ss="Asia -";
   if(di>=0)
     {
      // Asian range with pip size — ICT M8-V5: ideal 20-30 pips
      if(g_aOK[di])
        {
         double aPips=g_asiaPips>0?g_asiaPips:(g_aHi[di]-g_aLo[di])/_Point/((_Digits==3||_Digits==5)?10:1);
         string aFlag=(aPips>40)?" [WIDE - skip Judas]":(aPips<15)?" [NARROW]":"";
         ss="Asia "+P(g_aLo[di])+"-"+P(g_aHi[di])+" ("+DoubleToString(aPips,0)+"pip)"+aFlag;
        }
      // CBDR with pip size and >40pip warning — ICT M8-V3: must be <40, ideal 20-30
      if(g_cOK[di])
        {
         double cPips=g_cbdrPips>0?g_cbdrPips:(g_cHi[di]-g_cLo[di])/_Point/((_Digits==3||_Digits==5)?10:1);
         string cFlag=(cPips>=40)?" !! >40pip - SKIP London profiles !!":(cPips<10)?" [tiny]":"";
         ss+="  CBDR "+P(g_cLo[di])+"-"+P(g_cHi[di])+" ("+DoubleToString(cPips,0)+"pip)"+cFlag;
        }
     }
   // Sessions line: color orange when CBDR is too wide (ICT M8-V3 invalid day warning)
   color sessColor=(g_cbdrPips>=40)?clrOrange:InpAsiaColor;
   SetLine(L++,"Sessions   : "+ss,sessColor);

   int kz=KZIndex(TimeCurrent());
   if(kz>=0) SetLine(L++,"Kill zone  : "+g_kzName[kz]+"  (ACTIVE)",clrLime);
   else      SetLine(L++,"Kill zone  : none | next "+NextKZText(),clrSilver);
   SetLine(L++,"SMT        : "+g_smt,(StringFind(g_smt,"BULL")>=0)?clrLime:(StringFind(g_smt,"BEAR")>=0)?clrRed:clrSilver);

   int n=ArraySize(g_trades);
   if(n>0)
     {
      Trade t=g_trades[n-1];
      string st=(t.result==0)?(t.tp1Hit?"OPEN (TP1 done)":"OPEN"):(t.result==1)?"TP2 HIT":(t.result==2)?"BE after TP1":"SL HIT";
      SetLine(L++,"Last signal: "+(t.bull?"BUY ":"SELL ")+SetupName(t.type)+"  "+TimeToString(t.tEntry,TIME_DATE|TIME_MINUTES)+"  ["+st+"]",t.bull?clrLime:clrRed);
      SetLine(L++,"  E "+P(t.entry)+"  SL "+P(t.sl)+"  TP1 "+P(t.tp1)+"  TP2 "+P(t.tp2),InpDashText);
     }
   else { SetLine(L++,"Last signal: -",InpDashText); SetLine(L++,"",InpDashText); }

   SetLine(L++,Pad("Setup",13)+Pad("N",5)+Pad("W",5)+Pad("P",5)+Pad("L",5)+"WR%   (RR 1:"+DoubleToString(InpRR,1)+")",clrGold);
   int tN=0,tW=0,tP=0,tL=0;
   for(int s=ST_OB;s<=ST_JUDAS;s++)
     {
      int cN=0,cW=0,cP=0,cL=0;
      for(int i=0;i<n;i++)
        {
         if(g_trades[i].type!=s) continue; cN++;
         if(g_trades[i].result==1) cW++; else if(g_trades[i].result==2) cP++; else if(g_trades[i].result==-1) cL++;
        }
      tN+=cN; tW+=cW; tP+=cP; tL+=cL;
      double wr=(cW+cP+cL>0)?100.0*(cW+cP)/(cW+cP+cL):0;
      SetLine(L++,Pad(SetupName((ENUM_SETUP_TYPE)s),13)+Pad(IntegerToString(cN),5)+Pad(IntegerToString(cW),5)+Pad(IntegerToString(cP),5)+Pad(IntegerToString(cL),5)+DoubleToString(wr,0),SetupEnabled((ENUM_SETUP_TYPE)s)?InpDashText:clrDimGray);
     }
   double twr=(tW+tP+tL>0)?100.0*(tW+tP)/(tW+tP+tL):0;
   SetLine(L++,Pad("TOTAL",13)+Pad(IntegerToString(tN),5)+Pad(IntegerToString(tW),5)+Pad(IntegerToString(tP),5)+Pad(IntegerToString(tL),5)+DoubleToString(twr,0)+"   ATR "+P(g_atr),clrGold);
  }

//+------------------------------------------------------------------+
//| Handlers                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   string kzIn[4]; kzIn[0]=InpAsiaKZ; kzIn[1]=InpLondonKZ; kzIn[2]=InpNYKZ; kzIn[3]=InpLCKZ;
   for(int i=0;i<4;i++) if(!ParseSess(kzIn[i],g_kzS[i],g_kzE[i])){ g_kzS[i]=-1; g_kzE[i]=-1; }
   if(!ParseSess(InpCBDR,g_cbS,g_cbE)){ g_cbS=-1; g_cbE=-1; }
   g_dayOpenSec=ParseHM(InpDayOpen);
   if(InpSMTSymbol!="") SymbolSelect(InpSMTSymbol,true);
   if(InpShowDash) CreateDash();
   g_lastBarTime=0;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PFX); ObjectsDeleteAll(0,DPFX); ChartRedraw();
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   datetime bt=iTime(_Symbol,_Period,0);
   if(bt!=g_lastBarTime || prev_calculated==0)
     {
      g_lastBarTime=bt;
      Analyse();
      CheckAlerts();
     }
   if(InpShowDash) UpdateDash();
   return rates_total;
  }
//+------------------------------------------------------------------+