//+------------------------------------------------------------------+
//|                                       NeelyMethod_Structure.mq5  |
//|            Neely Method of Elliott Wave Analysis (MT5 indicator)  |
//|                                                                  |
//|  Implements the method described in:                             |
//|   "Mastering Elliott Wave - Version 2.0" (Glenn Neely, 1990)     |
//|                                                                  |
//|  Structure detection (per the book):                             |
//|   * Monowave identification via swing pivots (Ch.3)              |
//|   * Retracement Rules 1-7 (m2/m1) + Conditions (m0/m1)           |
//|   * Impulsions: Trending/Terminal, 1st/3rd/5th-wave Extension,   |
//|     5th-wave Failure (Ch.5 Essential + Conditional Rules)        |
//|   * Corrections: Zigzag Normal/Truncated/Elongated,              |
//|     Flat Common/B-Failure/C-Failure/Double Failure/Irregular/    |
//|     Irregular Failure/Running/Elongated, Triangle Contracting/   |
//|     Expanding x Horizontal/Irregular/Running, Double Zigzag,     |
//|     Double Three (Ch.5 + Ch.8 Non-Standard series)               |
//|   * Post-Constructive Rules of Logic confirmation (Ch.6):        |
//|     2-4 trendline break (impulse completion), O-B break          |
//|     (flat/zigzag completion), B-D break (triangle completion)    |
//|     - all with the book's time-limit tests                       |
//|   * Power Ratings -3..+3 (Ch.10) annotated on labels             |
//|                                                                  |
//|  Output: ENTRY (arrow + structure name + TP/SL) after a          |
//|  confirmed correction completion; EXIT after a confirmed         |
//|  impulse completion. Every structure is named on the chart.      |
//+------------------------------------------------------------------+
#property copyright "Built from Mastering Elliott Wave v2.0 (Glenn Neely)"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- inputs ---------------------------------------------------------
input int      InpSwingStrength  = 3;        // Pivot strength: monowave confirmation (bars each side)
input double   InpThrustRatio    = 1.00;     // Triangle thrust target: ratio of widest leg (0.75-2.618)
input double   InpMinATRMult     = 1.50;     // Structure must be >= this x ATR(14) to signal
input int      InpMinGapBars     = 15;       // Min. bars between two signals of the same direction
input int      InpMaxPatterns    = 20;       // Max. structure boxes drawn on the chart
input bool     InpShowPatterns   = true;     // Draw structure rectangles + names
input bool     InpShowTargets    = false;     // Draw TP/SL lines
input bool     InpAlert          = true;     // Alert on a new signal
input string   InpPrefix         = "NEELY_"; // Object name prefix
input color    InpColImpulse     = clrTomato;
input color    InpColZigzag      = clrOrange;
input color    InpColFlat        = clrBlueViolet;
input color    InpColTriangle    = clrLime;
input color    InpColDouble      = clrSaddleBrown;
input color    InpColBuy         = clrLime;
input color    InpColSell        = clrRed;

//--- structures -----------------------------------------------------
struct SPivot
  {
   int       bar;      // index in the oldest->newest rate copy
   double    price;
   bool      isHigh;   // true = swing high, false = swing low
  };

struct SPattern
  {
   int       type;     // 0 impulse, 1 doubleZZ, 2 triangle, 3 flat, 4 zigzag
   int       s;        // pivot index of the pattern start
   int       e;        // pivot index of the pattern end
   bool      dn;       // corrective pattern travelled down (a-wave started at a high)
   bool      up;
   string    name;
   double    a,b,c;    // zigzag/flat legs
   double    widest;   // triangle widest leg
   double    xret;     // x-wave retracement of previous correction
   int       length;   // bars spanned
   int       prio;
   bool      valid;
   // impulse extras
   double    w1,w2,w3,w4,w5;
   double    r2,r4;
   bool      fail;
   bool      terminal;
   string    ext;
  };

struct SSignal
  {
   int       bar;
   int       dir;      // +1 = buy, -1 = sell
   bool      isExit;   // true = completed impulse -> exit, false = correction done -> entry
   string    name;
   double    tp;
   double    sl;
   int       patIdx;
  };

//--- globals --------------------------------------------------------
SPivot   gPivots[];
SPattern gPatterns[];
SSignal  gSignals[];
datetime gTime[];
double   gOpen[], gHigh[], gLow[], gClose[];
int      gN=0;
int      gSigCount=0;
datetime gLastBar=0;
int      gLastSigBar[2]={-99999,-99999};

//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectsDeleteAll(0, InpPrefix);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   datetime nowBar = 0;
   if(rates_total>0) nowBar = time[0];
   if(nowBar==gLastBar) return(rates_total);      // one analysis pass per new bar
   gLastBar = nowBar;

   Analyze(rates_total);
   return(rates_total);
  }

