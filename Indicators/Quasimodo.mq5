//+------------------------------------------------------------------+
//|                    Quasimodo Pattern Detector                     |
//|                                                                   |
//| Identifies Quasimodo reversal patterns (D, C, B, A structure)    |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// QUASIMODO PATTERN STRUCTURE
//+------------------------------------------------------------------+

struct QuasimodoPattern {
    bool isValid;
    bool isBullish;              // true for bullish, false for bearish
    double pointD;               // Entry level
    double pointC;               // Structure level
    double pointB;               // Highest/lowest point
    double pointA;               // Reversal level
    int barsAgo;                 // How many bars ago the pattern formed
    double fibonacciRatio;       // Ratio between levels
    double patternStrength;      // 0.0 to 1.0
};

//+------------------------------------------------------------------+
// DETECT BULLISH QUASIMODO PATTERN
//+------------------------------------------------------------------+
// Pattern: D (low) -> C (high) -> B (low, but higher than D) -> A (high, but lower than C)
// Enters at D level, targets A level or above

QuasimodoPattern DetectBullishQuasimodo(string symbol, ENUM_TIMEFRAMES timeframe, int lookbackPeriod)
{
    QuasimodoPattern pattern;
    pattern.isValid = false;
    pattern.isBullish = true;
    pattern.patternStrength = 0.0;
    
    if(lookbackPeriod < 4) return pattern;  // Need at least 4 swing points
    
    // Find the last 4 significant swing points
    double pointA = 0, pointB = 0, pointC = 0, pointD = 0;
    int barA = 0, barB = 0, barC = 0, barD = 0;
    
    // Scan for low-high-low-high pattern
    int swingCount = 0;
    double lastLow = DBL_MAX;
    double lastHigh = -DBL_MAX;
    int lastLowBar = 0, lastHighBar = 0;
    
    for(int i = 1; i < lookbackPeriod && swingCount < 4; i++) {
        double high = iHigh(symbol, timeframe, i);
        double low = iLow(symbol, timeframe, i);
        double prevHigh = iHigh(symbol, timeframe, i + 1);
        double prevLow = iLow(symbol, timeframe, i + 1);
        double nextHigh = iHigh(symbol, timeframe, i - 1);
        double nextLow = iLow(symbol, timeframe, i - 1);
        
        // Check for swing low
        if(low < prevLow && low < nextLow && low < lastLow - 0.0001) {
            lastLow = low;
            lastLowBar = i;
            swingCount++;
            
            if(swingCount == 1) { pointD = lastLow; barD = lastLowBar; }
            else if(swingCount == 3) { pointB = lastLow; barB = lastLowBar; }
        }
        
        // Check for swing high
        if(high > prevHigh && high > nextHigh && high > lastHigh + 0.0001) {
            lastHigh = high;
            lastHighBar = i;
            swingCount++;
            
            if(swingCount == 2) { pointC = lastHigh; barC = lastHighBar; }
            else if(swingCount == 4) { pointA = lastHigh; barA = lastHighBar; }
        }
    }
    
    // Validate bullish Quasimodo pattern: D < B, C > A, and proper ratios
    if(pointD > 0 && pointC > 0 && pointB > 0 && pointA > 0) {
        if(pointD < pointB && pointC > pointA && pointA > pointD) {
            // Check Fibonacci ratios
            double cbRatio = (pointC - pointB) / (pointC - pointD);
            double baRatio = (pointB - pointA) / (pointC - pointA);
            
            if(cbRatio > 0.38 && cbRatio < 0.82 && baRatio > 0.38 && baRatio < 0.82) {
                pattern.isValid = true;
                pattern.pointD = pointD;
                pattern.pointC = pointC;
                pattern.pointB = pointB;
                pattern.pointA = pointA;
                pattern.barsAgo = barA;
                pattern.fibonacciRatio = (pointC - pointB) / (pointC - pointD);
                pattern.patternStrength = 0.7 + (MathAbs(cbRatio - 0.618) < 0.1 ? 0.3 : 0.0);
            }
        }
    }
    
    return pattern;
}

//+------------------------------------------------------------------+
// DETECT BEARISH QUASIMODO PATTERN
//+------------------------------------------------------------------+
// Pattern: D (high) -> C (low) -> B (high, but lower than D) -> A (low, but higher than C)
// Enters at D level, targets A level or below

