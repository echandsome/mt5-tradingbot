// Parameter, die manuell geändert werden können
input double MinATR = 0.0001;          // Minimum ATR-Wert für Volatilität
input int RSIOverbought = 70;          // RSI-Wert überkauft
input int RSIOversold = 30;            // RSI-Wert überverkauft
input int TakeProfitPips = 10;         // Beispielwert für Take Profit in Pips
input int MaxTrades = 3;               // Maximale Anzahl an offenen Trades
input double MaxDrawdown = 0.02;       // Maximaler Drawdown als Prozentsatz
input int ATRPeriod = 14;              // Periode für den ATR-Indikator
input int RSI_Period = 14;             // Periode für den RSI-Indikator
input int MA_Period = 10;              // Periode für den gleitenden Durchschnitt (SMA)

// Globale Variablen
double atrValue;
double maValue;
double rsiValue;
double dynamicStopLossGlobal;
double lotSizeGlobal;
double slBuy, slSell, tp, tpSell;

// Berechnung der Lotgröße basierend auf dem Risiko
double CalculateLotSize(double dynamicStopLoss)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * 0.01;  // 1% des Kontos riskieren
    double lotSize = riskAmount / (dynamicStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    Print("Berechnete Lotgröße: ", lotSize);
    return lotSize;
}

// Berechnung des maximalen Drawdowns
double GetMaxDrawdown()
{
    double maxDrawdown = 0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionSelect(_Symbol))
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if (profit < maxDrawdown)
            {
                maxDrawdown = profit;
            }
        }
    }
    Print("Maximaler Drawdown: ", maxDrawdown);
    return maxDrawdown;
}

void OnTick()
{
    // Hole aktuelle Preisdaten
    double price = iClose(_Symbol, PERIOD_M1, 0);  // Letzter Schlusskurs
    atrValue = iATR(_Symbol, PERIOD_M1, ATRPeriod);    // ATR-Wert für Volatilität
    maValue = iMA(_Symbol, PERIOD_M1, MA_Period, 0, MODE_SMA, PRICE_CLOSE);  // Gleitender Durchschnitt
    rsiValue = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);  // RSI-Wert zur Bestätigung

    // Debugging-Prints
    Print("Aktueller Preis: ", price);
    Print("Aktueller ATR-Wert: ", atrValue);
    Print("Aktueller RSI-Wert: ", rsiValue);
    Print("Aktueller MA-Wert: ", maValue);

    // Überprüfe, ob der ATR-Wert genügend Volatilität anzeigt
    if (atrValue < MinATR)
    {
        Print("Markt ist zu ruhig, keine Trades werden eröffnet. ATR: ", atrValue);
        return;
    }

    // Berechnung des dynamischen Stop-Loss basierend auf ATR
    dynamicStopLossGlobal = atrValue * 2;  // Stop-Loss auf 2x ATR setzen
    slBuy = price - dynamicStopLossGlobal;  // Stop-Loss für Kauf
    slSell = price + dynamicStopLossGlobal; // Stop-Loss für Verkauf
    tp = price + TakeProfitPips * _Point;  // Take-Profit für Kauf
    tpSell = price - TakeProfitPips * _Point; // Take-Profit für Verkauf

    // Berechne die Lotgröße basierend auf dem Risiko
    lotSizeGlobal = CalculateLotSize(dynamicStopLossGlobal);
    if (lotSizeGlobal <= 0)
    {
        Print("Ungültige Lotgröße berechnet, Trade wird nicht eröffnet.");
        return;
    }

    // Maximale offene Trades zählen
    int openTrades = 0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionSelect(_Symbol))
        {
            openTrades++;  // Zähle die offenen Trades
        }
    }
    Print("Offene Trades: ", openTrades);

    // Maximaler Drawdown-Check
    if (GetMaxDrawdown() > MaxDrawdown)
    {
        Print("Maximaler Drawdown überschritten, keine weiteren Trades werden eröffnet.");
        return;
    }

    // Kaufbedingung: RSI < 70 (nicht überkauft), Preis über MA, genügend Volatilität
    if (rsiValue < RSIOverbought && rsiValue > RSIOversold && price > maValue && openTrades < MaxTrades)
    {
        Print("Kaufbedingungen erfüllt. Setze Kauf-Trade.");
        MqlTradeRequest buyRequest = {};
        buyRequest.action = TRADE_ACTION_DEAL;
        buyRequest.symbol = _Symbol;
        buyRequest.volume = lotSizeGlobal;
        buyRequest.type = ORDER_TYPE_BUY;
        buyRequest.price = price;
        buyRequest.sl = slBuy;
        buyRequest.tp = tp;
        buyRequest.deviation = 10;  // Slippage
        buyRequest.magic = 123456;  // Magic Number
        buyRequest.comment = "Kauf-Trade";

        MqlTradeResult buyResult = {};
        if (!OrderSend(buyRequest, buyResult))
        {
            int errorCode = GetLastError();
            Print("Fehler beim Setzen des Kauf-Trades: ", errorCode);
            return;  // Stoppe den Bot nach einem Fehler
        }
        else
        {
            Print("Neuer Kauf-Trade gesetzt!");
        }
    }

    // Verkaufsbedingung: RSI > 30 (nicht überverkauft), Preis unter MA, genügend Volatilität
    if (rsiValue > RSIOverbought && rsiValue < RSIOversold && price < maValue && openTrades < MaxTrades)
    {
        Print("Verkaufsbedingungen erfüllt. Setze Verkaufs-Trade.");
        MqlTradeRequest sellRequest = {};
        sellRequest.action = TRADE_ACTION_DEAL;
        sellRequest.symbol = _Symbol;
        sellRequest.volume = lotSizeGlobal;
        sellRequest.type = ORDER_TYPE_SELL;
        sellRequest.price = price;
        sellRequest.sl = slSell;
        sellRequest.tp = tpSell;
        sellRequest.deviation = 10;  // Slippage
        sellRequest.magic = 123456;  // Magic Number
        sellRequest.comment = "Verkaufs-Trade";

        MqlTradeResult sellResult = {};
        if (!OrderSend(sellRequest, sellResult))
        {
            int errorCode = GetLastError();
            Print("Fehler beim Setzen des Verkaufs-Trades: ", errorCode);
            return;  // Stoppe den Bot nach einem Fehler
        }
        else
        {
            Print("Neuer Verkaufs-Trade gesetzt!");
        }
    }
}