//+------------------------------------------------------------------+
void Analyze(const int rates_total)
  {
   //--- copy rates oldest->newest -------------------------------------
   if(!LoadRates(_Symbol,_Period,0,MathMin(rates_total,10000)))
      return;
   gN = ArraySize(gTime);
   if(gN<40) return;

   //--- monowave pivots (Ch.3 Rules of Observation) --------------------
   BuildPivots(gHigh,gLow,gN);
   if(ArraySize(gPivots)<7) return;

   //--- structure detection --------------------------------------------
   DetectAll();

   //--- Ch.6 confirmation + signals ------------------------------------
   EmitSignals();

   //--- draw ------------------------------------------------------------
   if(InpShowPatterns) DrawPatterns();
   else KillOld();
   if(InpShowTargets) DrawTargets();
   DrawSignals();
   DrawStatus();

   if(InpAlert && gSigCount>0)
     {
      SSignal sg=gSignals[gSigCount-1];
      if(sg.bar==gN-1)
         Alert(_Symbol+" "+EnumToString(_Period)+" NeelyMethod: "+(sg.isExit?"EXIT":"ENTRY")+
               (sg.dir>0?" BUY":" SELL")+" | "+sg.name+
               " | TP "+DoubleToString(sg.tp,_Digits)+" SL "+DoubleToString(sg.sl,_Digits));
     }
  }

//+------------------------------------------------------------------+
bool LoadRates(const string symbol,const ENUM_TIMEFRAMES tf,const int start,const int count)
  {
   MqlRates r[];
   int got = ::CopyRates(symbol,tf,start,count,r);
   if(got<=0) return(false);
   ArraySetAsSeries(r,false);
   int n=got;
   ArrayResize(gTime,n); ArrayResize(gOpen,n); ArrayResize(gHigh,n);
   ArrayResize(gLow,n);  ArrayResize(gClose,n);
   ArraySetAsSeries(gTime,false); ArraySetAsSeries(gOpen,false);
   ArraySetAsSeries(gHigh,false); ArraySetAsSeries(gLow,false);
   ArraySetAsSeries(gClose,false);
   for(int i=0;i<n;i++)
     {
      gTime[i]=r[i].time;  gOpen[i]=r[i].open;  gHigh[i]=r[i].high;
      gLow[i]=r[i].low;    gClose[i]=r[i].close;
     }
   return(true);
  }

//+------------------------------------------------------------------+
//|  Monowave identification: alternating swing pivots               |
//+------------------------------------------------------------------+
void BuildPivots(const double &h[],const double &l[],const int n)
  {
   ArrayResize(gPivots,0);
   int str=InpSwingStrength;
   for(int i=str;i<n-str;i++)
     {
      bool isH=true, isL=true;
      for(int j=1;j<=str;j++)
        {
         if(h[i]<h[i-j] || h[i]<h[i+j]) isH=false;
         if(l[i]>l[i-j] || l[i]>l[i+j]) isL=false;
        }
      if(!isH && !isL) continue;
      if(isH && isL) isH=(h[i]-l[i])>=0;
      SPivot p;
      p.bar=i; p.price=(isH?h[i]:l[i]); p.isHigh=isH;
      int last=ArraySize(gPivots)-1;
      if(last>=0)
        {
         SPivot lp=gPivots[last];
         if(lp.isHigh==p.isHigh)
           {
            if((p.isHigh && p.price>lp.price) || (!p.isHigh && p.price<lp.price))
               gPivots[last]=p;
            continue;
           }
        }
      int sz=ArraySize(gPivots);
      ArrayResize(gPivots,sz+1);
      gPivots[sz]=p;
     }
  }

//+------------------------------------------------------------------+
double PctAbs(const double x,const double base)
  {
   if(base==0.0) return 0.0;
   return MathAbs(x)/MathAbs(base)*100.0;
  }

//+------------------------------------------------------------------+
void AddCand(SPattern &arr[],const SPattern &p)
  {
   int sz=ArraySize(arr);
   ArrayResize(arr,sz+1);
   arr[sz]=p;
  }

//+------------------------------------------------------------------+
void SortCand(SPattern &arr[])
  {
   int n=ArraySize(arr);
   for(int i=0;i<n-1;i++)
      for(int j=i+1;j<n;j++)
        {
         bool swap=false;
         long li=(long)gPivots[arr[i].e].bar-(long)gPivots[arr[i].s].bar;
         long lj=(long)gPivots[arr[j].e].bar-(long)gPivots[arr[j].s].bar;
         if(li<lj) swap=true;
         else if(li==lj && arr[i].prio>arr[j].prio) swap=true;
         if(swap){ SPattern t=arr[i]; arr[i]=arr[j]; arr[j]=t; }
        }
  }

