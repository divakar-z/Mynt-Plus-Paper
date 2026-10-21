# Web — IPO BRD

**Module:** IPO — Open, Upcoming and My Bids tabs, IPO details sheet, IPO order window, bid details and cancellation
**Platform:** Web
**Owner:** Zebu Trade
**Last updated:** 2026-10-21

---

## Scope

This document covers the **IPO screen** of the web application, opened from **IPO** in the top menu. It covers the tab bar and the search box on each tab; the **Open** tab, which lists IPOs that are open for bidding, about to open and recently closed; the **IPO Details** sheet that opens from a row; the **IPO order window** where the user chooses a category, enters up to three bids, gives a UPI ID and applies; the **Upcoming** tab, which lists IPOs that have filed their draft prospectus; and the **My Bids** tab, which lists the user's applications with their status, the bid details sheet and cancelling a bid.

IPO data, bid statuses and UPI mandates come from the exchange and the backend. Several cases therefore need a real IPO in a given state (open, pre-open, closed) and a real application. The mobile app's IPO screens are out of scope.

Sections:

- **A** — Tab bar and search
- **B** — Open tab
- **C** — IPO Details sheet
- **D** — IPO order window
- **E** — Upcoming tab
- **F** — My Bids tab

Each section covers its screen end to end. Where two screens behave the same way, the case is written out in full on both sides rather than pointing from one section to the other.

---

# SECTION A — TAB BAR AND SEARCH

> **Note for the tester:** each tab has its own search box. Changing tabs in any way — clicking a tab, swiping, or arriving on a tab after placing a bid — clears every search.

### IPO-001 — The IPO tab bar

**Description:**
The IPO screen opens from **IPO** in the top menu. Three tabs run along the top — **Open**, **Upcoming** and **My Bids** — with a search box at the right. This case verifies the tabs, which one is selected when the screen opens, the search box shown on each tab, that changing tabs clears the search, and that the screen returns to the last tab viewed.

**Test Steps:**

1. After logging in, click **IPO** in the top menu for the first time. Note the tabs and which one is selected.
2. Note the search box at the right of the tab bar.
3. Click **Upcoming**. Note the search box. Then click **My Bids** and note the search box.
4. Click **Open**, type a few letters into the search box, then click **Upcoming**. Note the search box. Click **Open** again and note its search box and the list.
5. Click **My Bids**, open another screen from the top menu, then click **IPO** again. Note the selected tab.

**Expected Result:**

- Step 1: Three tabs are shown, left to right: **Open**, **Upcoming** and **My Bids**. **Open** is selected: its label is in the accent colour and underlined.
- Step 2: A search box with the hint **"Search IPO"** is shown.
- Step 3: On **Upcoming** the search box reads **"Search upcoming IPO"**. On **My Bids** it reads **"Search my bids"**. The selected tab is underlined each time.
- Step 4: The Upcoming search box is empty. Back on **Open**, its search box is empty too and the full list is shown; the text typed earlier has been cleared.
- Step 5: **My Bids** is selected; the IPO screen opens on the tab the user last viewed.

---

### IPO-002 — Searching the Open tab

**Description:**
The **Search IPO** box on the Open tab narrows the table by company name. It searches the open and pre-open IPOs and the closed IPOs in the same table. This case verifies the match rule, that the search starts from the first letter, the message when nothing matches, and clearing the box.

**Test Steps:**

1. Open the **Open** tab with at least one open IPO and one closed IPO listed. Note the rows.
2. Type the first letter of an open IPO's name. Note the table.
3. Type more of the same name in lower case. Note the table.
4. Clear the box and type part of a closed IPO's name. Note the table.
5. Type text that matches no IPO, for example **xyz**. Note the table area.
6. Click the clear (X) control in the search box. Note the table.
7. Type a few letters again, then delete them one by one with backspace until the box is empty. Note the table.

**Expected Result:**

- Step 1: Open and pre-open IPOs are listed first, followed by closed IPOs.
- Step 2: The table narrows from the first letter to IPOs whose name contains that letter.
- Step 3: Only IPOs whose name contains the typed text are shown. The search ignores upper and lower case, and the text can match anywhere in the name.
- Step 4: The matching closed IPO is shown, with its **Closed** status.
- Step 5: The table is replaced by the message **"No Data Found"** with the line **"We couldn't find any data here."** and an **Explore** button.
- Step 6: The box is empty and the full table is shown again.
- Step 7: The full table is shown again as soon as the box is empty.

---

### IPO-003 — Searching the Upcoming tab

**Description:**
The **Search upcoming IPO** box on the Upcoming tab narrows the Upcoming table. This case verifies what the search matches, the message when nothing matches, and clearing the box.

**Test Steps:**

1. Open the **Upcoming** tab. Note the number of rows.
2. Type part of a company name from the list, in lower case. Note the table.
3. Type text that matches no company, for example **xyz**. Note the table area.
4. Click the clear (X) control in the search box. Note the table.
5. Type a few letters, then delete them with backspace until the box is empty. Note the table.
6. Type a few letters, then click the **Open** tab and come back to **Upcoming**. Note the search box and the table.

**Expected Result:**

- Step 1: The full list of upcoming IPOs is shown.
- Step 2: The table narrows as the user types to companies whose name (or IPO type) contains the text. The search ignores upper and lower case and can match anywhere in the name.
- Step 3: The table is replaced by the message **"No Data Found"** with the line **"We couldn't find any data here."** and an **Explore** button.
- Step 4: The box is empty and the full table is shown again.
- Step 5: The full table is shown again as soon as the box is empty.
- Step 6: The search box is empty and the full table is shown.

---

### IPO-004 — Searching the My Bids tab

**Description:**
The **Search my bids** box on the My Bids tab narrows both the Open orders and the Close orders tables. This case verifies what the search matches, the counts on the two sub-tabs, the message when nothing matches, and that the search is cleared when the user switches between Open orders and Close orders.

**Test Steps:**

1. Open the **My Bids** tab with bids in both **Open orders** and **Close orders**. Note the counts next to the two sub-tab labels.
2. Type part of the company name of one of the bids. Note the table and the counts.
3. Type part of a bid's symbol instead. Note the table.
4. With text in the box, switch from **Open orders** to **Close orders**. Note the search box and the table.
5. Type text that matches no bid, for example **xyz**. Note the area below the tab bar.
6. Click the clear (X) control in the search box. Note the area.

