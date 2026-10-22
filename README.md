# Sizwe Coffee: FY2025 Year-End Review (SQL Analysis)

Eight SQL analyses that answer the Financial Director's and National Sales Manager's questions ahead of Sizwe Coffee's FY2025 year-end review. The work was done in a Databricks notebook and exported to `queries.sql`.

## :dart: 1. Project overview

**The business.** Sizwe Coffee (Pty) Ltd is a coffee roastery and wholesale supplier based in Isando, Johannesburg, with a second distribution centre in Epping, Cape Town. It roasts green beans and sells to about 1,400 business customers - grocery chains, restaurant groups, independent cafés, hotels and offices. It does not own retail stores.

| Item | Value |
|---|---|
| Revenue | R441m in FY2024, R480m in FY2025 |
| Staff | 320 |
| Customers | 1,400 |
| Channels | Wholesale (about 70% of revenue) and Subscription (about 30%) |
| Financial year | 1 July to 30 June |
| Period in the data | 1 July 2023 to 30 June 2025 |

**The situation.** I am a junior data analyst who has just joined. The financial year ended on 30 June 2025 and the year-end review is two weeks away. **Nomsa Dlamini**, Financial Director and **Bongani Twala** National Sales Manager each asked for a list of things to understand before that meeting.

**The eight questions**

| # | Asked by | Question |
|---|---|---|
| 1 | Nomsa | Revenue by channel, FY2024 vs FY2025, with growth rate |
| 2 | Nomsa | Revenue, cost of goods, gross profit and margin by product line |
| 3 | Nomsa | Is the business being paid more slowly, and where does the problem sit? |
| 4 | Bongani | The ten largest customers by FY2025 revenue, with the rep who owns each account |
| 5 | Bongani | The 15 highest-revenue Wholesale customers that never received a trade promotion |
| 6 | Bongani | Are the sales reps hitting their monthly target? |
| 7 | Bongani | Monthly revenue over two years: seasonality and the quietest month |
| 8 | Both | Why did gross margin fall from 34.7% to 33.0% while revenue grew nearly 9%? |

## :file_cabinet: 2. Dataset

Nine tables were provided and eight are used here (`vendors` and `rep_visits` are not needed for these tasks). In my environment every table carries a `sizwe_` prefix (for example `sizwe_sales_lines`).

| Table | Rows | What it holds |
|---|---|---|
| `customers` | 1,400 | One row per customer: name, channel, segment, province, credit limit, assigned sales rep |
| `products` | 23 | One row per SKU: product line, pack size, list price, unit cost |
| `sales_orders` | 48,144 | One row per order: customer, order date, delivery date, channel, sales rep |
| `sales_lines` | 168,172 | One row per order line: SKU, units, unit price, discount, line revenue, cost of goods (`cogs`) |
| `ar_ledger` | 48,144 | One row per customer invoice: invoice amount, due date, amount settled, settlement date |
| `reps` | 18 | Sales reps: territory, monthly target (`target_monthly`) |
| `rep_visits` | 9,400 | Visits by reps to customers, with the outcome (not used) |
| `trade_promotions` | 640 | Promotional support given to a customer on a SKU |
| `vendors` | 74 | Suppliers (not used) |

### How the tables connect

```
sales_orders.customer_id  ->  customers.customer_id
sales_orders.order_id     ->  sales_lines.order_id
sales_lines.sku           ->  products.sku
sales_orders.rep_id  and  customers.rep_id  ->  reps.rep_id
ar_ledger.customer_id     ->  customers.customer_id
rep_visits.customer_id  and  trade_promotions.customer_id  ->  customers.customer_id
```

Three things to understand about these links:

1. **Revenue lives on `sales_lines`, not `sales_orders`.** An order has no value of its own, only the sum of its lines. Every revenue figure therefore joins orders to lines and sums `line_revenue`.
2. **The "and" in the join list is plain English, not an SQL keyword.** It means two different tables each point at the same target. `sales_orders.rep_id` and `customers.rep_id` both point at `reps`: the first is the rep who handled that specific order, the second is the rep assigned to the customer. I use the customer's rep when asking "who owns the account?" (Task 4) and the order's rep when asking "who made the sales?" (Task 6).
3. **`channel` appears on both `customers` and `sales_orders`.** I use the order's channel when measuring sales (Task 1) and the customer's channel when classifying customers or invoices (Tasks 3 and 5).

## :wrench: 3. Skills demonstrated

