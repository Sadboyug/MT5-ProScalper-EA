//+------------------------------------------------------------------+
//|            Malaysian Support & Resistance (MSNR) Module           |
//|                                                                   |
//| Identifies key support and resistance levels using price action  |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// SUPPORT & RESISTANCE LEVEL STRUCTURE
//+------------------------------------------------------------------+

struct SRLevel {
    double price;
    int touchCount;
    datetime lastTouchTime;
    bool isStrong;      // Strong if touched 3+ times
    double strength;    // 0.0 to 1.0
    int barsSinceTouch;
};

//+------------------------------------------------------------------+
// GLOBAL ARRAYS FOR SR LEVELS
//+------------------------------------------------------------------+

SRLevel supportLevels[100];
SRLevel resistanceLevels[100];
int supportCount = 0;
int resistanceCount = 0;

//+------------------------------------------------------------------+
// IDENTIFY SUPPORT LEVELS
//+------------------------------------------------------------------+

// Find local support levels (lows that reversed upward)
void IdentifySupportLevels(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, double touchThreshold)
{
    supportCount = 0;
    double currentPrice = iClose(symbol, timeframe, 0);
    
    // Find local minima (swing lows)
    for(int i = 1; i < lookback; i++) {
        double low = iLow(symbol, timeframe, i);
        double prevLow = iLow(symbol, timeframe, i + 1);
        double nextLow = iLow(symbol, timeframe, i - 1);
        
        // Check if it's a local minimum
        if(low < prevLow && low < nextLow) {
            // Check if this level already exists
            bool levelExists = false;
            int existingIndex = -1;
            
            for(int j = 0; j < supportCount; j++) {
                double diff = MathAbs(supportLevels[j].price - low);
                if(diff <= touchThreshold) {
                    levelExists = true;
                    existingIndex = j;
                    break;
                }
            }
            
            if(levelExists) {
                // Increase touch count
                supportLevels[existingIndex].touchCount++;
                supportLevels[existingIndex].lastTouchTime = iTime(symbol, timeframe, i);
                supportLevels[existingIndex].barsSinceTouch = i;
            } else if(supportCount < 100) {
                // Add new support level
                supportLevels[supportCount].price = low;
                supportLevels[supportCount].touchCount = 1;
                supportLevels[supportCount].lastTouchTime = iTime(symbol, timeframe, i);
                supportLevels[supportCount].barsSinceTouch = i;
                supportLevels[supportCount].isStrong = false;
                supportLevels[supportCount].strength = 0.5;
                supportCount++;
            }
        }
    }
    
    // Calculate strength and mark strong levels
    for(int i = 0; i < supportCount; i++) {
        if(supportLevels[i].touchCount >= 3) {
            supportLevels[i].isStrong = true;
            supportLevels[i].strength = MathMin(1.0, 0.5 + (supportLevels[i].touchCount * 0.1));
        } else {
            supportLevels[i].strength = 0.3 + (supportLevels[i].touchCount * 0.2);
        }
    }
}

//+------------------------------------------------------------------+
// IDENTIFY RESISTANCE LEVELS
//+------------------------------------------------------------------+

// Find local resistance levels (highs that reversed downward)
void IdentifyResistanceLevels(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, double touchThreshold)
{
    resistanceCount = 0;
    double currentPrice = iClose(symbol, timeframe, 0);
    
    // Find local maxima (swing highs)
    for(int i = 1; i < lookback; i++) {
        double high = iHigh(symbol, timeframe, i);
        double prevHigh = iHigh(symbol, timeframe, i + 1);
        double nextHigh = iHigh(symbol, timeframe, i - 1);
        
        // Check if it's a local maximum
        if(high > prevHigh && high > nextHigh) {
            // Check if this level already exists
            bool levelExists = false;
            int existingIndex = -1;
            
            for(int j = 0; j < resistanceCount; j++) {
                double diff = MathAbs(resistanceLevels[j].price - high);
                if(diff <= touchThreshold) {
                    levelExists = true;
                    existingIndex = j;
                    break;
                }
            }
            
            if(levelExists) {
                // Increase touch count
                resistanceLevels[existingIndex].touchCount++;
                resistanceLevels[existingIndex].lastTouchTime = iTime(symbol, timeframe, i);
                resistanceLevels[existingIndex].barsSinceTouch = i;
            } else if(resistanceCount < 100) {
                // Add new resistance level
                resistanceLevels[resistanceCount].price = high;
                resistanceLevels[resistanceCount].touchCount = 1;
                resistanceLevels[resistanceCount].lastTouchTime = iTime(symbol, timeframe, i);
                resistanceLevels[resistanceCount].barsSinceTouch = i;
                resistanceLevels[resistanceCount].isStrong = false;
                resistanceLevels[resistanceCount].strength = 0.5;
                resistanceCount++;
            }
        }
    }
    
    // Calculate strength and mark strong levels
    for(int i = 0; i < resistanceCount; i++) {
        if(resistanceLevels[i].touchCount >= 3) {
            resistanceLevels[i].isStrong = true;
            resistanceLevels[i].strength = MathMin(1.0, 0.5 + (resistanceLevels[i].touchCount * 0.1));
        } else {
            resistanceLevels[i].strength = 0.3 + (resistanceLevels[i].touchCount * 0.2);
        }
    }
}