**Expected Result:**

- Step 1: Each sub-tab label is followed by the number of bids in it.
- Step 2: Only bids whose company name contains the text are shown. The search ignores upper and lower case. The counts change to the number of matching bids in each sub-tab.
- Step 3: Bids whose symbol contains the text are shown.
- Step 4: The search box is emptied and the full Close orders list is shown.
- Step 5: The Open orders / Close orders switch and the tables are replaced by the message **"No Data Found"** with the line **"We couldn't find any data here."** and an **Explore** button.
- Step 6: The box is empty and the Open orders / Close orders switch and the full lists are shown again.

---

# SECTION B — OPEN TAB

> **Note for the tester:** an IPO's status is worked out from today's date and its bidding dates: **Open** between the first and last bidding day, **Pre-open** before the first day, **Closed** after the last day. Closed IPOs in this table are recently closed issues sent separately by the backend.

### IPO-005 — The Open table and its columns

**Description:**
The Open tab shows a table of IPOs with five columns. This case verifies the columns and what each one shows for an open or pre-open IPO.

**Test Steps:**

1. Open the **IPO** screen on the **Open** tab. Note the column headings, left to right.
2. Look at the **Stock name** cell of an open IPO. Note the two lines of text.
3. Note the **Status** cell.
4. Note the **IPO date** cell of an IPO whose bidding runs within one month, and of one whose bidding runs across two months, if listed.
5. Note the **Price range** cell.
6. Note the **Min. amount** cell.

**Expected Result:**

- Step 1: The columns are **Stock name**, **Status**, **IPO date**, **Price range** and **Min. amount**.
- Step 2: The first line is the company name with each word starting with a capital letter. The second line shows the scrip symbol (when available) followed by **Main** for a Mainboard issue or **SME** for an SME issue.
- Step 3: A coloured badge reads **Open** or **Pre-open**.
- Step 4: Dates are shown with day suffixes. Within one month: for example **21st - 23rd Oct 2026**. Across two months: for example **28th Nov 2025 - 1st Dec 2025**. A one-day issue shows one date. When a date is missing, **-** is shown.
- Step 5: The lowest and highest price of the band, for example **₹1065 - ₹1119**. Whole prices are shown without decimals; prices with paise are shown with two decimals.
- Step 6: The minimum investment (lowest price multiplied by the minimum bid quantity), for example **₹12,780**, with the lot size below it in smaller text, for example **12 Qty**. When either value is missing, **-** is shown.

---

### IPO-006 — Default order of the rows

**Description:**
Before any column is sorted, the Open table lists IPOs in a fixed order by status. This case verifies that order.

**Test Steps:**

1. Open the **Open** tab with open, pre-open and closed IPOs listed. Do not click any column heading. Note the order of the rows by status.
2. Note the order of the open IPOs among themselves.
3. Note whether any column heading shows a sort arrow.

**Expected Result:**

- Step 1: Open IPOs come first, then Pre-open IPOs, then Closed IPOs.
- Step 2: Open IPOs (and pre-open IPOs) are listed by bidding start date, earliest first. Closed IPOs follow in the order the backend sends them.
- Step 3: No heading shows a sort arrow.

---

### IPO-007 — The Status badge

**Description:**
The **Status** column shows each IPO's status as a coloured badge. The same three colours are used on every IPO screen. This case verifies the badge for each status.

**Test Steps:**

1. On the **Open** tab, look at the Status cell of an IPO that is open for bidding today.
2. Look at the Status cell of an IPO whose bidding starts on a later date.
3. Look at the Status cell of a closed IPO.

**Expected Result:**

- Step 1: A green badge reads **Open**.
- Step 2: A grey badge reads **Pre-open**.
- Step 3: A red badge reads **Closed**.

---

### IPO-008 — Closed IPO rows

**Description:**
Recently closed IPOs are listed at the bottom of the Open table. They show the same columns as open IPOs, with a few differences. This case verifies what a closed row shows and that it offers no Apply action.

**Test Steps:**

1. On the **Open** tab, scroll to the closed IPOs. Look at the **Stock name** cell of a closed Mainboard IPO and of a closed SME IPO.
2. Note the **Status**, **IPO date**, **Price range** and **Min. amount** cells.
3. Hover over a closed row. Note the right end of the Stock name cell.
4. Click the closed row.

**Expected Result:**

- Step 1: The first line is the company name with each word capitalised. The second line reads **Main** for a Mainboard issue or **SME** for an SME issue, followed by the subscription, for example **12.5x sub**, when the backend sends one.
- Step 2: Status shows a red **Closed** badge. IPO date shows the bidding dates in the same style as open rows, for example **14th - 16th Oct 2026**. Price range shows the price the backend sends, for example **₹289.00**; when it sends a range, both ends are shown. Min. amount shows the price multiplied by the minimum bid quantity with the quantity below it, for example **₹14,739** and **51 Qty**.
- Step 3: The row is highlighted, but no three-dot menu appears; a closed IPO cannot be applied for.
- Step 4: The **IPO Details** sheet opens for that IPO.

---

### IPO-009 — Sorting the Open table

**Description:**
Four of the column headings can be clicked to sort the table: **Stock name**, **Status**, **IPO date** and **Min. amount**. The first click sorts in ascending order, a second click on the same heading reverses it, and an arrow beside the heading shows the direction. Closed IPOs stay together at the bottom and are sorted among themselves, except when the table is sorted by Status in descending order. This case verifies each sortable heading and the heading that does not sort.

**Test Steps:**

1. On the **Open** tab, click the **Stock name** heading. Note the order and the heading.
2. Click **Stock name** again. Note the order and the arrow.
3. Click the **Status** heading. Note the order.
4. Click **Status** again. Note the order.
5. Click the **IPO date** heading. Note the order.
6. Click **IPO date** again. Note the order.
7. Click the **Min. amount** heading. Note the order and where the arrow sits.
8. Click **Min. amount** again. Note the order.
9. Click the **Price range** heading. Note the table.
10. Click anywhere in the **Stock name** heading cell away from the label text.

**Expected Result:**