| SQL technique | Where it is used |
|---|---|
| Joins across two, three and four tables | Tasks 1, 2, 3, 4, 5, 6, 7, 8 |
| Aggregation (`SUM`, `COUNT`, `AVG`) with `GROUP BY` | All tasks |
| Conditional aggregation (`SUM(CASE WHEN ...)`) to put two financial years side by side | Task 1 |
| Common table expressions (CTEs) | Tasks 1, 2, 6, 7, 8 |
| Safe division with `NULLIF` and rounding with `ROUND` | Tasks 1, 2, 3, 6, 7, 8 |
| Counting settled vs open invoices with `COUNT(column)` vs `COUNT(*)` | Task 3 |
| Date arithmetic (`DATEDIFF`) | Task 3 |
| `LEFT JOIN` plus `CASE` / `IFNULL` so no rows are silently dropped | Tasks 4, 6 |
| Anti-join with `NOT EXISTS` | Task 5 |
| Date filter placed in the `ON` clause to keep a `LEFT JOIN` intact | Task 6 |
| Window functions: `LAG`, rolling `AVG ... ROWS BETWEEN`, `SUM ... OVER (PARTITION BY ...)` | Tasks 7, 8 |
| Date bucketing with `DATE_TRUNC` | Task 7 |
| `CASE` expressions to label financial years | Tasks 1, 8 |
| `ORDER BY` and `LIMIT` for top-N lists | Tasks 4, 5 |

## :arrow_forward: 4. How to run

**Tool used:** a Databricks SQL notebook.

1. Load the Sizwe Coffee dataset into Databricks. The tables carry a `sizwe_` prefix (for example `sizwe_sales_lines`).
2. Open a new Databricks notebook and copy the queries from `queries.sql` into it, one query per SQL cell.
3. Run the queries one at a time, in order from Task 1 to Task 8. Each query is preceded by a `-- Task N` comment, and each runs on its own.
4. Compare your results with the figures in the Key insights section. For example, Task 1 should show 8.8% growth for both channels, and Task 4 should have Halvane Retail Group first at about R38.4m.


## :bar_chart: 5. Key insights

### Task 1: Channel performance

| Channel | FY2024 revenue | FY2025 revenue | Growth |
|---|---|---|---|
| Subscription | R132.8m | R144.6m | 8.8% |
| Wholesale | R308.2m | R335.4m | 8.8% |

- Both channels grew by the same **8.8%**, so the split stays at about 70% Wholesale and 30% Subscription in both years. 
- Verification: the two channels add up to R441.0m (FY2024) and R480.0m (FY2025), matching the brief.

### Task 2: Profit by product line

| Product line | Revenue | Gross profit | Gross margin |
|---|---|---|---|
| House Blend | R279.5m | R107.1m | 38.3% |
| Single Origin | R170.1m | R75.3m | **44.3%** |
| Bulk Commercial | R271.8m | R54.1m | **19.9%** |
| Capsules | R108.9m | R42.4m | 38.9% |
| Decaf | R90.6m | R32.5m | 35.8% |

- House Blend earns the most profit (R107.1m) but is **not** the highest-margin line. Single Origin has the best margin (44.3%).
- Bulk Commercial is the second-largest line by revenue (R271.8m) but earns only R54.1m of profit because its margin is just 19.9%, about half that of the other lines.
- Verification: revenue across the five lines is about R921m, which matches R441m (FY2024) + R480m (FY2025).

### Task 3: Collections

| Channel | Invoices | Open | Share open | Avg days vs due date | Outstanding |
|---|---|---|---|---|---|
| Subscription | 19,200 | 44 | 0.2% | -26.2 (early) | R0.75m |
| Wholesale | 28,944 | 3,454 | 11.9% | +17.2 (late) | R87.85m |

- Subscription customers pay about 26 days before the due date and almost nothing is outstanding.
- Wholesale customers pay about 17 days late on average, about 12% of Wholesale invoices (3,454 of 28,944) are still unpaid, and Wholesale holds roughly 99% of all money owed.
- The 17.2 days is probably understated because the average only includes settled invoices, and the 3,454 open ones are the slowest payers. **Wholesale is the first place to investigate.**
- Sanity check: 19,200 + 28,944 = 48,144 invoices, matching the `ar_ledger` row count.

### Task 4: Ten accounts that matter most

| Rank | Customer | Segment | Province | Account owner | FY2025 revenue |
|---|---|---|---|---|---|
| 1 | Halvane Retail Group | Grocery Chain | Western Cape | Kagiso Mkhize | R38.40m |
| 2 | Highveld Deli 85 | Restaurant Group | Free State | Karabo Mokoena | R3.38m |
| 3 | Table Bay Foods 280 | Independent Cafe | KwaZulu-Natal | Karabo van Wyk | R3.33m |
| 4 | Umhlanga Fresh 108 | Restaurant Group | Gauteng | Sipho Steyn | R3.25m |
| 5 | Kalahari Kitchen 42 | Independent Cafe | Gauteng | Chantal Ismail | R2.32m |