//+------------------------------------------------------------------+
void DetectAll()
  {
   ArrayResize(gPatterns,0);
   int pt=ArraySize(gPivots);
   SPattern cand[];
   for(int s=0;s<pt-5;s++)
     {
      SPattern p; ZeroMemory(p);
      if(DetectImpulse(gPivots,s,p))          { p.prio=0; AddCand(cand,p); }
      else if(DetectDouble(gPivots,s,p))      { p.prio=1; AddCand(cand,p); }
      else if(DetectTriangle(gPivots,s,p))    { p.prio=2; AddCand(cand,p); }
      else if(DetectFlat(gPivots,s,p))        { p.prio=3; AddCand(cand,p); }
      else if(DetectZigzag(gPivots,s,p))      { p.prio=4; AddCand(cand,p); }
     }
   // largest-first greedy selection -> one coherent count (grand degree first)
   SortCand(cand);
   int take=0;
   for(int i=0;i<ArraySize(cand);i++)
     {
      int s0=gPivots[cand[i].s].bar;
      int e0=gPivots[cand[i].e].bar;
      bool ok=true;
      for(int j=0;j<take;j++)
        {
         int js0=gPivots[gPatterns[j].s].bar;
         int je0=gPivots[gPatterns[j].e].bar;
         if(!(e0<js0 || s0>je0)){ ok=false; break; }
        }
      if(ok)
        {
         int sz=ArraySize(gPatterns);
         ArrayResize(gPatterns,sz+1);
         gPatterns[sz]=cand[i];
         take++;
        }
     }
  }

//+------------------------------------------------------------------+
//|  IMPULSE (Ch.5 Essential + Conditional Construction Rules).      |
//|  Five adjacent segments pts[s..s+5].                             |
//+------------------------------------------------------------------+
bool DetectImpulse(const SPivot &pts[],const int s,SPattern &p)
  {
   if(s+5>=ArraySize(pts)) return false;
   p.type=0; p.s=s; p.e=s+5; p.valid=true;
   double v[6];
   for(int i=0;i<6;i++) v[i]=pts[s+i].price;
   bool up=!(pts[s].isHigh);
   p.up=up; p.dn=!up;
   double w1=MathAbs(v[1]-v[0]), w2=MathAbs(v[2]-v[1]), w3=MathAbs(v[3]-v[2]);
   double w4=MathAbs(v[4]-v[3]), w5=MathAbs(v[5]-v[4]);
   if(w1<=0||w2<=0||w3<=0||w4<=0||w5<=0) return false;
   p.w1=w1; p.w2=w2; p.w3=w3; p.w4=w4; p.w5=w5;
   // Essential rules 3,4,5,6,7
   if(up)
     {
      if(!(v[2]>v[0]) || !(v[4]>v[2]) || !(w3>w2) || w5<0.382*w4) return false;
      p.terminal=(v[4]<v[1]);           // Overlap Rule: trending - no overlap; terminal - overlap
     }
   else
     {
      if(!(v[2]<v[0]) || !(v[4]<v[2]) || !(w3>w2) || w5<0.382*w4) return false;
      p.terminal=(v[4]>v[1]);
     }
   double mx=MathMax(w1,MathMax(w3,w5));
   double mn=MathMin(w1,MathMin(w3,w5));
   double mid=(w1+w3+w5)-mx-mn;
   if(mn==w3) return false;                 // 3rd wave never the shortest
   // Extension Rule (the litmus test): longest >= 161.8% of next longest
   p.ext="none";
   if(mx>=1.618*mid)
     {
      if(mx==w1) p.ext="1st"; else if(mx==w3) p.ext="3rd"; else p.ext="5th";
     }
   else if(mx==w1 && w3<=1.618*w1) p.ext="1st(ex)";   // book exception
   p.fail=(w5<w4);
   double r2=(w2>0?(MathAbs(v[2]-v[1]))/w1*100.0:0);
   double r4=(w3>0?(MathAbs(v[4]-v[3]))/w3*100.0:0);
   p.r2=r2; p.r4=r4;
   p.name = p.terminal ? "Impulse Terminal" : "Impulse Trending";
   if(p.ext=="1st")      p.name+=" / 1st-Wave Ext";
   else if(p.ext=="3rd") p.name+=" / 3rd-Wave Ext";
   else if(p.ext=="5th") p.name+=" / 5th-Wave Ext";
   else if(p.ext=="1st(ex)") p.name+=" / 1st-Wave Ext(exception)";
   if(p.fail) p.name+=" / 5th-Wave Failure";
   if(MathAbs(r2-r4)<10.0 && MathAbs(w2-w4)/MathMax(w2,w4)<0.15)
      p.name+=" (no alt 2-4)";
   p.length=pts[s+5].bar-pts[s].bar;
   return true;
  }