- Step 1: Open and pre-open IPOs are sorted by name A to Z, ignoring upper and lower case; closed IPOs remain below them, also sorted A to Z. An up arrow appears after **Stock name**.
- Step 2: Both groups are sorted Z to A, closed IPOs still at the bottom, and the arrow turns into a down arrow.
- Step 3: Rows are grouped Open, then Pre-open, then Closed, sorted by name within each group. The arrow moves to **Status**.
- Step 4: The order is reversed: Closed IPOs come first, then Pre-open, then Open.
- Step 5: Rows are sorted by bidding start date, earliest first (by end date when two start on the same day). Closed IPOs remain at the bottom, sorted the same way. Rows with no date go last.
- Step 6: The order is reversed, latest first; rows with no date still go last.
- Step 7: Rows are sorted by minimum amount, smallest first. Because the column is right-aligned, the arrow appears before the label. Rows showing **-** go last.
- Step 8: The order is reversed, largest first; rows showing **-** still go last.
- Step 9: Nothing changes; **Price range** cannot be sorted and shows no arrow.
- Step 10: The table sorts; the whole heading cell can be clicked, not only the label.

---

### IPO-010 — Row actions menu on an open or pre-open IPO

**Description:**
Hovering over an open or pre-open IPO shows a three-dot control at the right end of the Stock name cell. It opens a menu to apply or to see the IPO's details. This case verifies the control, the menu for each status, and each menu entry.

**Test Steps:**

1. On the **Open** tab, hover over an open IPO. Note the row and the Stock name cell.
2. Click the three-dot control. Note the menu.
3. Hover over a pre-open IPO and click its three-dot control. Note the menu.
4. Click **Details**.
5. Close the sheet, open the menu on an open IPO again and click **Apply**.
6. Open a menu, then move the mouse away from both the row and the menu.

**Expected Result:**

- Step 1: The row is highlighted and a three-dot control appears at the right end of the Stock name cell.
- Step 2: A menu opens with **Apply** and, below a divider, **Details**.
- Step 3: The first entry reads **Pre Apply** instead of Apply.
- Step 4: The menu closes and the **IPO Details** sheet opens for the IPO.
- Step 5: The menu closes and the **IPO order window** opens for the IPO.
- Step 6: The menu closes by itself.

---

### IPO-011 — Clicking an IPO row

**Description:**
Clicking anywhere on an IPO row — on any column — opens the IPO Details sheet. This case verifies the click and that a second click while the sheet is loading does not open a second sheet.

**Test Steps:**

1. On the **Open** tab, click the **IPO date** cell of an open IPO.
2. Close the sheet. Click the **Min. amount** cell of a closed IPO.
3. Close the sheet. Click a row twice quickly.

**Expected Result:**

- Step 1: The **IPO Details** sheet slides in from the right for that IPO.
- Step 2: The **IPO Details** sheet opens for the closed IPO.
- Step 3: Only one sheet opens.

---

# SECTION C — IPO DETAILS SHEET

### IPO-012 — The IPO Details sheet header and company block

**Description:**
The IPO Details sheet slides in from the right when the user clicks an IPO. Its top part shows the company and the IPO's status. This case verifies the header and the company block for an open, a pre-open and a closed IPO.

**Test Steps:**

1. On the **Open** tab, click an open Mainboard IPO. Note the header of the sheet.
2. Note the company name, the line below it and the round image on the right.
3. Close the sheet with the close (X) control. Open the sheet for a pre-open IPO and note the badge.
4. Open the sheet for a closed Mainboard IPO and for a closed SME IPO. Note the line below the name and the badge.
5. Open the sheet for an IPO with no company logo. Note the round image.

**Expected Result:**

- Step 1: The header shows a close (X) control and the title **IPO Details**.
- Step 2: The company name is shown as given by the IPO details service, for example **Jio Platforms Ltd.** Below it the type reads **Main** (Mainboard) or **SME**, followed by a green **OPEN** badge. The company logo is shown in a circle on the right.
- Step 3: The sheet closes. For the pre-open IPO the badge is grey and reads **PRE-OPEN**.
- Step 4: The badge is red and reads **CLOSED**. The type reads **Main** for a closed Mainboard IPO and **SME** for a closed SME IPO.
- Step 5: The circle shows the company's initials (the first letters of the first two words of the name).

---

### IPO-013 — The Apply button in the IPO Details sheet

**Description:**
For an open or pre-open IPO, the IPO Details sheet has a full-width button that opens the IPO order window. Closed IPOs have no button. This case verifies the button label for each status and what clicking it does.

**Test Steps:**

1. Open the IPO Details sheet for an open IPO. Note the button below the company block.
2. Open the sheet for a pre-open IPO. Note the button.
3. Open the sheet for a closed IPO. Note the area below the company block.
4. Open the sheet for an open IPO and click **Apply**.

**Expected Result:**

- Step 1: A full-width button reads **Apply**.
- Step 2: The button reads **Pre Apply**.
- Step 3: No button is shown; the details list follows directly.
- Step 4: The IPO order window opens for the IPO and the IPO Details sheet closes.

---

### IPO-014 — The details list in the IPO Details sheet

**Description:**
Below the company block, the sheet lists the IPO's key facts, one per row, with the label on the left and the value on the right. Most values come from the IPO details service. This case verifies each row.

**Test Steps:**

1. Open the IPO Details sheet for an open IPO. Note the rows, top to bottom.
2. Note the value on each row.
3. Open the sheet for a closed IPO. Note the **Min amount** and **Price range** rows.
4. For any row the service sends no value for, note what is shown.

**Expected Result:**

- Step 1: The rows are **Min amount**, **Lot size**, **Price range**, **Date**, **Issue size**, **Listing at**, **Listing date** and **RHP Doc**.
- Step 2: **Min amount** is the lowest price multiplied by the minimum bid quantity, for example **₹12,780**. **Lot size** is the lot, for example **12**. **Price range** is the band, for example **₹1065 - ₹1119**. **Date** is the bidding period, for example **21 Oct - 23 Oct 2026**. **Issue size** is the total number of shares, for example **270000000 Shares**. **Listing at** is the exchanges, for example **BSE, NSE**. **Listing date** is the listing date or **Not yet listed**.
- Step 3: **Min amount** is the closed IPO's price multiplied by its minimum bid quantity, for example **₹14,739**. **Price range** shows the price the backend sends, for example **₹289.00**.
- Step 4: The row shows **--**.

---

### IPO-015 — The RHP document link

**Description:**
The last row of the details list, **RHP Doc**, links to the Red Herring Prospectus when the IPO details service provides one. This case verifies the link and the row when there is no document.

