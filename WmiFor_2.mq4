#property copyright "Copyright © 2023, Salavat"
#property link      ""

#property indicator_chart_window
#property indicator_buffers 6

#property indicator_style1 STYLE_DOT
#property indicator_width1 1
#property indicator_color1 Sienna

#property indicator_style2 STYLE_DOT
#property indicator_width2 1
#property indicator_color2 Sienna

#property indicator_style3 STYLE_SOLID
#property indicator_width3 2
#property indicator_color3 DodgerBlue

#property indicator_style4 STYLE_SOLID
#property indicator_width4 2
#property indicator_color4 DodgerBlue

#property indicator_style5 STYLE_SOLID
#property indicator_width5 1
#property indicator_color5 DodgerBlue

#property indicator_style6 STYLE_SOLID
#property indicator_width6 1
#property indicator_color6 DodgerBlue

#include <stdlib.mqh>
#include <stderror.mqh>

#define DOUBLEMAX  1000000.0
#define DOUBLEMIN -1000000.0

// Внешние переменные

extern bool IsTopCorner = true; // Информационный блок в верхнем углу?
extern int Offset = 1; // Смещение исходного образца в барах (для проверки надежности прогноза) [1..]
extern bool IsOffsetStartFixed = true; // Фиксировано ли начало образца
extern bool IsOffsetEndFixed = false; // Фиксирован ли конец образца
extern int PastBars = 24; // Размер образца в барах, который ищется на истории [3..]
extern int ForecastBars = 24; // На сколько баров вперед делать прогноз [1..]
extern int MaxAlts = 5; // Искать указанное кол-во лучших образцов [1..100]
extern bool ShowCloud = true; // Показывать ли облако
extern bool ShowBestPattern = true; // Показывать ли максимально близкий образец
extern bool IsExactTime = true; // Должно ли совпадать время образцов (для учета эффекта сессий)
extern datetime MinDate = D'01.01.2001'; // Минимальная дата образца
extern int PeriodMA = 2; // Периуд сглаженной средней
extern double ScalePercents = 90.0; // Рассматривать только образцы с этим минимальным процентом совпадения
extern color IndicatorCloudColor = Sienna; // Цвет облака похожих вариантов
extern color IndicatorBestPatternColor = DodgerBlue; // Цвет самого похожего образца
extern color IndicatorVLinesColor = Sienna; // Цвет вертикальных линий-границ образца
extern color IndicatorTextColor = MediumBlue; // Цвет текста инф.блока
extern color IndicatorTextWarningColor = Tomato; // Цвет предупреждений в тестовом инф.блоке
extern int XCorner = 5; // Отступ инф.блока индикатора от правой границы графика
extern int YCorner = 5; // Отступ инф.блока индикатора от верхней границы графика
extern string FontName = "Arial"; // Шрифт тестового инф.блока
extern int FontSize = 7; // Размер шрифта тестового инф.блока

// Глобальные переменные

string IndicatorName = "WmiFor";
string IndicatorVersion = "2.2";
string IndicatorAuthor = "Мурад Исмайлов (wmlab@hotmail.com)";
datetime OffsetStart, OffsetEnd;
bool IsRedraw;
datetime LastRedraw;
double ForecastCloudHigh[];
double ForecastCloudLow[];
double ForecastBestPatternOpen[];
double ForecastBestPatternClose[];
double ForecastBestPatternHigh[];
double ForecastBestPatternLow[];

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+