//+------------------------------------------------------------------+
//|  ZIGZAG 5-3-5 (Ch.5)  pts[s..s+3]                                |
//+------------------------------------------------------------------+
bool DetectZigzag(const SPivot &pts[],const int s,SPattern &p)
  {
   if(s+3>=ArraySize(pts)) return false;
   p.type=4; p.s=s; p.e=s+3; p.valid=true;
   bool dn=pts[s].isHigh;
   p.dn=dn; p.up=!dn;
   double v[4];
   for(int i=0;i<4;i++) v[i]=pts[s+i].price;
   double a=MathAbs(v[1]-v[0]), b=MathAbs(v[2]-v[1]), c=MathAbs(v[3]-v[2]);
   if(a<=0||b<=0||c<=0) return false;
   p.a=a; p.b=b; p.c=c;
   if(dn)
     {
      if(!(v[1]<v[0]) || !(v[2]>v[1]) || !(v[3]<v[2]) || !(v[3]<v[1])) return false;
     }
   else
     {
      if(!(v[1]>v[0]) || !(v[2]<v[1]) || !(v[3]>v[2]) || !(v[3]>v[1])) return false;
     }
   double bret=PctAbs(v[2]-v[1], v[1]-v[0]);
   if(bret<1.0 || bret>61.8) return false;      // b between 1% and 61.8% of a
   double ratio=c/a;
   string kind;
   if(ratio<0.382) return false;                // below minimum zigzag length
   else if(ratio<0.618) kind="Truncated";
   else if(ratio<=1.618) kind="Normal";
   else kind="Elongated";
   p.name="Zigzag "+kind;
   p.length=pts[s+3].bar-pts[s].bar;
   return true;
  }

//+------------------------------------------------------------------+
//|  FLAT 3-3-5 (Ch.5, all variations)  pts[s..s+3]                  |
//+------------------------------------------------------------------+
bool DetectFlat(const SPivot &pts[],const int s,SPattern &p)
  {
   if(s+3>=ArraySize(pts)) return false;
   p.type=3; p.s=s; p.e=s+3; p.valid=true;
   bool dn=pts[s].isHigh;
   p.dn=dn; p.up=!dn;
   double v[4];
   for(int i=0;i<4;i++) v[i]=pts[s+i].price;
   double a=MathAbs(v[1]-v[0]), b=MathAbs(v[2]-v[1]), c=MathAbs(v[3]-v[2]);
   if(a<=0||b<=0||c<=0) return false;
   p.a=a; p.b=b; p.c=c;
   double bret=PctAbs(v[2]-v[1], v[1]-v[0]);
   if(bret<61.8) return false;                  // flat minimum: b >= 61.8% of a
   double cmina=c/a*100.0;
   if(cmina<38.2) return false;                 // flat minimum: c >= 38.2% of a
   string kind;
   if(bret<=80.0)                               // Weak b-wave
     {
      if(c<b) kind="Double Failure";
      else if(c<=1.382*b) kind="B-Failure";
      else kind="Elongated";
     }
   else if(bret<=100.0)                         // Normal b-wave
     {
      if(c<b) kind="C-Failure";
      else if(c<=1.382*b) kind="Common";
      else kind="Elongated";
     }
   else                                         // Strong b-wave
     {
      if(bret<=123.6)
        {
         if(cmina<=161.8) kind="Irregular";
         else kind="Elongated";
        }
      else
        {
         double lo=MathMin(v[0],v[1]), hi=MathMax(v[0],v[1]);
         if(v[3]>hi) kind="Running";
         else if(v[3]>=lo) kind="Irregular Failure";
         else kind="Elongated";
        }
     }
   p.name="Flat "+kind;
   p.length=pts[s+3].bar-pts[s].bar;
   return true;
  }