**Test Steps:**

1. Open the IPO Details sheet for an IPO with a prospectus. Note the **RHP Doc** row.
2. Click **Download**.
3. Open the sheet for an IPO without a prospectus. Note the row.

**Expected Result:**

- Step 1: The value reads **Download** in the accent (link) colour.
- Step 2: The prospectus opens in a new browser tab, or downloads, depending on the file (for example a PDF or a ZIP file).
- Step 3: The value reads **--** in normal text and does nothing when clicked.

---

### IPO-016 — IPO Details sheet when no details are available

**Description:**
When the IPO details service returns nothing for an IPO, the sheet cannot show the details list. This case verifies the message shown instead.

**Test Steps:**

1. Click an IPO for which the IPO details service returns no data. Note the sheet.
2. If the IPO is open, note whether the Apply button is still shown.

**Expected Result:**

- Step 1: The header and company block are shown. In place of the details list a message reads **"No Details Available"** with the line **"IPO details are not available at the moment."**
- Step 2: The **Apply** (or **Pre Apply**) button is still shown above the message.

---

# SECTION D — IPO ORDER WINDOW

> **Note for the tester:** the order window opens from **Apply** / **Pre Apply** in the row menu or in the IPO Details sheet. Validation messages appear in red under the field they refer to. Messages from the server appear as toasts. The examples below use a Mainboard IPO with a price band of ₹1065 to ₹1119, a lot and minimum bid of 12 shares and a UPI limit of ₹5,00,000 for Individual; use the values of the IPO being tested.

### IPO-017 — Opening the IPO order window

**Description:**
The IPO order window opens over a dimmed page. It can be moved by dragging its header and is closed with its close control. This case verifies the window's header, its layout, moving it and closing it.

**Test Steps:**

1. Open the row menu on an open IPO and click **Apply**. Note the page behind and the window's header.
2. Note the parts of the window from top to bottom.
3. Press and hold on the header and drag the window. Try to drag it past the edge of the screen.
4. Click on the dimmed page outside the window.
5. Click the close (X) control at the top right of the window.

**Expected Result:**

- Step 1: The page behind is dimmed. The header shows the IPO name; below it **Main** (Mainboard) or **SME** and a status badge — green **OPEN**, or grey **PRE-OPEN** for Pre Apply. A close (X) control is at the right.
- Step 2: The window shows **Category**, then the bid row (**Qty** and **Bid Price**), **Add another bid**, **UPI ID (Virtual payment address)**, the declaration checkbox, and at the foot the **Margin** line and the **Continue** button.
- Step 3: The cursor changes to a move cursor over the header and the window follows the mouse. It cannot be dragged off the screen.
- Step 4: Nothing happens; the window stays open.
- Step 5: The window closes and the page is no longer dimmed.

---

### IPO-018 — The Category dropdown

**Description:**
The **Category** dropdown sets the investor category the bid is placed under. Only categories that allow UPI payment for the IPO are offered, in a fixed order, and each category carries its own maximum investment. This case verifies the options, the default, and what changes when the category is changed.

**Test Steps:**

1. Open the order window for an IPO. Note the value in the **Category** dropdown.
2. Open the dropdown. Note the options and their order.
3. Choose **HNI** (if offered) with the default bid. Note the message under the Qty field.
4. Increase the quantity so the bid amount is above ₹2,00,000. Note the message.
5. Choose **Individual** again with a bid amount above the Individual UPI limit. Note the message.
6. With **Cut-off** ticked, change to a category where cut-off is not allowed. Note the Bid Price field and the Cut-off checkbox.

**Expected Result:**

- Step 1: The first available category is selected, normally **Individual**.
- Step 2: The options appear in this order, showing only those the IPO allows with UPI: **Individual**, **HNI**, **Employee**, **Shareholder**, **Policyholder**.
- Step 3: The message **"Minimum investment for HNI is above ₹200000"** appears under the Qty field.
- Step 4: The message disappears.
- Step 5: The message **"Maximum investment upto ₹500000 only"** appears under the Qty field.
- Step 6: The Cut-off checkbox disappears and the Bid Price field is unlocked and reset to the lowest price of the band.

---

### IPO-019 — The default bid

**Description:**
When the order window opens, it holds one bid already filled with the minimum quantity and the lowest price of the band. This case verifies the starting values and the margin shown for them.

**Test Steps:**

1. Open the order window for an IPO. Note the **Qty** field.
2. Note the **Bid Price** field and the **Cut-off** checkbox.
3. Note the **Margin** line at the foot of the window.
4. Note the **UPI ID** field.

**Expected Result:**

- Step 1: Qty holds the minimum bid quantity, for example **12**.
- Step 2: Bid Price holds the lowest price of the band with a **₹** before it, for example **₹ 1065**. Cut-off is not ticked.
- Step 3: The line reads **Margin · 12780.00** — the bid price multiplied by the quantity.
- Step 4: The field is filled with the user's UPI ID when one is saved on the account; otherwise it is empty and shows the hint **"Add UPI ID"**.

---

### IPO-020 — Typing in the Qty field

**Description:**
The **Qty** field accepts digits only. As the user types, the quantity is checked and a message appears under the field. This case verifies every quantity message and that each disappears when the quantity is valid.

**Test Steps:**

1. In the order window, clear the **Qty** field. Note the message.
2. Type **0**. Note the message.
3. Type a quantity below the minimum, for example **6**. Note the message.
4. Type a quantity that is above the minimum but not a multiple of the lot, for example **13**. Note the message.
5. Type a quantity whose amount is above the category's maximum investment, for example **480** at ₹1065. Note the message.
6. Choose **HNI** and type a quantity whose amount is below ₹2,00,000, for example **24**. Note the message.
7. Choose **Individual** and type a valid quantity, for example **24**. Note the message and the Margin line.
8. Try to type a letter or a decimal point.

**Expected Result:**

- Step 1: **"Value is required"** is shown under the Qty field.
- Step 2: **"Value cannot be 0"** is shown.
- Step 3: **"Minimum Bid quantity is 12 only"** is shown.
- Step 4: **"Quantity must be in multiples of 12"** is shown.
- Step 5: **"Maximum investment upto ₹500000 only"** is shown.
- Step 6: **"Minimum investment for HNI is above ₹200000"** is shown.
- Step 7: The message disappears and the Margin line updates, for example **Margin · 25560.00**.
- Step 8: Nothing is typed; the field takes digits only.