QuasimodoPattern DetectBearishQuasimodo(string symbol, ENUM_TIMEFRAMES timeframe, int lookbackPeriod)
{
    QuasimodoPattern pattern;
    pattern.isValid = false;
    pattern.isBullish = false;
    pattern.patternStrength = 0.0;
    
    if(lookbackPeriod < 4) return pattern;  // Need at least 4 swing points
    
    // Find the last 4 significant swing points
    double pointA = 0, pointB = 0, pointC = 0, pointD = 0;
    int barA = 0, barB = 0, barC = 0, barD = 0;
    
    // Scan for high-low-high-low pattern
    int swingCount = 0;
    double lastHigh = -DBL_MAX;
    double lastLow = DBL_MAX;
    int lastHighBar = 0, lastLowBar = 0;
    
    for(int i = 1; i < lookbackPeriod && swingCount < 4; i++) {
        double high = iHigh(symbol, timeframe, i);
        double low = iLow(symbol, timeframe, i);
        double prevHigh = iHigh(symbol, timeframe, i + 1);
        double prevLow = iLow(symbol, timeframe, i + 1);
        double nextHigh = iHigh(symbol, timeframe, i - 1);
        double nextLow = iLow(symbol, timeframe, i - 1);
        
        // Check for swing high
        if(high > prevHigh && high > nextHigh && high > lastHigh + 0.0001) {
            lastHigh = high;
            lastHighBar = i;
            swingCount++;
            
            if(swingCount == 1) { pointD = lastHigh; barD = lastHighBar; }
            else if(swingCount == 3) { pointB = lastHigh; barB = lastHighBar; }
        }
        
        // Check for swing low
        if(low < prevLow && low < nextLow && low < lastLow - 0.0001) {
            lastLow = low;
            lastLowBar = i;
            swingCount++;
            
            if(swingCount == 2) { pointC = lastLow; barC = lastLowBar; }
            else if(swingCount == 4) { pointA = lastLow; barA = lastLowBar; }
        }
    }
    
    // Validate bearish Quasimodo pattern: D > B, C < A, and proper ratios
    if(pointD > 0 && pointC > 0 && pointB > 0 && pointA > 0) {
        if(pointD > pointB && pointC < pointA && pointA < pointD) {
            // Check Fibonacci ratios
            double cbRatio = (pointB - pointC) / (pointD - pointC);
            double baRatio = (pointA - pointB) / (pointA - pointC);
            
            if(cbRatio > 0.38 && cbRatio < 0.82 && baRatio > 0.38 && baRatio < 0.82) {
                pattern.isValid = true;
                pattern.pointD = pointD;
                pattern.pointC = pointC;
                pattern.pointB = pointB;
                pattern.pointA = pointA;
                pattern.barsAgo = barA;
                pattern.fibonacciRatio = (pointB - pointC) / (pointD - pointC);
                pattern.patternStrength = 0.7 + (MathAbs(cbRatio - 0.618) < 0.1 ? 0.3 : 0.0);
            }
        }
    }
    
    return pattern;
}

//+------------------------------------------------------------------+
// DETECT QUASIMODO (AUTO DETECT BULLISH OR BEARISH)
//+------------------------------------------------------------------+

QuasimodoPattern DetectQuasimodo(string symbol, ENUM_TIMEFRAMES timeframe, int lookbackPeriod)
{
    // Try to detect both patterns and return the more recent/valid one
    QuasimodoPattern bullish = DetectBullishQuasimodo(symbol, timeframe, lookbackPeriod);
    QuasimodoPattern bearish = DetectBearishQuasimodo(symbol, timeframe, lookbackPeriod);
    
    // Return the pattern with higher strength
    if(bullish.isValid && bearish.isValid) {
        return bullish.patternStrength >= bearish.patternStrength ? bullish : bearish;
    }
    
    if(bullish.isValid) return bullish;
    if(bearish.isValid) return bearish;
    
    // Return empty pattern if neither found
    QuasimodoPattern empty;
    empty.isValid = false;
    return empty;
}

//+------------------------------------------------------------------+
// CHECK IF PRICE IS AT QUASIMODO ENTRY (POINT D)
//+------------------------------------------------------------------+

bool IsPriceAtQuasimodoEntry(double currentPrice, QuasimodoPattern& pattern, double tolerance)
{
    if(!pattern.isValid) return false;
    
    double distance = MathAbs(currentPrice - pattern.pointD);
    return distance <= tolerance;
}

//+------------------------------------------------------------------+
// GET QUASIMODO TARGET (POINT A)
//+------------------------------------------------------------------+

double GetQuasimodoTarget(QuasimodoPattern& pattern)
{
    if(!pattern.isValid) return 0;
    return pattern.pointA;
}

//+------------------------------------------------------------------+
// GET QUASIMODO CONFIRMATION LEVEL (POINT B)
//+------------------------------------------------------------------+

double GetQuasimodoConfirmation(QuasimodoPattern& pattern)
{
    if(!pattern.isValid) return 0;
    return pattern.pointB;
}

//+------------------------------------------------------------------+
// GET QUASIMODO RISK LEVEL (POINT C)
//+------------------------------------------------------------------+

double GetQuasimodoRiskLevel(QuasimodoPattern& pattern)
{
    if(!pattern.isValid) return 0;
    return pattern.pointC;
}

//+------------------------------------------------------------------+
// CALCULATE PATTERN DISTANCE IN PIPS
//+------------------------------------------------------------------+

int GetQuasimodoDistancePips(string symbol, QuasimodoPattern& pattern)
{
    if(!pattern.isValid) return 0;
    
    double range = MathAbs(pattern.pointA - pattern.pointD);
    double pipValue = 0.0001;  // Standard pip
    
    return (int)(range / pipValue);
}

//+------------------------------------------------------------------+
// VALIDATE PATTERN HAS FORMED (CONFIRMATION BARS PASSED)
//+------------------------------------------------------------------+

bool IsQuasimodoConfirmed(QuasimodoPattern& pattern, int confirmationBars)
{
    if(!pattern.isValid) return false;
    
    // Pattern is confirmed if it's at least 'confirmationBars' bars old
    return pattern.barsAgo >= confirmationBars;
}

//+------------------------------------------------------------------+
// GET QUASIMODO REVERSAL ZONE
//+------------------------------------------------------------------+
// Returns a zone (min/max) where reversal is expected

struct ReversalZone {
    double minPrice;
    double maxPrice;
};

ReversalZone GetQuasimodoReversalZone(QuasimodoPattern& pattern, double zoneTolerance)
{
    ReversalZone zone;
    
    if(!pattern.isValid) {
        zone.minPrice = 0;
        zone.maxPrice = 0;
        return zone;
    }
    
    // Reversal zone around point A
    zone.minPrice = pattern.pointA - zoneTolerance;
    zone.maxPrice = pattern.pointA + zoneTolerance;
    
    return zone;
}

//+------------------------------------------------------------------+