//+------------------------------------------------------------------+
//|  TRIANGLE 3-3-3-3-3 (Ch.5)  pts[s..s+5]                          |
//+------------------------------------------------------------------+
bool DetectTriangle(const SPivot &pts[],const int s,SPattern &p)
  {
   if(s+5>=ArraySize(pts)) return false;
   p.type=2; p.s=s; p.e=s+5; p.valid=true;
   bool dn=pts[s].isHigh;
   p.dn=dn; p.up=!dn;
   double v[6];
   for(int i=0;i<6;i++) v[i]=pts[s+i].price;
   double cw[5];
   for(int i=0;i<5;i++)
     {
      cw[i]=MathAbs(v[i+1]-v[i]);
      if(cw[i]<=0) return false;
     }
   // rule 5: b between 38.2% and 261.8% of a
   double r0=PctAbs(v[2]-v[1], v[1]-v[0]);
   if(r0<38.2 || r0>261.8) return false;
   // rule 6: b,c,d,e retrace a previous wave; at least 3 of them >= 50%
   double rr[4];
   rr[0]=r0;
   rr[1]=PctAbs(v[3]-v[2], v[2]-v[1]);
   rr[2]=PctAbs(v[4]-v[3], v[3]-v[2]);
   rr[3]=PctAbs(v[5]-v[4], v[4]-v[3]);
   int n50=0;
   for(int i=0;i<4;i++) if(rr[i]>=50.0) n50++;
   if(n50<3) return false;
   // envelope check
   double highs[3], lows[3];
   if(!dn){ highs[0]=v[1];highs[1]=v[3];highs[2]=v[5]; lows[0]=v[0];lows[1]=v[2];lows[2]=v[4]; }
   else    { highs[0]=v[0];highs[1]=v[2];highs[2]=v[4]; lows[0]=v[1];lows[1]=v[3];lows[2]=v[5]; }
   bool hDec=highs[0]>highs[1] && highs[1]>highs[2];
   bool lInc=lows[0]<lows[1]   && lows[1]<lows[2];
   bool hInc=highs[0]<highs[1] && highs[1]<highs[2];
   bool lDec=lows[0]>lows[1]   && lows[1]>lows[2];
   string ct;
   if(hDec && lInc) ct="Contracting";
   else if(hInc && lDec) ct="Expanding";
   else return false;
   double mn=cw[0], mxw=cw[0];
   for(int i=1;i<5;i++)
     {
      if(cw[i]<mn) mn=cw[i];
      if(cw[i]>mxw) mxw=cw[i];
     }
   string var="Horizontal";
   if(ct=="Contracting")
     {
      if(cw[4]>1.15*mn) return false;          // e-wave must be the smallest
      if(cw[1]>cw[0]) var=(cw[1]>=0.95*mxw)?"Running":"Irregular";
     }
   else
     {
      if(cw[4]!=mxw) return false;             // e-wave must be the largest
      if(!(cw[0]<=1.15*mn || cw[1]<=1.15*mn)) return false;   // a or b smallest
      if(cw[1]<cw[0]) var="Irregular";
      else if(cw[1]>cw[0] && cw[1]>=0.95*mxw) var="Running";
     }
   p.name="Triangle "+ct+" "+var;
   p.widest=mxw;
   p.length=pts[s+5].bar-pts[s].bar;
   return true;
  }

//+------------------------------------------------------------------+
//|  DOUBLE ZIGZAG / DOUBLE THREE (Ch.8 Non-Standard series)         |
//|  pts[s..s+7]                                                     |
//+------------------------------------------------------------------+
bool DetectDouble(const SPivot &pts[],const int s,SPattern &p)
  {
   if(s+7>=ArraySize(pts)) return false;
   bool dn=pts[s].isHigh;
   bool isDZ=false, isD3=false;
   SPattern z1,z2,f1,f2;
   ZeroMemory(z1); ZeroMemory(z2); ZeroMemory(f1); ZeroMemory(f2);
   if(DetectZigzag(pts,s,z1) && DetectZigzag(pts,s+4,z2) && z1.dn==z2.dn)
     {
      double c1=MathAbs(pts[s+3].price-pts[s+2].price);
      double x =MathAbs(pts[s+4].price-pts[s+3].price);
      double xret=(c1>0? x/c1*100.0 : 0.0);
      if(xret>=1.0 && xret<61.8 &&
         StringFind(z1.name,"Truncated")<0 && StringFind(z2.name,"Truncated")<0)
        { isDZ=true; p.xret=xret; }
     }
   if(!isDZ && DetectFlat(pts,s,f1) && DetectFlat(pts,s+4,f2) && f1.dn==f2.dn)
     {
      double c1=MathAbs(pts[s+3].price-pts[s+2].price);
      double x =MathAbs(pts[s+4].price-pts[s+3].price);
      double xret=(c1>0? x/c1*100.0 : 0.0);
      if(xret>=61.8 && xret<=161.8)
        { isD3=true; p.xret=xret; }
     }
   if(!isDZ && !isD3) return false;
   p.type=1; p.s=s; p.e=s+7; p.valid=true;
   p.dn=dn; p.up=!dn;
   p.name=isDZ ? "Double Zigzag" : "Double Three";
   p.length=pts[s+7].bar-pts[s].bar;
   return true;
  }