---

### IPO-021 — The + and − buttons on the Qty field

**Description:**
The **−** and **+** buttons on either side of the Qty field change the quantity by one lot. A quantity that is not a multiple of the lot is first moved to the nearest multiple. The quantity never goes below the minimum bid. This case verifies each case of the two buttons.

**Test Steps:**

1. With Qty at **12** and a lot of 12, click **+**. Note the quantity and the Margin line.
2. Click **−**. Note the quantity.
3. Click **−** again. Note the quantity.
4. Type **13** and click **+**. Note the quantity. Type **25** and click **−**. Note the quantity.
5. Clear the Qty field so **"Value is required"** shows, then click **+**. Note the quantity and the message.
6. Type **0** and click **−**. Note the quantity and the message.
7. Raise the quantity with **+** until the amount is above the maximum investment. Note the message.

**Expected Result:**

- Step 1: The quantity becomes **24** and the Margin line updates.
- Step 2: The quantity goes back to **12**.
- Step 3: The quantity stays at **12**; it does not go below the minimum bid.
- Step 4: **13** with **+** becomes **24**; **25** with **−** becomes **24**.
- Step 5: The quantity becomes the minimum bid, **12**, and the message disappears.
- Step 6: The quantity becomes **12** and the message disappears.
- Step 7: **"Maximum investment upto ₹500000 only"** is shown under the Qty field.

---

### IPO-022 — Typing in the Bid Price field

**Description:**
The **Bid Price** field takes the price per share the user bids, in whole rupees. It must be inside the IPO's price band. As the user types, the price is checked and a message appears under the field. This case verifies each price message.

**Test Steps:**

1. In the order window, clear the **Bid Price** field. Note the message.
2. Type **0**. Note the message.
3. Type a price below the band, for example **8**. Note the message.
4. Type a price above the band, for example **1200**. Note the message.
5. Type a price inside the band, for example **1100**. Note the message and the Margin line.
6. Try to type a decimal point, for example **1100.50**. Note the field.
7. Try to type a letter.

**Expected Result:**

- Step 1: **"Value is required"** is shown under the Bid Price field.
- Step 2: **"Value cannot be 0"** is shown.
- Step 3: **"Your bid price ranges between ₹1065-₹1119"** is shown.
- Step 4: The same message, **"Your bid price ranges between ₹1065-₹1119"**, is shown.
- Step 5: The message disappears and the Margin line updates to the price multiplied by the quantity, for example **Margin · 13200.00**.
- Step 6: The decimal point is not typed. Typing **1100.50** key by key leaves **110050** in the field, which is outside the band, so the range message is shown. IPO bids are in whole rupees.
- Step 7: Nothing is typed; the field takes digits only.

---

### IPO-023 — The Cut-off checkbox

**Description:**
For categories that allow it, a **Cut-off** checkbox sits beside the Bid Price label. Ticking it bids at the cut-off price: the bid price is set to the top of the band and locked. This case verifies ticking and unticking it, and the categories where it is not shown.

**Test Steps:**

1. In the order window with **Individual** selected, note the **Cut-off** checkbox beside the Bid Price label.
2. Type an out-of-band price so the range message shows, then tick **Cut-off**. Note the Bid Price field, the message and the Margin line.
3. Try to type in the Bid Price field.
4. Untick **Cut-off**. Note the Bid Price field.
5. Choose a category where cut-off is not allowed, for example **HNI**. Note the checkbox.

**Expected Result:**

- Step 1: An unticked checkbox labelled **Cut-off** is shown.
- Step 2: Bid Price changes to the top of the band, for example **₹ 1119**, and is shown dimmed. The range message disappears. The Margin line is recalculated at the top price.
- Step 3: The field cannot be edited while Cut-off is ticked.
- Step 4: Bid Price returns to the lowest price of the band, for example **₹ 1065**, and can be edited again.
- Step 5: The Cut-off checkbox is not shown.

---

### IPO-024 — Adding and deleting bids

**Description:**
An application can carry up to three bids. **Add another bid** adds a new bid filled with the default values, and every bid after the first has its own **Delete** control. This case verifies adding up to the limit, deleting, and that the margin follows the largest bid.

**Test Steps:**

1. In the order window, click **Add another bid**. Note the new bid.
2. Click **Add another bid** again. Note the bids and the **Add another bid** link.
3. Raise the quantity of the second bid so its amount is the largest. Note the Margin line.
4. Click **Delete** under the third bid. Note the bids and the link.
5. Note whether the first bid has a Delete control.

**Expected Result:**

- Step 1: A second bid appears with the default quantity and the lowest price of the band, and a red **Delete** control below it on the right.
- Step 2: A third bid appears. The **Add another bid** link disappears; no more than three bids can be added.
- Step 3: The Margin line shows the amount of the largest bid.
- Step 4: The third bid is removed and **Add another bid** appears again.
- Step 5: The first bid has no Delete control; it cannot be removed.

---

### IPO-025 — The UPI ID field

**Description:**
The **UPI ID (Virtual payment address)** field takes the UPI ID on which the bank will raise the payment mandate. It is filled automatically when the account has a UPI ID saved. This case verifies the field and that its message clears when the user types.

**Test Steps:**

1. Open the order window as a user with a saved UPI ID. Note the field.
2. Open it as a user without a saved UPI ID. Note the field.
3. Leave the field empty and click **Continue** with valid bids, so a message appears. Then type in the field. Note the message.

**Expected Result:**

- Step 1: The field is labelled **UPI ID (Virtual payment address)** and holds the saved UPI ID.
- Step 2: The field is empty with the hint **"Add UPI ID"**.
- Step 3: The message under the field disappears as soon as the user types.

---

### IPO-026 — The declaration checkbox

**Description:**
Before applying, the user must accept a declaration about the prospectus and eligibility. This case verifies the checkbox, its text, and that its message clears when it is ticked.

**Test Steps:**

1. Open the order window. Note the checkbox below the UPI ID field and its text.
2. With valid bids and UPI ID and the box unticked, click **Continue**. Note the message.
3. Tick the box. Note the message.

**Expected Result:**