- **Halvane Retail Group** is by far the largest account at R38.4m, about 8% of FY2025 revenue and roughly 11 times the second-largest customer. That is a concentration risk worth raising in the review.
- The other nine accounts in the top ten range from R1.9m to R3.4m. Together the top ten bring in about R61.4m, around 12.8% of the R480m.
- Every one of the ten has an assigned rep (none shows as "Unassigned"), and Chantal Ismail and Karabo Zwane each own two of them.

### Task 5: A commercial gap

- The three largest Wholesale customers that have **never** received a trade promotion are **Umhlanga Fresh 108**, **Ridgeway Foods 308** and **Kalahari Kitchen 42**.
- Recommendation: have each account's sales rep visit them and offer a targeted promotion, starting with Umhlanga Fresh 108, because they already buy heavily at full price.
- Revenue here is measured across the whole period in the data (July 2023 to June 2025), since the brief does not restrict it to one year.

- Task 4 shows that all three also rank among the top six accounts by FY2025 revenue: Umhlanga Fresh 108 (4th, R3.25m), Kalahari Kitchen 42 (5th, R2.32m) and Ridgeway Foods 308 (6th, R2.32m). That supports Bongani's suspicion that sizeable customers are getting no promotional support.

### Task 6: Sales reps against target

- The 15 highest-ranked reps all beat their monthly target, from **116.1%** (Bongani Mahlangu, Eastern Cape) up to **250.3%** (Karabo van Wyk, Gauteng South, who averaged R2.25m a month against a R900k target).
- **Kagiso Mkhize** (Gauteng North) is second at 249.8% and the biggest earner in rand, averaging R5.0m a month against a R2.0m target. Kagiso also owns the Halvane Retail Group account (R38.4m in FY2025, about R3.2m a month), which would make up roughly two-thirds of that average if those orders were placed under the same rep.
- Percentage of target depends heavily on the target itself: Karabo Zwane averaged more (R2.51m) than Anele Zwane (R1.85m) but scores lower (125.6% against 205.2%), because the target is R2.0m against R900k.



### Task 7: The shape of the year

- There is a clear seasonal pattern that repeats almost exactly in both years.
- Revenue slumps in **December**, and December 2023 was the quietest month at **R29.9m**.
- Revenue then climbs steadily from January to peak in the winter months of June and July.
- The first two rolling three-month averages use fewer than three months of history, because the data starts in July 2023.

### Task 8: Why the margin fell from 34.7% to 33.0%

- The decline is a **mix effect**, not a pricing or cost problem inside any single line.
- **Bulk Commercial**, the lowest-margin line at 19.9%, grew from R110.3m to R161.5m and now makes up **33.6%** of revenue instead of **25.0%**, a shift of 8.6 percentage points.
- The two highest-margin lines lost share: **Single Origin** from 19.5% to 17.6% and **Capsules** from 12.9% to 10.8%.
- Each line held its own margin almost exactly, so the blended margin fell because the business tilted toward its least profitable line. Revenue grew about 9%, but it was low-quality growth.
- Consistency check: R110.3m + R161.5m = R271.8m, which matches Bulk Commercial's total revenue in Task 2.

## :memo: 6. Assumptions and design decisions

- **Financial years.** FY2024 is `order_date < '2024-07-01'` and FY2025 is `order_date >= '2024-07-01'`, so orders carrying a time of day on 30 June are not dropped. The year is assigned by **order date**, as the brief specifies.
- **Settled invoice.** An invoice counts as settled when it has a `settlement_date`; otherwise it is open.
- **Days to settle.** Measured as `settlement_date - due_date`, because the ledger has a due date but no invoice date. Negative means paid early, positive means paid late.
- **Outstanding value.** `invoice_amount - amount_settled`, summed, so part-payments are handled correctly.
- **Task 4 keeps every customer.** `LEFT JOIN reps` with a `CASE` that labels a missing rep as "Unassigned" means a customer without a rep is not silently dropped.
- **Task 5 period.** "Highest-revenue" uses revenue across the whole period in the data.
- **Task 6 monthly average.** FY2025 revenue divided by 12, using the rep on the order (`sales_orders.rep_id`). The date filter sits in the `ON` clause of the `LEFT JOIN`, so reps with no FY2025 sales still appear with revenue 0.
- **Task 7 rolling average.** A three-row window ordered by month, so the first two months are averaged over fewer than three months.
- **Task 8 margin.** `(revenue - cogs) / revenue`, computed per product line per financial year, and the share of revenue is each line's revenue divided by that year's total across all lines.

## :file_folder: 7. Repository contents

| File | Purpose |
|---|---|
| [queries.sql](queries.sql) | All eight queries in order, each preceded by its task number, with a written answer beneath where the brief asks for one |
| [README.md](README.md) | Project Documentation |
