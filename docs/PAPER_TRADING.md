# Paper Trading — How It Works

Mynt Plus Paper is a **practice version** of the Mynt Plus web app. Users log in with their real Mynt account and see **real live prices**, but every order is **simulated on their own device**. No real order is ever placed, and no real money moves.

This app is built from the main app, [Zebu-Dev/Mynt-Plus-Web](https://github.com/Zebu-Dev/Mynt-Plus-Web). We pull its updates in regularly and keep the paper trading code as a small, separate layer on top of it.

---

## 1. The big picture

```
            ┌──────────────────────── App screens ────────────────────────┐
            │  Watchlist · Charts · Order window · Positions · Holdings    │
            │  Orders · Funds                                              │
            └───────────────────────────────┬──────────────────────────────┘
                                            │  every screen calls  locator<ApiExporter>()
                                            ▼
                         ┌──────────────────────────────────────┐
                         │          PaperApiExporter            │   (paper mode is always ON)
                         │                                      │
   order / fund /        │  ① Simulated   → Paper engine        │
   portfolio calls  ───► │  ② Blocked     → PaperSafetyGuard    │
                         │  ③ Everything else → real API        │
                         └──────┬─────────────────┬─────────────┘
                                │                 │
                 ┌──────────────▼───┐     ┌───────▼─────────────────────┐
                 │  Paper engine    │     │  Shared HTTP client          │
                 │  (on the device) │     │  + PaperNetworkGuard         │
                 │                  │     │  (blocks order/money URLs)   │
                 │  • Order engine  │     └───────┬─────────────────────┘
                 │  • Virtual wallet│             │ only market data, login,
                 │  • Portfolio     │             │ reports, etc. get through
                 └──────────────────┘             ▼
                  saved in browser            Real Mynt servers
                  storage                     (prices, charts, search …)
```

In one sentence: **the app is the normal Mynt app, but the part that talks to the broker has been replaced by a local simulator, with two safety walls behind it.**

---

## 2. What is real and what is simulated

| Area | In paper mode |
|---|---|
| Login, profile | **Real** — users log in with their Mynt account |
| Live prices, watchlist, charts, option chain, scanner, search | **Real** — streamed from Mynt |
| Placing / modifying / cancelling orders | **Simulated** on the device |
| Order book, trade book, order history | **Simulated** — shows paper orders only |
| Positions, holdings | **Simulated** — calculated from paper trades |
| Funds, margin | **Simulated** — a virtual wallet (starts at ₹10,00,000) |
| Add money / withdraw | **Simulated** — just changes the virtual balance |
| Brokerage / margin estimates | **Simulated** estimates |
| GTT / OCO, SIP, IPO, bonds, mutual funds, pledge, corporate actions, MTF transfer | **Hidden and blocked** — not available |

---

## 3. The files involved

All paper-only logic lives in **`lib/api/paper/`**:

| File | What it does (simple terms) |
|---|---|
| `paper_api_exporter.dart` | Stands in for the real API. Sends order, fund and portfolio calls to the paper engine, and returns answers in **exactly the same shape** as the real API, so the screens don't know the difference. |
| `paper_order_engine.dart` | The "fake exchange". Accepts orders, decides when they fill, and records orders and trades. |
| `virtual_wallet.dart` | The fake bank balance. Starts at ₹10,00,000; buying takes money out, selling puts it back. |
| `paper_portfolio_service.dart` | Builds **positions** and **holdings** from the list of paper trades. |
| `paper_ltp_service.dart` | A random price generator, for testing without a live feed. **Not used at the moment** (see Known gaps). |
| `paper_safety_guard.dart` | Safety wall #1. Blocks every API method that would place a real order or move real money but isn't simulated. |
| `paper_network_guard.dart` | Safety wall #2. Blocks order and money **web addresses** inside the HTTP client itself. |

Small hooks outside that folder:

| File | Change |
|---|---|
| `lib/locator/locator.dart` | `const bool isPaperTrading = true;` — always registers `PaperApiExporter`. |
| `lib/main.dart` | Loads the wallet and the engine at startup. |
| `lib/api/core/api_core.dart` | Runs every HTTP request through `PaperNetworkGuard`. |
| `lib/screens/web/customizable_split_home_screen.dart` | The **PT** badge in the navbar; hides MF / IPO / Bonds; `paperUnavailableFeatures` list. |
| `lib/screens/web/paper/paper_unavailable_screen.dart` | The "not available in paper trading" screen. |
| `lib/screens/web/funds/secure_fund_web.dart` | Paper add-money / withdraw pop-up and the **Reset Account** button. |
| `lib/screens/web/order/place_order_screen_web.dart` | GTT tab hidden. |
| `lib/screens/web/holdings/*` | Pledge buttons hidden. |
| `lib/provider/order_provider.dart` | Skips the "order placed" confirmation screen once a paper order has already filled. |
| `lib/provider/portfolio_provider.dart` and some order screens | Pass `token` / `dname` on orders so the paper engine knows which instrument it is. |

---

## 4. How paper mode is switched on

1. **`isPaperTrading` is a constant set to `true`** (`locator.dart`). It can't change while the app runs. There's no toggle, saved setting or URL option that turns live trading on.
2. At startup, `setupLocator()` registers **`PaperApiExporter`** as the app's `ApiExporter`.
3. `main.dart` then loads the saved paper data:
   ```dart
   await VirtualWallet.instance.init();
   await PaperOrderEngine.instance.init();
   ```
4. Every screen and provider gets its API through `locator<ApiExporter>()`, so they all get the paper version without being changed.

---

## 5. Life of a paper order

### Placing an order

```
User clicks BUY
   → order_provider builds a PlaceOrderInput (same as live)
   → api.getPlaceOrder(...)                       ← PaperApiExporter
       → works out a fill price
       → PaperOrderEngine.placeOrder(...)
           1. Check quantity > 0
           2. Check money:
                BUY  → wallet must cover price × qty
                SELL (F&O, opening a short) → wallet must cover ~10 × premium
                SELL (closing a long) → no check, it frees up money
           3. Create an order with status PENDING
           4. Decide whether it fills now (table below)
           5. Save orders and trades to browser storage
       ← returns a normal "Ok" response with the order number
   → order book / positions refresh as usual
```

**When does an order fill?**

| Order type | Rule |
|---|---|
| **Market (MKT)** | Fills immediately at the current price. |
| **Limit (LMT)** | BUY fills if price ≤ limit; SELL fills if price ≥ limit. Fills at the limit price. |
| **SL-MKT** | Fills immediately if the trigger is already hit (BUY: price ≥ trigger, SELL: price ≤ trigger), at the current price. |
| **SL-LMT** | Same trigger check; fills at the limit price. |
| Not filled yet | Stays **PENDING** in the order book; it can be modified or cancelled. |

### When an order fills (`_executeOrder`)

- **BUY** → takes `price × qty` out of the wallet. If there isn't enough money, the order is **REJECTED** ("Insufficient funds").
- **SELL** → adds `price × qty` to the wallet.
- The order becomes **COMPLETE**, and a **trade** is recorded.

Because buying takes money out and selling puts it back, a closed trade leaves the wallet up or down by exactly the profit or loss.

### Modify, cancel, exit

- **Modify** changes price, quantity or type on a PENDING order. COMPLETE or CANCELLED orders can't be changed.
- **Cancel** marks a PENDING order CANCELLED.
- **Exit position / Exit All** places an opposite MARKET order through the same path as above.

---

## 6. Positions, holdings and funds

Nothing extra is stored for these. They're **rebuilt from the trade list** every time a screen asks.

- **Positions** (`getPositionBook`): trades are grouped by exchange + symbol + product, then buys and sells are added up to get net quantity, average prices and realised P&L. Live P&L uses the real price feed, like the live app.
- **Holdings** (`getHolding`): only **delivery (CNC, `prd = 'C'`)** trades with a net long quantity. MTF holdings are always empty.
- **Funds** (`getFunds`): the wallet balance, plus margin used and realised P&L worked out from open positions, returned in the same format as the real funds API.

---

## 7. The virtual wallet

- Starts at **₹10,00,000** (`VirtualWallet.defaultBalance`).
- Every debit and credit is logged with a description, for example `BUY 50 RELIANCE-EQ @ 2950.00`.
- **Add Money / Withdraw** on the Funds screen open a paper pop-up that only changes this balance. No payment gateway is involved.
- **Reset Account** (Funds screen) asks for confirmation, then puts the balance back to ₹10,00,000 and deletes all paper orders and trades (and so all positions and holdings).

---

## 8. Where data is saved

All paper data is saved in the **browser's local storage** (`SharedPreferences`):

| Key | Contents |
|---|---|
| `paper_wallet_balance` | Current virtual balance |
| `paper_wallet_transactions` | Wallet history |
| `paper_orders` | All paper orders |
| `paper_trades` | All paper trades |
| `paper_order_counter` | Used to make order numbers |

Because of this:
- Data stays when the page reloads, but it's **per browser, per device**. Another browser or computer starts fresh.
- Clearing site data wipes the paper account.
- Nothing is sent to any server, so the team can't see users' paper trades.

---

## 9. Safety — how we make sure nothing real happens

There are **four layers**. Each one would stop a real order on its own.

| # | Layer | What it stops |
|---|---|---|
| 1 | **Paper mode can't be turned off** — `const isPaperTrading = true` | The app ever switching to the live API. |
| 2 | **Hidden screens** — `paperUnavailableFeatures` + `PaperUnavailableScreen` | Users opening Mutual Funds, IPO, Bonds, Pledge or Corporate Actions from menus, cards, search or a direct link. GTT tab and Pledge buttons are hidden too. |
| 3 | **`PaperSafetyGuard`** — method level | GTT/OCO, SIP, IPO, bond, MF, payment, withdrawal, MTF transfer, UPI update and corporate action calls. Each one throws *"… is not available in paper trading mode"* before any request is made. It also makes the GTT and SIP order books return empty, so the user's **real** GTT/SIP orders are never shown. |
| 4 | **`PaperNetworkGuard`** — network level | Any request to an order, payment, pledge, IPO, bond or MF **order** web address. It's answered on the device with `{"stat":"Not_Ok"}` and never sent. This also covers new code from future syncs, as long as its address matches the list. |

Layer 4 has a unit test: `test/paper_network_guard_test.dart` (`flutter test test/paper_network_guard_test.dart`).

---

## 10. Pulling in updates from Mynt-Plus-Web

The real order and payment code is **kept, not deleted**, so merges stay small.

```bash
git fetch web main
git merge web/main          # resolve conflicts, keep the paper hooks
flutter pub get
flutter analyze             # must show 0 errors
flutter test test/paper_network_guard_test.dart
```

After every sync, check:
1. **Did `PaperApiExporter` break?** If the web code changed a method's parameters (for example `getHolding({String prd})`), update the paper version to match. `flutter analyze` reports these as `invalid_override`.
2. **New order or money API?** Add a blocking override to `paper_safety_guard.dart` **and** its address to `paper_network_guard.dart`, unless the paper engine simulates it.
3. **New real-money screen?** Add its `ScreenType` to `paperUnavailableFeatures` and hide its menu entry.

---

## 11. Known gaps

These are how the engine behaves **today**, and worth fixing next:

1. **Pending orders never fill later.** `PaperOrderEngine.onLtpUpdate()` exists but nothing calls it. A Limit or SL order that doesn't fill when placed stays PENDING until it's cancelled. **Fix:** call `onLtpUpdate` from the live price feed (WebSocket provider) for symbols with pending orders.
2. **Limit orders always fill straight away.** For Limit orders the exporter passes the limit price as the "current price", so the fill check always passes. **Fix:** pass the real live price (from the WebSocket data) into `placeOrder`.
3. **Market orders can fill at a made-up price.** If a market order arrives with price `0` and there's no simulated price, it fills at a placeholder **₹100.00**. Most screens send the live price, so this is rare. **Fix:** same as #2, use the live feed.
4. **Margin is simplified.** F&O selling uses about **10 × premium** as margin; there's no SPAN or exposure calculation. Brokerage and charges are estimates.
5. **No GTT, baskets-as-GTT, SIP, IPO, bonds or MF** in paper mode. They're hidden, not simulated.
6. **The old mobile screens (`lib/screens/Mobile/`)** still show some of these menus. Layers 1, 3 and 4 still block them, so nothing real can happen, but the menu items aren't hidden there.
7. **Paper data lives only in the browser.** There's no cloud backup and no sync between devices.