- Step 1: The checkbox is unticked. Its text reads **"I hereby undertake that I have read the Red Herring Prospectus and I am eligible bidder as per the applicable provisions of SEBI (Issue of Capital & Disclosure Agreement, 2009) regulations"**.
- Step 2: **"Please accept the declaration to continue"** is shown in red under the declaration.
- Step 3: The message disappears.

---

### IPO-027 — The Margin line

**Description:**
The **Margin** line at the foot of the order window shows the amount that will be blocked through the UPI mandate: the amount of the largest bid. This case verifies the value as bids change.

**Test Steps:**

1. Open the order window with the default bid. Note the Margin line.
2. Change the quantity to **24**. Note the line.
3. Add a second bid and leave it at the default. Note the line.
4. Raise the second bid's quantity to **36**. Note the line.
5. Tick **Cut-off** on the second bid. Note the line.

**Expected Result:**

- Step 1: **Margin · 12780.00** (₹1065 multiplied by 12), shown in the accent colour.
- Step 2: **Margin · 25560.00**.
- Step 3: The line stays at **25560.00**; the margin is the largest bid, not the total.
- Step 4: **Margin · 38340.00**.
- Step 5: **Margin · 40284.00** (₹1119 multiplied by 36).

---

### IPO-028 — Continue: empty or zero bid price and quantity

**Description:**
The **Continue** button can always be clicked while no application is being sent. Clicking it first checks every bid for an empty or zero bid price and quantity and shows a message under each field that fails. This case verifies those messages.

**Test Steps:**

1. In the order window, clear the **Bid Price** field and click **Continue**. Note the message under Bid Price.
2. Type **0** into Bid Price and click **Continue**. Note the message.
3. Enter a valid price. Clear the **Qty** field and click **Continue**. Note the message under Qty.
4. Type **0** into Qty and click **Continue**. Note the message.
5. Add a second bid, clear the second bid's price and quantity, and click **Continue**. Note both bids.

**Expected Result:**

- Step 1: No application is sent. **"Bid Price Value is required"** is shown under Bid Price.
- Step 2: **"Bid Price Value cannot be 0"** is shown.
- Step 3: **"Quantity cannot be empty"** is shown under Qty.
- Step 4: **"Quantity cannot be 0"** is shown.
- Step 5: The messages are shown under the second bid's fields; every bid is checked, not only the last one.

---

### IPO-029 — Continue: other bid errors

**Description:**
After the empty and zero checks, **Continue** stops if any bid still shows a message under its fields — for example a price outside the band or a quantity below the minimum. This case verifies that an application with such a bid is not sent.

**Test Steps:**

1. In the order window, type a bid price outside the band so **"Your bid price ranges between ₹1065-₹1119"** shows. Fill a valid UPI ID and tick the declaration. Click **Continue**.
2. Correct the price. Type a quantity below the minimum so **"Minimum Bid quantity is 12 only"** shows, then click **Continue**.

**Expected Result:**

- Step 1: No application is sent and the message under Bid Price stays.
- Step 2: No application is sent and the message under Qty stays.

---

### IPO-030 — Continue: UPI ID checks

**Description:**
With valid bids, **Continue** checks the UPI ID before anything is sent. This case verifies the message for an empty UPI ID and for one in the wrong format.

**Test Steps:**

1. With valid bids, clear the **UPI ID** field and click **Continue**. Note the message.
2. Type a UPI ID without the **@** part, for example **testupi**, and click **Continue**. Note the message.
3. Type a UPI ID with a space, for example **test upi@okaxis**, and click **Continue**. Note the message.

**Expected Result:**

- Step 1: No application is sent. **"UPI ID cannot be empty"** is shown in red under the UPI ID field.
- Step 2: **"Invalid UPI ID format"** is shown under the field.
- Step 3: **"Invalid UPI ID format"** is shown. A UPI ID must be letters, digits, dots, hyphens or underscores, then **@**, then letters or digits.

---

### IPO-031 — Continue: declaration not accepted

**Description:**
With valid bids and UPI ID, **Continue** checks that the declaration is ticked. This case verifies the message.

**Test Steps:**

1. With valid bids and a valid UPI ID, leave the declaration unticked and click **Continue**.
2. Tick the declaration.

**Expected Result:**

- Step 1: No application is sent. **"Please accept the declaration to continue"** is shown in red under the declaration.
- Step 2: The message disappears.

---

### IPO-032 — Continue: maximum investment

**Description:**
**Continue** refuses an application whose bid amount is above the maximum investment allowed for the chosen category. This case verifies the warning.

**Test Steps:**

1. With **Individual** selected, set the only bid's quantity so its amount is above ₹5,00,000. Click **Continue**.
2. Add a second bid at the default values, set the first bid above ₹5,00,000 and the second within the limit, and click **Continue**.

**Expected Result:**

- Step 1: No application is sent. A warning toast reads **"Maximum investment upto ₹500000 only"**, and the same text is shown under the Qty field.
- Step 2: No application is sent. The same warning toast, **"Maximum investment upto ₹500000 only"**, is shown; every bid is checked, not only the last one.

---

### IPO-033 — Applying for an IPO

**Description:**
When every check passes, **Continue** verifies the UPI ID with the bank and then sends the application. On success the window closes and the user is taken to My Bids. This case verifies a successful application, a UPI ID the bank does not recognise, and what the user sees while the request runs.

**Test Steps:**

1. Fill valid bids, a valid UPI ID and tick the declaration. Click **Continue**. Note the button while the request runs.
2. Note the message, the window and the tab shown when it completes.
3. Open **My Bids** → **Open orders**. Note the new application.
4. Repeat with a UPI ID in the right format that the bank does not recognise, for example **nobody123@okaxis**. Click **Continue**.

**Expected Result:**

- Step 1: The **Continue** label is replaced by a small loader and the button cannot be clicked.
- Step 2: A toast shows the server's message, or **"Order placed successfully"** when the server sends none. The order window closes and the IPO screen switches to the **My Bids** tab.
- Step 3: In **My Bids** → **Open orders**, the new application is listed with status **SUCCESS** or **PENDING**.
- Step 4: No application is sent and the window stays open. A warning toast reads **"Invalid UPI ID"**.

---

# SECTION E — UPCOMING TAB

### IPO-034 — The Upcoming table and its columns

**Description:**
The Upcoming tab lists companies that have filed their draft prospectus (DRHP) and are expected to come to market. This case verifies the columns, what each shows and the default order.

