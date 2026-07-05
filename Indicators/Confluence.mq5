//+------------------------------------------------------------------+
//|                    Confluence Zone Calculator                     |
//|                                                                   |
//| Identifies confluence zones where multiple support/resistance    |
//| levels align - powerful reversal and exit points                 |
//+------------------------------------------------------------------+

#property strict

//+------------------------------------------------------------------+
// CONFLUENCE LEVEL STRUCTURE
//+------------------------------------------------------------------+

struct ConfluenceLevel {
    double price;
    int levelCount;              // How many levels converge here
    double strength;             // Cumulative strength (0.0 to 10.0)
    string sources[10];          // What created this level (S/R, Pivot, Fib, QM, etc)
};

//+------------------------------------------------------------------+
// CALCULATE CONFLUENCE ZONES FROM MULTIPLE SOURCES
//+------------------------------------------------------------------+

int FindConfluenceZones(double priceArray[], int priceCount, 
                        double tolerance, 
                        ConfluenceLevel& confluenceLevels[])
{
    int confluenceCount = 0;
    
    if(priceCount == 0) return 0;
    
    // Sort prices
    SortDoubleArray(priceArray, priceCount);
    
    // Group nearby prices
    for(int i = 0; i < priceCount && confluenceCount < 100; i++) {
        bool foundExisting = false;
        
        for(int j = 0; j < confluenceCount; j++) {
            if(MathAbs(confluenceLevels[j].price - priceArray[i]) <= tolerance) {
                // Add to existing confluence zone
                confluenceLevels[j].levelCount++;
                confluenceLevels[j].strength += 1.0;
                foundExisting = true;
                break;
            }
        }
        
        if(!foundExisting) {
            // Create new confluence zone
            confluenceLevels[confluenceCount].price = priceArray[i];
            confluenceLevels[confluenceCount].levelCount = 1;
            confluenceLevels[confluenceCount].strength = 1.0;
            confluenceCount++;
        }
    }
    
    return confluenceCount;
}

//+------------------------------------------------------------------+
// BUILD CONFLUENCE ZONE FROM MSNR AND QUASIMODO
//+------------------------------------------------------------------+

int BuildTradeConfluenceZones(string symbol, ENUM_TIMEFRAMES timeframe,
                               double currentPrice,
                               double tolerance,
                               ConfluenceLevel& confluenceZones[])
{
    double allLevels[20];
    int levelCount = 0;
    
    // 1. Add nearby MSNR support levels
    for(int i = 0; i < 5; i++) {
        double support = GetNearestSupport(currentPrice, i);
        if(support > 0 && support < currentPrice) {
            allLevels[levelCount] = support;
            levelCount++;
        }
    }
    
    // 2. Add nearby MSNR resistance levels
    for(int i = 0; i < 5; i++) {
        double resistance = GetNearestResistance(currentPrice, i);
        if(resistance > 0 && resistance > currentPrice) {
            allLevels[levelCount] = resistance;
            levelCount++;
        }
    }
    
    // 3. Add Quasimodo levels if pattern detected
    QuasimodoPattern qm = DetectQuasimodo(symbol, timeframe, 50);
    if(qm.isValid) {
        // Add Point A (target)
        allLevels[levelCount] = qm.pointA;
        levelCount++;
        
        // Add Point B (confirmation)
        allLevels[levelCount] = qm.pointB;
        levelCount++;
        
        // Add Point C (risk level)
        allLevels[levelCount] = qm.pointC;
        levelCount++;
    }
    
    // 4. Add pivot points
    double pivotHigh = iHigh(symbol, timeframe, 1);
    double pivotLow = iLow(symbol, timeframe, 1);
    double pivotMid = (pivotHigh + pivotLow) / 2;
    
    allLevels[levelCount] = pivotMid;
    levelCount++;
    
    // Find confluence zones
    return FindConfluenceZones(allLevels, levelCount, tolerance, confluenceZones);
}

//+------------------------------------------------------------------+
// GET NEAREST CONFLUENCE ZONE
//+------------------------------------------------------------------+

ConfluenceLevel GetNearestConfluenceZone(string symbol, ENUM_TIMEFRAMES timeframe,
                                         double currentPrice, 
                                         double tolerance,
                                         int minLevels,
                                         bool above = true)
{
    ConfluenceLevel confluenceZones[100];
    int zoneCount = BuildTradeConfluenceZones(symbol, timeframe, currentPrice, tolerance, confluenceZones);
    
    ConfluenceLevel nearest;
    nearest.price = 0;
    nearest.levelCount = 0;
    nearest.strength = 0;
    
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < zoneCount; i++) {
        if(confluenceZones[i].levelCount >= minLevels) {
            if(above && confluenceZones[i].price > currentPrice) {
                double distance = confluenceZones[i].price - currentPrice;
                if(distance < minDistance) {
                    nearest = confluenceZones[i];
                    minDistance = distance;
                }
            } else if(!above && confluenceZones[i].price < currentPrice) {
                double distance = currentPrice - confluenceZones[i].price;
                if(distance < minDistance) {
                    nearest = confluenceZones[i];
                    minDistance = distance;
                }
            }
        }
    }
    
    return nearest;
}