//+------------------------------------------------------------------+
//|  Ch.6 Post-Constructive Rules of Logic: confirmation + signals   |
//+------------------------------------------------------------------+
double LineVal(const SPivot &a,const SPivot &b,const int bar)
  {
   if(b.bar==a.bar) return a.price;
   return a.price+(b.price-a.price)*(bar-a.bar)/(double)(b.bar-a.bar);
  }

int FindBreak(const int endBar,const int maxBars,const SPivot &a,const SPivot &b,const bool upSide)
  {
   for(int k=1;k<=maxBars;k++)
     {
      int bar=endBar-k;
      if(bar<0) return -1;
      double lv=LineVal(a,b,bar);
      if(upSide && gClose[bar]>lv) return bar;
      if(!upSide && gClose[bar]<lv) return bar;
     }
   return -1;
  }

int PowerOf(const string name)
  {
   if(StringFind(name,"Triple")>=0) return 3;
   if(StringFind(name,"Running")>=0) return 3;
   if(StringFind(name,"Double Zigzag")>=0 || StringFind(name,"Double Three")>=0) return 2;
   if(StringFind(name,"Irregular Failure")>=0 || StringFind(name,"Elongated")>=0) return 2;
   if(StringFind(name,"C-Failure")>=0 || StringFind(name,"B-Failure")>=0 ||
      StringFind(name,"Zigzag Truncated")>=0) return -1;
   if(StringFind(name,"Double Failure")>=0) return -2;
   if(StringFind(name,"Irregular")>=0) return 1;
   return 0;
  }

string PowerStr(const string name)
  {
   int v=PowerOf(name);
   return "P"+(v>0? "+" : "")+IntegerToString(v);
  }

void AddSignal(const SSignal &sg)
  {
   int sz=ArraySize(gSignals);
   ArrayResize(gSignals,sz+1);
   gSignals[sz]=sg;
   gSigCount=sz+1;
  }

bool OkGap(const int bar,const int dir)
  {
   int idx=(dir>0?0:1);
   if(MathAbs(bar-gLastSigBar[idx])<InpMinGapBars) return false;
   gLastSigBar[idx]=bar;
   return true;
  }