**Test Steps:**

1. Click the **Upcoming** tab. Note the column headings, left to right.
2. Note what each column shows for a row.
3. Note the order of the rows before any heading is clicked, and whether any heading shows a sort arrow.
4. Hover over a row.

**Expected Result:**

- Step 1: The columns are **Stock name**, **Issue Size**, **Last Updated**, **Stock Exchanges**, and a last column with no heading.
- Step 2: Stock name is the company name, for example **Hero Fincorp Ltd.** Issue Size is the figure sent by the backend, for example **3668.13**. Last Updated is a date such as **22-May-2025**. Stock Exchanges is, for example, **BSE, NSE**. The last column shows a blue **DRHP** link, or **-** when no DRHP is available.
- Step 3: Rows are in the order the backend sends them, and no heading shows a sort arrow.
- Step 4: The row is highlighted.

---

### IPO-035 — Sorting the Upcoming table

**Description:**
The four labelled headings of the Upcoming table can be clicked to sort it. The first click sorts in ascending order, a second click on the same heading reverses it, and an arrow beside the heading shows the direction. This case verifies each heading.

**Test Steps:**

1. On the **Upcoming** tab, click **Stock name**. Note the order and the heading.
2. Click **Stock name** again. Note the order.
3. Click **Issue Size**. Note the order.
4. Click **Last Updated**. Note the order.
5. Click **Last Updated** again. Note the order.
6. Click **Stock Exchanges**. Note the order.
7. Click the heading of the last column (the DRHP column).

**Expected Result:**

- Step 1: Rows are sorted by company name A to Z, ignoring upper and lower case. An up arrow appears after **Stock name**.
- Step 2: Rows are sorted Z to A and the arrow turns into a down arrow.
- Step 3: Rows are sorted by issue size as a number, smallest first — for example **999.0** comes before **1000.0**. The arrow moves to Issue Size.
- Step 4: Rows are sorted by date, oldest first — for example **15-Apr-2025**, **29-Apr-2025**, **15-May-2025**. Rows with no date go last.
- Step 5: Rows are sorted newest first; rows with no date still go last.
- Step 6: Rows are sorted by the exchange text, A to Z.
- Step 7: Nothing changes; the last column cannot be sorted.

---

### IPO-036 — The DRHP link

**Description:**
Each Upcoming row has a blue **DRHP** link in its last column. Clicking the link — or anywhere on the row — opens the draft prospectus page in a new browser tab. This case verifies the link, the row click and a row without a DRHP.

**Test Steps:**

1. On the **Upcoming** tab, click the **DRHP** link on a row.
2. Return to the app and click the **Last Updated** cell of another row.
3. Find a row that shows **-** in the last column, if any. Hover over it and click it.

**Expected Result:**

- Step 1: The DRHP page opens in a new browser tab.
- Step 2: The DRHP page for that row opens in a new browser tab.
- Step 3: The cursor stays a normal pointer and nothing opens.

---

# SECTION F — MY BIDS TAB

> **Note for the tester:** a bid is listed under **Open orders** while its status is success or pending, and under **Close orders** once it is cancelled or has failed.

### IPO-037 — The My Bids tab

**Description:**
The My Bids tab lists the user's IPO applications in two sub-tabs, **Open orders** and **Close orders**. This case verifies the sub-tabs, their counts, the default sub-tab and the screen shown when the user has no applications.

**Test Steps:**

1. As a user with no IPO applications, click **My Bids**. Note the area below the tab bar.
2. As a user with open and closed applications, click **My Bids**. Note the sub-tabs and which one is selected.
3. Note the number next to each sub-tab label.
4. Click **Close orders**. Note the sub-tab and the table.
5. As a user with open applications but no closed ones, note the **Close orders** label.

**Expected Result:**

- Step 1: The message **"No Data Found"** with the line **"We couldn't find any data here."** and an **Explore** button is shown.
- Step 2: Two sub-tabs are shown, **Open orders** and **Close orders**. **Open orders** is selected (shown highlighted, with its label in bold).
- Step 3: Each label is followed, slightly raised, by the number of applications in it.
- Step 4: **Close orders** becomes highlighted and the closed applications are shown.
- Step 5: **Close orders** shows no number.

---

### IPO-038 — The Open orders table

**Description:**
The Open orders table lists applications that are live. This case verifies the columns, what each one shows and the default order.

**Test Steps:**

1. Open **My Bids** → **Open orders**. Note the column headings, left to right.
2. Note the **Date** cell of a row.
3. Note the **Amount** cell of an application with one bid and of one with several bids.
4. Note the **Status** cell of a successful application and of a pending one.
5. Note the order of the rows before any heading is clicked.

**Expected Result:**

- Step 1: The columns are **Date**, **Stock name**, **Amount** and **Status**.
- Step 2: The date and time the application was received, for example **21-10-2026 - 10:15 AM**, or **----** when not available.
- Step 3: For one bid, the bid amount, for example **12,780**. For several bids, the amount of the largest bid.
- Step 4: A green badge reads **SUCCESS**; an amber badge reads **PENDING**.
- Step 5: Rows are listed newest first.

---

### IPO-039 — Sorting the Open orders table

**Description:**
All four headings of the Open orders table can be clicked to sort it. The first click sorts in ascending order, a second click on the same heading reverses it, and an arrow beside the heading shows the direction. This case verifies each heading.

**Test Steps:**

1. In **Open orders**, click **Date**. Note the order and the heading.
2. Click **Date** again. Note the order.
3. Click **Stock name**. Note the order.
4. Click **Amount**. Note the order.
5. Click **Status**. Note the order.

**Expected Result:**

- Step 1: Rows are sorted oldest first and an up arrow appears after **Date**.
- Step 2: Rows are sorted newest first and the arrow turns into a down arrow.
- Step 3: Rows are sorted by company name A to Z, ignoring upper and lower case. The arrow moves to Stock name.
- Step 4: Rows are sorted by amount as a number, smallest first — for example **9,000** comes before **15,000**.
- Step 5: **SUCCESS** rows come before **PENDING** rows.

---

### IPO-040 — Row actions on an open order

**Description:**
Hovering over an open order shows a three-dot control at the right end of the Stock name cell. Its menu offers **Cancel** when the application can still be cancelled, and **Info**. A pending application can always be cancelled; a successful one only while the IPO is still open for bidding. Clicking anywhere on the row opens the Order Details sheet. This case verifies the menu for each situation.