//+------------------------------------------------------------------+
// GET ALL CONFLUENCE ZONES ABOVE PRICE
//+------------------------------------------------------------------+

int GetConfluenceZonesAbove(string symbol, ENUM_TIMEFRAMES timeframe,
                            double currentPrice, 
                            double tolerance,
                            int minLevels,
                            ConfluenceLevel& aboveZones[])
{
    ConfluenceLevel confluenceZones[100];
    int zoneCount = BuildTradeConfluenceZones(symbol, timeframe, currentPrice, tolerance, confluenceZones);
    
    int count = 0;
    for(int i = 0; i < zoneCount; i++) {
        if(confluenceZones[i].levelCount >= minLevels && confluenceZones[i].price > currentPrice) {
            aboveZones[count] = confluenceZones[i];
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
// GET ALL CONFLUENCE ZONES BELOW PRICE
//+------------------------------------------------------------------+

int GetConfluenceZonesBelow(string symbol, ENUM_TIMEFRAMES timeframe,
                            double currentPrice, 
                            double tolerance,
                            int minLevels,
                            ConfluenceLevel& belowZones[])
{
    ConfluenceLevel confluenceZones[100];
    int zoneCount = BuildTradeConfluenceZones(symbol, timeframe, currentPrice, tolerance, confluenceZones);
    
    int count = 0;
    for(int i = 0; i < zoneCount; i++) {
        if(confluenceZones[i].levelCount >= minLevels && confluenceZones[i].price < currentPrice) {
            belowZones[count] = confluenceZones[i];
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
// CALCULATE STRONGEST CONFLUENCE ZONE
//+------------------------------------------------------------------+

ConfluenceLevel GetStrongestConfluenceZone(string symbol, ENUM_TIMEFRAMES timeframe,
                                           double tolerance)
{
    ConfluenceLevel confluenceZones[100];
    int zoneCount = BuildTradeConfluenceZones(symbol, timeframe, 0, tolerance, confluenceZones);
    
    ConfluenceLevel strongest;
    strongest.price = 0;
    strongest.levelCount = 0;
    strongest.strength = 0;
    
    for(int i = 0; i < zoneCount; i++) {
        if(confluenceZones[i].strength > strongest.strength) {
            strongest = confluenceZones[i];
        }
    }
    
    return strongest;
}

//+------------------------------------------------------------------+
// CHECK IF PRICE IS IN CONFLUENCE ZONE
//+------------------------------------------------------------------+

bool IsPriceInConfluence(double price, double confluencePrice, double tolerance)
{
    return MathAbs(price - confluencePrice) <= tolerance;
}

//+------------------------------------------------------------------+
// GET CONFLUENCE STRENGTH AT PRICE
//+------------------------------------------------------------------+

int GetConfluenceStrengthAtPrice(string symbol, ENUM_TIMEFRAMES timeframe,
                                 double price, double tolerance)
{
    ConfluenceLevel confluenceZones[100];
    int zoneCount = BuildTradeConfluenceZones(symbol, timeframe, 0, tolerance, confluenceZones);
    
    for(int i = 0; i < zoneCount; i++) {
        if(IsPriceInConfluence(price, confluenceZones[i].price, tolerance)) {
            return confluenceZones[i].levelCount;
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
// SORT CONFLUENCE LEVELS BY STRENGTH
//+------------------------------------------------------------------+

void SortConfluenceLevelsByStrength(ConfluenceLevel& levels[], int count)
{
    for(int i = 0; i < count - 1; i++) {
        for(int j = i + 1; j < count; j++) {
            if(levels[j].strength > levels[i].strength) {
                ConfluenceLevel temp = levels[i];
                levels[i] = levels[j];
                levels[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
// UTILITY: SORT DOUBLE ARRAY
//+------------------------------------------------------------------+

void SortDoubleArray(double& arr[], int size)
{
    for(int i = 0; i < size - 1; i++) {
        for(int j = i + 1; j < size; j++) {
            if(arr[j] < arr[i]) {
                double temp = arr[i];
                arr[i] = arr[j];
                arr[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+