//+------------------------------------------------------------------+
// GET NEAREST SUPPORT LEVEL
//+------------------------------------------------------------------+

double GetNearestSupport(double currentPrice, int minBounces = 0)
{
    double nearestSupport = 0;
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < supportCount; i++) {
        if(supportLevels[i].price < currentPrice) {
            double distance = currentPrice - supportLevels[i].price;
            
            if(supportLevels[i].touchCount >= minBounces && distance < minDistance) {
                nearestSupport = supportLevels[i].price;
                minDistance = distance;
            }
        }
    }
    
    return nearestSupport;
}

//+------------------------------------------------------------------+
// GET NEAREST RESISTANCE LEVEL
//+------------------------------------------------------------------+

double GetNearestResistance(double currentPrice, int minBounces = 0)
{
    double nearestResistance = 0;
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < resistanceCount; i++) {
        if(resistanceLevels[i].price > currentPrice) {
            double distance = resistanceLevels[i].price - currentPrice;
            
            if(resistanceLevels[i].touchCount >= minBounces && distance < minDistance) {
                nearestResistance = resistanceLevels[i].price;
                minDistance = distance;
            }
        }
    }
    
    return nearestResistance;
}

//+------------------------------------------------------------------+
// GET ALL SUPPORT LEVELS
//+------------------------------------------------------------------+

int GetAllSupportLevels(SRLevel& levels[], int minBounces = 0)
{
    int count = 0;
    
    for(int i = 0; i < supportCount; i++) {
        if(supportLevels[i].touchCount >= minBounces) {
            levels[count] = supportLevels[i];
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
// GET ALL RESISTANCE LEVELS
//+------------------------------------------------------------------+

int GetAllResistanceLevels(SRLevel& levels[], int minBounces = 0)
{
    int count = 0;
    
    for(int i = 0; i < resistanceCount; i++) {
        if(resistanceLevels[i].touchCount >= minBounces) {
            levels[count] = resistanceLevels[i];
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
// CHECK IF PRICE IS NEAR SUPPORT
//+------------------------------------------------------------------+

bool IsPriceNearSupport(double currentPrice, double tolerance)
{
    for(int i = 0; i < supportCount; i++) {
        if(MathAbs(currentPrice - supportLevels[i].price) <= tolerance) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
// CHECK IF PRICE IS NEAR RESISTANCE
//+------------------------------------------------------------------+

bool IsPriceNearResistance(double currentPrice, double tolerance)
{
    for(int i = 0; i < resistanceCount; i++) {
        if(MathAbs(currentPrice - resistanceLevels[i].price) <= tolerance) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
// GET SUPPORT/RESISTANCE STRENGTH AT PRICE
//+------------------------------------------------------------------+

double GetSRStrengthAtPrice(double price, bool getSupport, double tolerance)
{
    double maxStrength = 0;
    
    if(getSupport) {
        for(int i = 0; i < supportCount; i++) {
            if(MathAbs(price - supportLevels[i].price) <= tolerance) {
                if(supportLevels[i].strength > maxStrength) {
                    maxStrength = supportLevels[i].strength;
                }
            }
        }
    } else {
        for(int i = 0; i < resistanceCount; i++) {
            if(MathAbs(price - resistanceLevels[i].price) <= tolerance) {
                if(resistanceLevels[i].strength > maxStrength) {
                    maxStrength = resistanceLevels[i].strength;
                }
            }
        }
    }
    
    return maxStrength;
}

//+------------------------------------------------------------------+
// SORT LEVELS BY PROXIMITY
//+------------------------------------------------------------------+

void SortLevelsByProximity(SRLevel& levels[], int count, double referencePrice)
{
    // Simple bubble sort by distance
    for(int i = 0; i < count - 1; i++) {
        for(int j = i + 1; j < count; j++) {
            double dist1 = MathAbs(levels[i].price - referencePrice);
            double dist2 = MathAbs(levels[j].price - referencePrice);
            
            if(dist2 < dist1) {
                SRLevel temp = levels[i];
                levels[i] = levels[j];
                levels[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
// CLEAR ALL LEVELS (FOR REINITIALIZATION)
//+------------------------------------------------------------------+

void ClearAllLevels()
{
    supportCount = 0;
    resistanceCount = 0;
    
    for(int i = 0; i < 100; i++) {
        supportLevels[i].price = 0;
        supportLevels[i].touchCount = 0;
        supportLevels[i].isStrong = false;
        
        resistanceLevels[i].price = 0;
        resistanceLevels[i].touchCount = 0;
        resistanceLevels[i].isStrong = false;
    }
}

//+------------------------------------------------------------------+