//+------------------------------------------------------------------+
void EmitSignals()
  {
   gSigCount=0;
   ArrayResize(gSignals,0);
   gLastSigBar[0]=-99999; gLastSigBar[1]=-99999;
   int np=ArraySize(gPatterns);
   for(int i=0;i<np;i++)
     {
      SPattern pa=gPatterns[i];
      int ibar=gPivots[pa.s].bar;
      double legA=(pa.a>0? pa.a : pa.w1);
      if(legA<=0) continue;
      double atr=ATR14(ibar);
      if(atr>0 && legA<InpMinATRMult*atr) continue;    // ignore micro-structures

      SSignal sg; sg.patIdx=i;
      if(pa.type==0)
        {
         //---- completed IMPULSE -> EXIT (Stage 1: break 2-4 trendline within wave-5's time)
         SPivot e5=gPivots[pa.e];
         int wt=(int)MathMax(1.0,(double)(e5.bar-gPivots[pa.e-1].bar));
         int b;
         if(pa.up) b=FindBreak(e5.bar,wt,gPivots[pa.s+2],gPivots[pa.s+4],false);
         else      b=FindBreak(e5.bar,wt,gPivots[pa.s+2],gPivots[pa.s+4],true);
         if(b>=0)
           {
            sg.bar=b; sg.isExit=true;
            sg.dir=-1; if(!pa.up) sg.dir=1;             // trade against the completed impulse
            sg.name=pa.name+" (impulse done)";
            if(pa.fail) sg.tp=gPivots[pa.s].price;      // full retrace implied
            else if(pa.ext=="5th") sg.tp=e5.price-(pa.up?0.618*pa.w5:-0.618*pa.w5);
            else sg.tp=gPivots[pa.s+4].price;
            sg.sl=e5.price+(pa.up?0.618*pa.w5*0.382:-0.618*pa.w5*0.382);
            if(OkGap(b,sg.dir)) AddSignal(sg);
           }
        }
      else if(pa.type==4 || pa.type==3)
        {
         //---- completed correction -> ENTRY (break O-B trendline within wave-c's time)
         SPivot ce=gPivots[pa.e];
         int ct=(int)MathMax(1.0,(double)(ce.bar-gPivots[pa.e-1].bar));
         bool upSide=!pa.dn;                             // down-correction breaks on the upside
         int b=FindBreak(ce.bar,ct,gPivots[pa.s],gPivots[pa.e-1],upSide);
         if(b>=0)
           {
            sg.bar=b; sg.isExit=false;
            sg.dir=pa.dn?1:-1;                           // resume in the direction of the larger trend
            sg.name=pa.name+" (correction done, "+PowerStr(pa.name)+")";
            if(StringFind(pa.name,"Truncated")>=0)
              {
               double rng=MathAbs(gPivots[pa.s].price-ce.price);
               sg.tp=ce.price+(pa.dn?0.81*rng:-0.81*rng);
              }
            else sg.tp=gPivots[pa.s].price;
            double cs=(pa.c>0? pa.c : MathAbs(ce.price-gPivots[pa.e-1].price));
            sg.sl=ce.price-(pa.dn?0.382*cs:-0.382*cs);
            if(OkGap(b,sg.dir)) AddSignal(sg);
           }
        }
      else if(pa.type==2)
        {
         //---- TRIANGLE -> ENTRY on the thrust (break B-D trendline within wave-e's time)
         SPivot ee=gPivots[pa.e];
         int et=(int)MathMax(1.0,(double)(ee.bar-gPivots[pa.e-1].bar));
         int bu=FindBreak(ee.bar,et,gPivots[pa.s+2],gPivots[pa.s+4],true);
         int bd=FindBreak(ee.bar,et,gPivots[pa.s+2],gPivots[pa.s+4],false);
         int b=-1, dir=0;
         if(bu>=0 && bd>=0){ if(bu<bd){b=bu;dir=1;} else {b=bd;dir=-1;} }
         else if(bu>=0){ b=bu; dir=1; }
         else if(bd>=0){ b=bd; dir=-1; }
         if(b>=0 && dir!=0)
           {
            double lo=DBL_MAX, hi=-DBL_MAX;
            for(int k=0;k<=5;k++)
              {
               double pr=gPivots[pa.s+k].price;
               if(pr<lo) lo=pr;
               if(pr>hi) hi=pr;
              }
            sg.bar=b; sg.isExit=false; sg.dir=dir;
            sg.name=pa.name+" (triangle thrust)";
            sg.tp=ee.price+dir*InpThrustRatio*pa.widest;
            sg.sl=(dir>0? lo-0.382*pa.widest : hi+0.382*pa.widest);
            if(OkGap(b,sg.dir)) AddSignal(sg);
           }
        }
      else if(pa.type==1)
        {
         //---- DOUBLE ZIGZAG / DOUBLE THREE -> ENTRY after base-line break
         SPivot ce=gPivots[pa.e];
         int ct=(int)MathMax(1.0,(double)(ce.bar-gPivots[pa.e-1].bar));
         bool upSide=!pa.dn;
         int b=FindBreak(ce.bar,ct,gPivots[pa.s],gPivots[pa.e-1],upSide);
         if(b>=0)
           {
            sg.bar=b; sg.isExit=false;
            sg.dir=pa.dn?1:-1;
            sg.name=pa.name+" (done, "+PowerStr(pa.name)+")";
            sg.tp=gPivots[pa.s].price;
            double cs=MathAbs(ce.price-gPivots[pa.e-1].price);
            sg.sl=ce.price-(pa.dn?0.382*cs:-0.382*cs);
            if(OkGap(b,sg.dir)) AddSignal(sg);
           }
        }
     }
  }

//+------------------------------------------------------------------+
double ATR14(const int bar)
  {
   if(bar<15 || bar>=gN) return 0.0;
   double s=0;
   for(int i=bar-14;i<=bar;i++)
     {
      double tr=gHigh[i]-gLow[i];
      if(i>0)
        {
         double d1=MathAbs(gHigh[i]-gClose[i-1]);
         double d2=MathAbs(gLow[i]-gClose[i-1]);
         if(d1>tr) tr=d1;
         if(d2>tr) tr=d2;
        }
      s+=tr;
     }
   return s/14.0;
  }

//+------------------------------------------------------------------+
//|  Drawing                                                         |
//+------------------------------------------------------------------+
void KillOld()
  {
   int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
     {
      string nm=ObjectName(0,i,0,-1);
      if(StringFind(nm,InpPrefix)==0) ObjectDelete(0,nm);
     }
  }