int init()
{
   if (Offset < 1)
   {
      Offset = 1;
   }
  
   if (PastBars < 3)
   {
      PastBars = 3;
   }  
  
   if (ForecastBars < 1)
   {
      ForecastBars = 1;
   }

   if (MaxAlts < 1)
   {
      MaxAlts = 1;
   }
   else
   {
      if (MaxAlts > 100)
      {
         MaxAlts = 100;
      }
   }

   SetIndexBuffer(0, ForecastCloudHigh);
   SetIndexStyle(0, DRAW_HISTOGRAM, EMPTY, EMPTY, IndicatorCloudColor);
   SetIndexShift(0, ForecastBars - Offset);
  
   SetIndexBuffer(1, ForecastCloudLow);
   SetIndexStyle(1, DRAW_HISTOGRAM, EMPTY, EMPTY, IndicatorCloudColor);
   SetIndexShift(1, ForecastBars - Offset);
  
   SetIndexBuffer(2, ForecastBestPatternOpen);
   SetIndexStyle(2, DRAW_HISTOGRAM, STYLE_SOLID, EMPTY, IndicatorBestPatternColor);
   SetIndexShift(2, ForecastBars - Offset);

   SetIndexBuffer(3, ForecastBestPatternClose);
   SetIndexStyle(3, DRAW_HISTOGRAM, STYLE_SOLID, EMPTY, IndicatorBestPatternColor);
   SetIndexShift(3, ForecastBars - Offset);

   SetIndexBuffer(4, ForecastBestPatternHigh);
   SetIndexStyle(4, DRAW_HISTOGRAM, STYLE_SOLID, EMPTY, IndicatorBestPatternColor);
   SetIndexShift(4, ForecastBars - Offset);
  
   SetIndexBuffer(5, ForecastBestPatternLow);
   SetIndexStyle(5, DRAW_HISTOGRAM, STYLE_SOLID, EMPTY, IndicatorBestPatternColor);
   SetIndexShift(5, ForecastBars - Offset);
        
   LoadHistory(Period());
   RemoveOurObjects();
  
   IsRedraw = true;
  
   return (0);
}

//+------------------------------------------------------------------+
//| Деинициализация                                                  |
//+------------------------------------------------------------------+

int deinit()
{
   RemoveOurObjects();

   return (0);
}

//+------------------------------------------------------------------+
//| Работа индикатора                                                |
//+------------------------------------------------------------------+