**Test Steps:**

1. In **Open orders**, hover over a **PENDING** application and click its three-dot control. Note the menu.
2. Hover over a **SUCCESS** application for an IPO that is open today and click its three-dot control. Note the menu.
3. Hover over a **SUCCESS** application for an IPO whose bidding has ended and click its three-dot control. Note the menu.
4. Click **Info**.
5. Close the sheet and click the **Amount** cell of any row.
6. Open a menu and click **Cancel**.

**Expected Result:**

- Step 1: The row is highlighted. The menu shows **Cancel** (with a red icon) and, below a divider, **Info**.
- Step 2: The menu shows **Cancel** and **Info**.
- Step 3: The menu shows only **Info**; the application can no longer be cancelled.
- Step 4: The menu closes and the **Order Details** sheet opens for the application.
- Step 5: The **Order Details** sheet opens.
- Step 6: The **Cancel IPO Order** dialog opens.

---

### IPO-041 — Cancelling an application

**Description:**
**Cancel** on an open order asks the user to confirm, then sends the cancellation. This case verifies the dialog, closing it without cancelling, and a confirmed cancellation.

**Test Steps:**

1. In **Open orders**, open the menu on a cancellable application and click **Cancel**. Note the dialog.
2. Click the close (X) control at the top right. Note the table.
3. Open the dialog again and click **Cancel Order**. Note the button while the request runs.
4. Note the message, the dialog and the table when it completes.
5. Open **Close orders**. Look for the application.

**Expected Result:**

- Step 1: A dialog titled **Cancel IPO Order** opens with the text **"Are you sure you want to cancel this IPO order? This action cannot be undone."** and a red **Cancel Order** button.
- Step 2: The dialog closes and the application is still listed.
- Step 3: The button shows a small loader and cannot be clicked again.
- Step 4: A toast shows the server's message confirming the cancellation. The dialog closes and My Bids refreshes.
- Step 5: After a successful cancellation the application is listed under Close orders with status **CANCELLED**.

---

### IPO-042 — The Close orders table

**Description:**
The Close orders table lists applications that were cancelled or failed. This case verifies the columns, the statuses, the menu and the default order.

**Test Steps:**

1. Open **My Bids** → **Close orders**. Note the column headings.
2. Note the **Status** cell of a cancelled application and of a failed one.
3. Note the **Amount** cell of an application with several bids.
4. Hover over a row and click its three-dot control. Note the menu. Click **Info**.
5. Close the sheet and click any cell of a row.
6. Note the order of the rows before any heading is clicked.
7. Click each heading in turn, then the same heading again.

**Expected Result:**

- Step 1: The columns are **Date**, **Stock name**, **Amount** and **Status**, as in Open orders.
- Step 2: A cancelled application shows an amber **CANCELLED** badge; any other closed application shows a red **FAILED** badge.
- Step 3: The amount of the largest bid is shown, as in Open orders.
- Step 4: The menu shows only **Info**. Clicking it opens the **Order Details** sheet.
- Step 5: The **Order Details** sheet opens.
- Step 6: Rows are listed newest first.
- Step 7: Each heading sorts in the same way as in Open orders: Date oldest first, Stock name A to Z, Amount smallest first, Status (CANCELLED before FAILED); a second click reverses it and the arrow shows the direction.

---

### IPO-043 — The Order Details sheet for an open order

**Description:**
The Order Details sheet slides in from the right and shows one application in full: its identifiers, status, payment, amounts, the reason from the exchange and each bid. This case verifies the sheet for an application in Open orders.

**Test Steps:**

1. In **Open orders**, click a row. Note the header and the name below it.
2. Note the rows of the details list, top to bottom, and their values.
3. Note the **Payment** row for an application whose UPI mandate has not been answered yet, and for one that has been approved.
4. Note the **Reason** row for a successful application.
5. Note the section below the details list.
6. Click the close (X) control.

**Expected Result:**

- Step 1: The header shows a close (X) control and the title **Order Details**. Below it is the company name.
- Step 2: The rows are **Order Id** (the application number), **Order Status** (a green **Success** or amber **Pending** badge), **Payment**, **App no** (the exchange's bid reference), **Qty**, **Price** (with **₹**), **Total amount** (with **₹** and commas) — Qty, Price and Total amount are those of the bid with the largest amount — **Bid Date & Time** (for example **21-10-2026 - 10:15 AM**) and **Reason**.
- Step 3: Before the mandate is answered, **Payment** shows an amber **Pending** badge. Once answered it shows the status from the bank — green when approved, red when it failed, was rejected, expired, was declined or cancelled.
- Step 4: **Reason** reads **"Order placed successfully"** when the exchange gives no reason; otherwise it shows the exchange's reason.
- Step 5: A heading reads **Single bid order**, followed by a table with the columns **Bid**, **Qty**, **Price**, **Amount** and **Cut off**. Each bid is a row numbered 1, 2, 3; Amount carries **₹**; Cut off shows a green tick when the bid was at cut-off and a red cross when it was not.
- Step 6: The sheet closes.

---

### IPO-044 — The Order Details sheet for a closed order

**Description:**
The Order Details sheet for an application in Close orders shows the same details as for an open one, except that there is no payment to track. This case verifies the sheet for a cancelled and a failed application.

**Test Steps:**

1. In **Close orders**, click a cancelled application. Note the header, the name and the rows of the details list.
2. Note whether a **Payment** row is shown.
3. Open the sheet for a failed application. Note the **Order Status** and **Reason** rows.
4. Note the section below the details list.

**Expected Result:**

- Step 1: The header shows a close (X) control and the title **Order Details**, with the company name below. The rows are **Order Id**, **Order Status**, **App no**, **Qty**, **Price**, **Total amount**, **Bid Date & Time** and **Reason**. Qty, Price and Total amount are those of the bid with the largest amount.
- Step 2: No **Payment** row is shown.
- Step 3: **Order Status** shows an amber **Cancelled** badge for a cancelled application and a red **Failed** badge for a failed one. **Reason** shows the exchange's reason for the failure, or **"Order placed successfully"** when none is given.
- Step 4: A heading reads **Single bid order**, followed by the bid table with the columns **Bid**, **Qty**, **Price**, **Amount** and **Cut off**, one row per bid.

---