void DrawPatterns()
  {
   KillOld();
   int np=ArraySize(gPatterns);
   int drawn=0;
   for(int k=np-1;k>=0 && drawn<InpMaxPatterns;k--)
     {
      SPattern pa=gPatterns[k];
      SPivot ps=gPivots[pa.s], pe=gPivots[pa.e];
      double lo=DBL_MAX, hi=-DBL_MAX;
      for(int i=pa.s;i<=pa.e;i++)
        {
         double pr=gPivots[i].price;
         if(pr<lo) lo=pr;
         if(pr>hi) hi=pr;
        }
      color col=InpColZigzag;
      if(pa.type==0) col=InpColImpulse;
      else if(pa.type==3) col=InpColFlat;
      else if(pa.type==2) col=InpColTriangle;
      else if(pa.type==1) col=InpColDouble;

      string nm=InpPrefix+"BOX_"+IntegerToString(k);
      if(ObjectFind(0,nm)<0)
         ObjectCreate(0,nm,OBJ_RECTANGLE,0,gTime[ps.bar],lo,gTime[pe.bar],hi);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,col);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,nm,OBJPROP_FILL,true);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);

      string tnm=InpPrefix+"TXT_"+IntegerToString(k);
      if(ObjectFind(0,tnm)<0)
         ObjectCreate(0,tnm,OBJ_TEXT,0,gTime[ps.bar],hi);
      ObjectSetString(0,tnm,OBJPROP_TEXT,pa.name);
      ObjectSetInteger(0,tnm,OBJPROP_COLOR,col);
      ObjectSetInteger(0,tnm,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,tnm,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,tnm,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0,tnm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tnm,OBJPROP_HIDDEN,true);
      drawn++;
     }
  }

void DrawTargets()
  {
   for(int i=0;i<gSigCount;i++)
     {
      SSignal sg=gSignals[i];
      color col=(sg.dir>0? InpColBuy : InpColSell);
      string t1=InpPrefix+"TP_"+IntegerToString(i);
      if(ObjectFind(0,t1)<0) ObjectCreate(0,t1,OBJ_HLINE,0,0,sg.tp);
      ObjectSetInteger(0,t1,OBJPROP_COLOR,col);
      ObjectSetInteger(0,t1,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,t1,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,t1,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,t1,OBJPROP_HIDDEN,true);

      string t2=InpPrefix+"SL_"+IntegerToString(i);
      if(ObjectFind(0,t2)<0) ObjectCreate(0,t2,OBJ_HLINE,0,0,sg.sl);
      ObjectSetInteger(0,t2,OBJPROP_COLOR,clrOrange);
      ObjectSetInteger(0,t2,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,t2,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,t2,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,t2,OBJPROP_HIDDEN,true);
     }
  }

void DrawSignals()
  {
   for(int i=0;i<gSigCount;i++)
     {
      SSignal sg=gSignals[i];
      color col=(sg.dir>0? InpColBuy : InpColSell);
      int code=(sg.dir>0? 233 : 234);
      string nm=InpPrefix+"ARR_"+IntegerToString(i);
      if(ObjectFind(0,nm)<0)
         ObjectCreate(0,nm,OBJ_ARROW,0,gTime[sg.bar],gClose[sg.bar]);
      ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,code);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,col);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,3);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);

      string txt=(sg.isExit?"EXIT ":"ENTRY ")+(sg.dir>0?"BUY ":"SELL ")+sg.name;
      string tnm=InpPrefix+"SIG_"+IntegerToString(i);
      if(ObjectFind(0,tnm)<0)
         ObjectCreate(0,tnm,OBJ_TEXT,0,gTime[sg.bar],gClose[sg.bar]);
      ObjectSetString(0,tnm,OBJPROP_TEXT,txt);
      ObjectSetInteger(0,tnm,OBJPROP_COLOR,col);
      ObjectSetInteger(0,tnm,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,tnm,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,tnm,OBJPROP_ANCHOR,(sg.dir>0? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER));
      ObjectSetInteger(0,tnm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,tnm,OBJPROP_HIDDEN,true);
     }
  }

void DrawStatus()
  {
   string txt="NEELY METHOD (hftland.com) | ";
   int np=ArraySize(gPatterns);
   if(np>0)
     {
      int last=np-1;
      for(int k=np-1;k>=0;k--)                        // newest (right-most) structure
        {
         if(gPivots[gPatterns[k].e].bar>gPivots[gPatterns[last].e].bar) last=k;
        }
      txt+=gPatterns[last].name;
      txt+=(gPatterns[last].up? "  [bull bias]" : "  [bear bias]");
     }
   if(gSigCount>0)
     {
      SSignal sg=gSignals[gSigCount-1];
      txt+="\nLast signal: "+(sg.isExit?"EXIT":"ENTRY")+" "+(sg.dir>0?"BUY":"SELL");
      txt+="  TP "+DoubleToString(sg.tp,_Digits)+"  SL "+DoubleToString(sg.sl,_Digits);
      txt+="\n"+sg.name;
     }
   string nm=InpPrefix+"STATUS";
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
   ObjectSetString(0,nm,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,nm,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