int start()
{
   int counted_bars = IndicatorCounted();
  
   if (IsRedraw)
   {
      ReCalculate();
   }
  
   // Проверка на наличие вертикальных линий
  
   datetime time1;
   string vlineOffsetStart = IndicatorName + "OffsetStart";
   if (ObjectFind(vlineOffsetStart) == -1)
   {
      time1 = iTime(NULL, 0, Offset + PastBars - 1);
      ObjectCreate(vlineOffsetStart, OBJ_VLINE, 0, time1, 0);
      ObjectSetText(vlineOffsetStart, "НАЧАЛО ОБРАЗЦА", 0);
      ObjectSet(vlineOffsetStart, OBJPROP_COLOR, IndicatorVLinesColor);
      ObjectSet(vlineOffsetStart, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(vlineOffsetStart, OBJPROP_WIDTH, 1);
   }
  
   string vlineOffsetEnd = IndicatorName + "OffsetEnd";
   if (ObjectFind(vlineOffsetEnd) == -1)
   {
      time1 = iTime(NULL, 0, Offset);
      ObjectCreate(vlineOffsetEnd, OBJ_VLINE, 0, time1, 0);
      ObjectSetText(vlineOffsetEnd, "КОНЕЦ ОБРАЗЦА", 0);
      ObjectSet(vlineOffsetEnd, OBJPROP_COLOR, IndicatorVLinesColor);
      ObjectSet(vlineOffsetEnd, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(vlineOffsetEnd, OBJPROP_WIDTH, 1);
   }
  
   datetime datetimeOffsetStart = ObjectGet(vlineOffsetStart, OBJPROP_TIME1);
   int indexOffsetStart = iBarShift(Symbol(), 0, datetimeOffsetStart);
   datetime datetimeOffsetEnd = ObjectGet(vlineOffsetEnd, OBJPROP_TIME1);
   int indexOffsetEnd = iBarShift(Symbol(), 0, datetimeOffsetEnd);
  
   // Проверка на их корректную установку
  
   if (indexOffsetEnd < 1)
   {
      indexOffsetEnd  = 1;
      datetimeOffsetEnd = iTime(NULL, 0, indexOffsetEnd);
      ObjectSet(vlineOffsetEnd, OBJPROP_TIME1, datetimeOffsetEnd);
      ChangeOffset(1);
   }
      
   if ((indexOffsetStart - indexOffsetEnd + 1) < 3)
   {
      indexOffsetStart = indexOffsetEnd + 2;
      PastBars = 3;
      datetimeOffsetStart = iTime(NULL, 0, indexOffsetStart);
      ObjectSet(vlineOffsetStart, OBJPROP_TIME1, datetimeOffsetStart);
   }
  
   // Линии передвигали вручную?
  
   if (datetimeOffsetEnd != OffsetEnd)
   {
      ChangeOffset(indexOffsetEnd);
   }
  
   if ((indexOffsetStart - indexOffsetEnd + 1) != PastBars)
   {
      PastBars = indexOffsetStart - indexOffsetEnd + 1;
   }
  
   // Наступил новый бар?
  
   if (IsNewBar())
   {
      // Нужно сдвинуть образец?
      
      if (!IsOffsetStartFixed && !IsOffsetEndFixed)
      {
         datetimeOffsetStart = iTime(NULL, 0, Offset + PastBars - 1);
         ObjectSet(vlineOffsetStart, OBJPROP_TIME1, datetimeOffsetStart);
      }
      
      if (!IsOffsetEndFixed)
      {
         datetimeOffsetEnd = iTime(NULL, 0, Offset);
         ObjectSet(vlineOffsetEnd, OBJPROP_TIME1, datetimeOffsetEnd);
      }
   }        
  
   // Линии передвинулись?
  
   if ((datetimeOffsetStart != OffsetStart) || (datetimeOffsetEnd != OffsetEnd))
   {
      OffsetStart = datetimeOffsetStart;
      OffsetEnd = datetimeOffsetEnd;
      
      IsRedraw = true;
      LastRedraw = TimeCurrent();
   }      
      
   return (0);
}

//+------------------------------------------------------------------+
//| Появился новый бар?                                              |
//+------------------------------------------------------------------+

bool IsNewBar()
{
   static datetime prevTime = 0;

   datetime currentTime = iTime(NULL, 0, 0);
   if (prevTime == currentTime)
   {
      return (false);
   }

   prevTime = currentTime;
   return (true);
}

//+------------------------------------------------------------------+
//| Подгрузка истории                                                |
//+------------------------------------------------------------------+

void LoadHistory(int period = 0)
{
   int iPeriod[9];
   iPeriod[0] = PERIOD_M1;
   iPeriod[1] = PERIOD_M5;
   iPeriod[2] = PERIOD_M15;
   iPeriod[3] = PERIOD_M30;
   iPeriod[4] = PERIOD_H1;
   iPeriod[5] = PERIOD_H4;
   iPeriod[6] = PERIOD_D1;
   iPeriod[7] = PERIOD_W1;
   iPeriod[8] = PERIOD_MN1;
   for (int i = 0; i < 9; i++)
   {
      if ((period != 0) && (period != iPeriod[i]))
      {
         continue;
      }
  
      double open = iTime(Symbol(), iPeriod[i], 0);
      int error = GetLastError();
      while (error == ERR_HISTORY_WILL_UPDATED)
      {
         Sleep(10000);
         open = iTime(Symbol(), iPeriod[i], 0);
         error = GetLastError();
      }
   }
}

//+------------------------------------------------------------------+
//| Убираем все наши метки                                           |
//+------------------------------------------------------------------+

void RemoveOurObjects()
{
   for (int index = 0; index < ObjectsTotal(); index++)
   {
      if (StringFind(ObjectName(index), IndicatorName) == 0)
      {
         ObjectDelete(ObjectName(index));
         index--;
      }
   }
}

//+------------------------------------------------------------------+
//| Убираем все наши метки                                           |
//+------------------------------------------------------------------+

void ChangeOffset(int newOffset)
{
   Offset = newOffset;
   for (int indexIndicator = 0; indexIndicator < 6; indexIndicator++)
   {
      SetIndexShift(indexIndicator, ForecastBars - Offset);
   }
}

//+------------------------------------------------------------------+
//| Пересчет                                                         |
//+------------------------------------------------------------------+

void ReCalculate()
{
   datetime currentTime = TimeCurrent();
   if ((currentTime - LastRedraw) < 1)
   {
      return;
   }
  
   LastRedraw = currentTime;
   IsRedraw = false;
  
   if (Bars < 100)
   {
      return;
   }  
  
   int indexBar;
   double x[], xp[];
   double xhighest, xlowest;
   int foundAlts;
   double iAlt[], kAlt[], sAlt[];
   double y[], yp[];
   double yhighest, ylowest;
   double scale, scalep;
   double kspearman; //, kh, kl;
   int patternscount;
   bool altAdded;
   datetime ytime;
  
   int baseHour = TimeHour(iTime(NULL, 0, Offset));
   int baseMinute = TimeMinute(iTime(NULL, 0, Offset));
  
   // Снимаем образец и пишем исходные значения

   ArrayResize(x, PastBars);
   for (indexBar = 0; indexBar < PastBars; indexBar++)
   {
      x[indexBar] = iMA(NULL, 0, PeriodMA, 0, MODE_LWMA, PRICE_CLOSE, indexBar + Offset);
   }      
  
   xhighest = x[ArrayMaximum(x)];
   xlowest = x[ArrayMinimum(x)];
  
   ArrayResize(xp, PastBars);
   SpearmenRange(x, xp);
  
   // Готовимся к поиску похожих фрагментов

   foundAlts = 0;
   patternscount = 0;
   ArrayResize(iAlt, MaxAlts);
   ArrayResize(kAlt, MaxAlts);
   ArrayResize(sAlt, MaxAlts);

   // Поиск по циклу похожего фрагмента
  
   for (int indexShift = ForecastBars + Offset + 1; indexShift < Bars; indexShift++)
   {
      ytime = iTime(NULL, 0, indexShift);
      if (IsExactTime)
      {
         // Время образцов должно совпадать
      
         int currentHour = TimeHour(ytime);
         if (currentHour != baseHour)
         {
            continue;
         }

         int currentMinute = TimeMinute(ytime);
         if (currentMinute != baseMinute)
         {
            continue;
         }
      }
      
      if ((indexShift + PastBars) >= Bars)
      {
         // Образец близко к началу истории
      
         break;
      }
  
      if (ytime < MinDate)
      {
         // Образец слишком старый
      
         break;
      }
      
      patternscount++;
      
      // Снимаем образец и пишем исходные значения
      
      ArrayResize(y, PastBars);
      for (indexBar = 0; indexBar < PastBars; indexBar++)
      {
         y[indexBar] = iMA(NULL, 0, PeriodMA, 0, MODE_LWMA, PRICE_CLOSE, indexBar + indexShift);
      }
      
      yhighest = y[ArrayMaximum(y)];
      ylowest = y[ArrayMinimum(y)];
      
      ArrayResize(yp, PastBars);
      SpearmenRange(y, yp);
      
      // Масштаб
  
      scale = (xhighest - xlowest) / (yhighest - ylowest);
      if (scale > 1.0)
      {
         scalep = 100.0 / scale;
      }
      else
      {
         scalep = 100.0 * scale;
      }
      
      if (scalep < ScalePercents)
      {
         continue;
      }
      
      // Проверка корреляции
      
      kspearman = SpearmenCorrelation(xp, yp);
      if (
         ((foundAlts == 0) && (kspearman <= 0.0)) ||
         ((foundAlts > 0) && (kspearman < (kAlt[0] - 1.0)))
         )
      {
         continue;
      }
      
      // Добавляем образец в отсортированный список найденных
      
      altAdded = false;
      for (int j = 0; j < foundAlts; j++)
      {
         if (kspearman > kAlt[j])
         {
            if (foundAlts == MaxAlts)
            {
               foundAlts = MaxAlts - 1;  
            }
        
            for (int m = foundAlts; m >= (j + 1); m--)
            {
               kAlt[m] = kAlt[m - 1];
               iAlt[m] = iAlt[m - 1];
               sAlt[m] = sAlt[m - 1];
            }
        
            kAlt[j] = kspearman;
            iAlt[j] = indexShift;
            sAlt[j] = scale;
            foundAlts++;
            altAdded = true;
            
            break;
         }
      }
      
      if (!altAdded)
      {
         if (foundAlts < MaxAlts)
         {
            kAlt[j] = kspearman;
            iAlt[j] = indexShift;
            sAlt[j] = scale;
            foundAlts++;
         }
      }
   }
  
   // Отсекаем лишние варианты
  
   if (foundAlts > 1)
   {
      for (int a = 1; a < foundAlts; a++)
      {
         if (kAlt[a] < (kAlt[0] - 1.0))
         {
            foundAlts = a;
            break;
         }
      }
   }
  
   double xcbase, ycbase;
   int alt, altindex;
  
   ArrayInitialize(ForecastCloudHigh, EMPTY_VALUE);
   ArrayInitialize(ForecastCloudLow, EMPTY_VALUE);
   if (ShowCloud && (foundAlts > 0))
   {
      double forecastCloudHigh;
      double forecastCloudLow;
      double yhigh, ylow;
      
      // Рисуем облако
      
      xcbase = iClose(NULL, 0, Offset);      
      for (indexBar = 0; indexBar < (PastBars + ForecastBars); indexBar++)
      {
         forecastCloudHigh = DOUBLEMIN;
         forecastCloudLow = DOUBLEMAX;            
         for (alt = 0; alt < foundAlts; alt++)
         {
            altindex = iAlt[alt] - ForecastBars + indexBar;
            ycbase = iClose(NULL, 0, iAlt[alt]);
            
            yhigh = xcbase + ((iHigh(NULL, 0, altindex) - ycbase) * sAlt[alt]);
            if (yhigh > forecastCloudHigh)
            {
               forecastCloudHigh = yhigh;
            }
            
            ylow = xcbase + ((iLow(NULL, 0, altindex) - ycbase) * sAlt[alt]);
            if (ylow < forecastCloudLow)
            {
               forecastCloudLow = ylow;
            }
         }
        
         ForecastCloudHigh[indexBar] = forecastCloudHigh;
         ForecastCloudLow[indexBar] = forecastCloudLow;
      }
   }
  
   ArrayInitialize(ForecastBestPatternOpen, EMPTY_VALUE);
   ArrayInitialize(ForecastBestPatternClose, EMPTY_VALUE);
   ArrayInitialize(ForecastBestPatternHigh, EMPTY_VALUE);
   ArrayInitialize(ForecastBestPatternLow, EMPTY_VALUE);
   if (ShowBestPattern && (foundAlts > 0))
   {
      xcbase = iClose(NULL, 0, Offset);
      ycbase = iClose(NULL, 0, iAlt[0]);
      for (indexBar = 0; indexBar < (PastBars + ForecastBars); indexBar++)
      {
         altindex = iAlt[0] - ForecastBars + indexBar;
         ForecastBestPatternOpen[indexBar] = xcbase + ((iOpen(NULL, 0, altindex) - ycbase) * sAlt[0]);
         ForecastBestPatternClose[indexBar] = xcbase + ((iClose(NULL, 0, altindex) - ycbase) * sAlt[0]);
         ForecastBestPatternHigh[indexBar] = xcbase + ((iHigh(NULL, 0, altindex) - ycbase) * sAlt[0]);
         ForecastBestPatternLow[indexBar] = xcbase + ((iLow(NULL, 0, altindex) - ycbase) * sAlt[0]);
      }
   }
  
   // Рисуем текстовый блок
  
   DrawLabel("Name", "Индикатор " + IndicatorName + ", версия " + IndicatorVersion, 0, 0, IndicatorTextColor);
   DrawLabel("Author", IndicatorAuthor, 0, 10, IndicatorTextColor);
  
   if (patternscount < 100)
   {
      DrawLabel("Alt1", "СОВЕТ: Подгрузите историю " + Symbol(), 0, 25, IndicatorTextWarningColor);
   }
   else
   {
      DrawLabel("Alt1", "Всего рассмотрено образцов: " + patternscount, 0, 25, IndicatorTextColor);
   }
  
   if (foundAlts == 0)
   {
      DrawLabel("Alt2", "Похожих образцов найдено недостаточно", 0, 35, IndicatorTextColor);
      DrawLabel("Alt3", "СОВЕТ: Установите ScalePercents меньше " + DoubleToStr(ScalePercents - 5, 0), 0, 45, IndicatorTextWarningColor);
   }
   else
   {
      double correlationPercents = kAlt[foundAlts - 1];
  
      DrawLabel("Alt2", "Отобрано похожих образцов: " + foundAlts, 0, 35, IndicatorTextColor);
      DrawLabel("Alt3", "Вероятность исполнения прогноза: " + DoubleToStr(correlationPercents, 0) + "%", 0, 45, IndicatorTextColor);
   }
}

//+------------------------------------------------------------------+
//| Ранжирование массива по Cпирмену                                 |
//+------------------------------------------------------------------+

void SpearmenRange(double x[], double &xp[])
{
   int xpi;
   int arraySize = ArraySize(x);
   double xlevelmin = DOUBLEMIN;
   for (int pass = 0; pass < arraySize; pass++)
   {
      int ixmin = -1;
      double xmin = DOUBLEMIN;
      for (int ix = 0; ix < arraySize; ix++)
      {
         if (x[ix] <= xlevelmin)
         {
            continue;
         }
      
         if (ixmin == -1)
         {
            ixmin = ix;
            xmin = x[ix];
         }
         else
         {
            if (x[ix] < xmin)
            {
               ixmin = ix;
               xmin = x[ix];
            }
         }
      }
      
      xpi++;
      xp[ixmin] = xpi;
      xlevelmin = xmin;
   }
}

//+------------------------------------------------------------------+
//| Корреляция массивов по Cпирмену                                  |
//+------------------------------------------------------------------+

double SpearmenCorrelation(double xp[], double yp[])
{
   int arraySize = ArraySize(xp);
   double k = 0.0;
   for (int indexBar = 0; indexBar < arraySize; indexBar++)
   {
      k += (xp[indexBar] - yp[indexBar]) * (xp[indexBar] - yp[indexBar]);
   }
  
   k = (1.0 - ((6.0 * k) / ((arraySize * arraySize * arraySize) - arraySize))) * 100.0;
   return (k);
}

//+------------------------------------------------------------------+
//| Рисование текстовой метки                                        |
//+------------------------------------------------------------------+

void DrawLabel(string label, string text, int x, int y, color clr)
{
   int typeCorner = 1;
   if (!IsTopCorner)
   {
      typeCorner = 3;
   }

   string labelIndicator = IndicatorName + "Label" + label;  
   if (ObjectFind(labelIndicator) == -1)
   {
      ObjectCreate(labelIndicator, OBJ_LABEL, 0, 0, 0);
   }
  
   ObjectSet(labelIndicator, OBJPROP_CORNER, typeCorner);
   ObjectSet(labelIndicator, OBJPROP_XDISTANCE, XCorner + x);
   ObjectSet(labelIndicator, OBJPROP_YDISTANCE, YCorner + y);
   ObjectSetText(labelIndicator, text, FontSize, FontName, clr);
}

