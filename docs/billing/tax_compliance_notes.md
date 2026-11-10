# Canadian sales tax: what a seller's return needs (assessment, 2026-11-10)

A reference note for the tax report (`Billing::TaxReport`, see [tax_reports.md](tax_reports.md)). It was written from public CRA, Revenu Quebec, BC, Saskatchewan and Manitoba pages read on 2026-11-10. Anything marked UNVERIFIED was not found on a page that was read: confirm it with the administrator or an accountant before it drives behaviour. The report prepares figures for a return. It does not file one.

## Scope decisions

- No small-supplier threshold tracking. Registration status on `TaxRegistration` is enough; sellers handle their own thresholds.
- Out of scope because billing does not own the data: input tax credits and refunds (GST34 lines 106, 108, 109, 110 to 115), instalments, rebates, self-assessment (405), bad debts, deposits, discounts.
- No filing, no CRA platform information return (CRA says it does not require platform operators to file them until further notice, page updated 2025-10-16).

## GST/HST (CRA, form GST34)

| Line | Meaning | From the report |
|---|---|---|
| 101 | Total revenue without tax, all supply types, whole dollars | revenue (taxable + zero-rated + non-taxable + exempt) |
| 90 / 91 | Optional split: 90 taxable incl. domestic zero-rated, 91 exempt, exports, other | zero-rated and exempt are now separate |
| 103 | GST/HST collected or collectible on invoices of the period | GST/HST authority total |
| 104, 107 | Adjustments, credits for refunds in set cases | refunded tax is shown separately so either treatment works |
| 105, 108, 109 | Calculated; 109 needs ITCs the platform does not hold | the view says "collected less refunded", never "net tax due" |

- Basis: report the period of the invoice date (earlier of payment received or due), paid or not. The report offers `paid` (default) or `invoice` (placed day, paid statuses still required).
- Periods: annual up to 1.5M taxable supplies, quarterly to 6M, monthly above. Due one month after period end (monthly, quarterly), three months after fiscal year end (annual). Electronic filing is mandatory. Nil returns are required.
- Rates by place of supply, not seller location: 5% GST, 13% HST ON, 14% HST NS (from 2025-04-01), 15% HST NB, NL, PE (NB, NL, PE rates UNVERIFIED on CRA pages read). Zero-rated is 0% everywhere.
- Zero-rated (basic groceries, agricultural and fishery products, prescription drugs, exports) differs from exempt (long-term residential rent, most health, child care, most financial services): zero-rated supplies carry ITC rights and count toward thresholds.
- PST and QST are not on the GST34, and GST is calculated on the price without PST.
- Tax-inclusive prices: back out tax as rate / (1 + rate) of the price (UNVERIFIED against a CRA page).
- Quick method (RC4058): line 101 is tax-inclusive revenue of eligible taxable supplies; remittance rates depend on province and supply location; 1% credit on the first 30,000 on line 107; eligibility up to 400,000 and some professions excluded. Not built.
- Records: keep 6 years. Invoices show the rate, and tax as a separate line or a clear tax-included statement; HST shows the single combined rate.
- Credit notes on a regular-method sale: reduce line 103 or claim on 107, and which period, is in GST/HST Memorandum 16.3 (not read, UNVERIFIED). Keeping collected and refunded separate supports both.

## Provincial taxes (not on the GST34)

| Jurisdiction | Tax | Rate | Administrator | Base | Period and due | Marketplace facilitator |
|---|---|---|---|---|---|---|
| Quebec | QST | 9.975% | Revenu Quebec (also GST/HST there) | price without GST | combined GST/HST and QST return, electronic; monthly, quarterly (due 1 month after), annual (3 months) | platform operators register (NR specified system, TQ general system) and collect on supplies by unregistered suppliers; annual information return by 1 July |
| British Columbia | PST | 7% | BC Finance (eTaxBC), return FIN 400 | price before GST | monthly to annual by PST collectable; due last day of next month | facilitator registers, collects and remits; seller not required to collect on those sales but stays jointly liable; annual information return by 31 Aug |
| Saskatchewan | PST | 6% | Ministry of Finance (SETS) | price before GST | monthly over 12,000, quarterly 4,800 to 12,000, annual below; due last day of next month | licensed facilitator collects and remits; seller exempt from licensing for those sales |
| Manitoba | RST | 7% | Manitoba Finance (TAXcess) | price before GST | monthly 5,000+, quarterly 500 to 4,999, annual below; due 20th of next month, annual by 20 January | operator collects and remits on all facilitated taxable sales; seller has no RST duty for them |

- No tax-on-tax in QC, BC, SK or MB: each provincial tax is on the pre-GST price. Inclusive-price factors: BC 6.67%, SK 5.71% (both confirmed). Compute QST from the pre-GST amount, not from a combined multiplier.
- Quebec platform detail: a specified Quebec consumer is shown by any two of billing address, home or business address, device IP or geolocation, payment information, SIM or other location evidence.
- BC facilitator records per seller: name, address, contact, business number, total payments transmitted, tax collected for the seller, tax remitted.
- Alberta, Yukon, NWT and Nunavut have GST only (UNVERIFIED on an official page).
- UNVERIFIED: registration number formats (GST/HST BN + RT + 4 digits; QST TQ and NR; BC PST; SK licence; MB 7 digits), QST invoice requirements, BC FIN 400 and SK return layouts, SK and MB information return duties, Quebec-resident platform detail.

## What was built (PR #2127)

- `TaxRate` and `TaxLine` carry an `authority` (gst_hst, pst, qst, rst, vat, other), snapshotted like the rate.
- Revenue splits into taxable, zero-rated (categories `zero_rated`, `basic_groceries`), non-taxable and exempt.
- Tax owed per administrator, who collected each tax (seller, platform, or platform for the seller), a per-region summary, registrations with masked numbers (reports are stored), and a paid-day or placed-day basis on saved reports.
- CSV has a return worksheet block, regions and registrations.

## Not built, in value order

1. Per-registrant period and due-date hints (computed hints, never legal deadlines).
2. Quick-method worksheet (rates as dated data).
3. Refund-treatment switch (quick-method view vs regular view).
4. Facilitator view per seller (facilitated sales, tax collected vs remitted, seller number and address).
5. Non-CAD handling: flag non-CAD blocks and document a conversion rule once confirmed.
6. Registration number format validation, once formats are confirmed.
7. Records note: 6-year retention against orders, lines, tax lines, refunds and saved reports; consider blocking hard delete of billed orders.
