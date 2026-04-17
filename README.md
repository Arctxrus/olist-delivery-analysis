# Olist Delivery Performance Analysis

A SQL-driven investigation into whether delivery performance drives customer review scores on Olist, a Brazilian e-commerce platform. Short answer: it does, and the effect is larger than most other factors in the dataset.

The headline number: crossing the estimated delivery date by even a single day costs sellers an average of **1.4 stars** on their review score. Late deliveries make up only 7% of all delivered orders but account for 41% of 1-star reviews.

This project started with one question and ended up answering five, each one prompted by what the previous finding left unexplained.

---

## Findings

### 1. Late deliveries collapse review scores, and the cliff is sharp

Early and on-time deliveries cluster around 4.1 to 4.3 stars. The moment a delivery crosses its estimated date, the average drops to 2.7. Orders arriving 8-30 days late average 1.65. The relationship is not gradual; there is a hard cliff at day zero.

One anomaly worth noting: orders arriving 30+ days late (n=331) actually score slightly higher than the 8-30 day late bucket. The most likely explanation is category mix in the tail; very long delays skew toward furniture and other forgiving categories where customers had lower urgency to begin with. The small sample size also limits confidence in this bucket.

![Delay vs review score](figures/01_delay_vs_score.png)

### 2. The penalty varies by category, by up to 28%

Toys, sports equipment, and watches/gifts take the harshest hit when delivery goes wrong (score drops of 2.0+ stars). Telephony, furniture, and bedding are more forgiving (drops around 1.75-1.9 stars). The pattern maps cleanly onto emotional stakes: a late birthday gift is a different kind of failure than a late set of bed sheets.

![Category variation](figures/02_category_variation.png)

### 3. Distance is a confounder, not a direct cause

Cross-country deliveries are 3x more likely to be late than local ones. But when they arrive on time, customers score them nearly identically to local deliveries (4.25 vs 4.35). Customers respond to outcomes, not to geography. The disadvantage long-distance sellers face is a logistics problem, not a fairness problem.

![Distance confounder](figures/03_distance_confounder.png)

### 4. Seller size doesn't help (null result)

We expected that high-volume sellers would be cut more slack when deliveries went wrong. They aren't. The penalty for a late delivery is roughly 2 stars regardless of whether the seller has shipped 5 orders or 5,000. Brand familiarity does not buy a buffer against bad delivery experiences.

![Seller size null result](figures/04_seller_size_null.png)

### 5. Two distinct intervention types emerge from the priority ranking

Combining categories, geography, and volume into a single priority metric reveals that the top 20 intervention targets split into two clusters with very different profiles:

**Rio de Janeiro** shows late-delivery rates 3-4x higher than São Paulo across every major category. The per-order penalty is also high, especially in time-sensitive categories. This points to a systemic logistics issue, not a category-specific one.

**São Paulo** already operates well (4-5% late rates), but the sheer order volume means even small improvements recover hundreds of review-score points across the customer base.

These are not interchangeable interventions. Rio needs a fix; São Paulo needs tuning. Different teams, different timelines.

![Intervention priorities](figures/05_intervention_priorities.png)

---

## Recommendations

Three concrete moves, in priority order:

**Investigate the Rio de Janeiro logistics gap.** RJ's late-rate is structurally 3-4x higher than SP's in every top-10 category. This is too uniform to be a category problem and too large to be noise. The likely culprits are carrier contracts, distribution node capacity, or last-mile routing.

**Set category-aware delivery estimates.** The modal delivery arrives about 13 days before the estimate, so Olist is already sandbagging conservatively. But the buffer should be even larger for emotional/gift categories (toys, watches, sports), where the penalty for slipping is steepest. A uniform buffer across all categories leaves predictable review damage on the table.

**De-prioritise seller-trust badges as a defence against late-delivery damage.** The null result in section 4 is direct evidence that customer goodwill toward known sellers does not survive a bad delivery. Seller-tier signals may be worth building for other reasons (discoverability, conversion), but not as a shield against logistics failures.

---

### With more data, the next step is inferential

This analysis is deliberately descriptive. The natural extension would be an ordinal logistic regression predicting review score from delay days (continuous), product category, shipping distance, and order value simultaneously. That model would quantify the marginal effect of each additional day of delay while controlling for the other variables, which is something the bucketed analysis above cannot do cleanly. It would also surface whether the category-sensitivity finding from section 2 survives as a genuine interaction term or is absorbed once you control for price and distance jointly. The Olist dataset has enough volume (96k delivered orders) to support this comfortably.

---

## Limitations

**Correlational, not causal.** This analysis cannot rule out that customers who buy time-sensitive categories are also systematically harsher reviewers in general. A controlled experiment varying delivery promises within a single category would isolate the effect more cleanly.

**Binary simplification.** Most of the analysis splits delivery into on-time vs late, which loses information about delay magnitude. A delivery 1 day late is a different event from one 30 days late. Future work could use a continuous delay variable and report effect sizes per additional day.

About 600 orders (under 1%) were excluded from the distance analysis due to missing geolocation entries. Category attribution uses the first item per order, which is defensible for single-item orders (the majority) but misses multi-category basket effects.

---

## Project structure

```
olist-delivery-analysis/
├── README.md
├── setup/
│   └── 01_create_indexes.sql    # Run once after downloading the database
├── queries/
│   ├── 01_delivery_score_baseline.sql
│   ├── 02_category_variation.sql
│   ├── 03_distance_confounder.sql
│   ├── 04_seller_size_interaction.sql
│   └── 05_intervention_priorities.sql
├── notebooks/
│   └── analysis.ipynb           # Full analysis with charts and narrative
├── figures/                     # Chart outputs from the notebook
├── data/
│   └── README.md                # Download instructions for the dataset
└── requirements.txt
```

## Reproducing this analysis

1. Clone the repo.
2. Download the Olist SQLite database from [Kaggle](https://www.kaggle.com/datasets/terencicp/e-commerce-dataset-by-olist-as-an-sqlite-database) and place `olist.sqlite` in `data/`.
3. Run `setup/01_create_indexes.sql` once against the database to create join-key indexes. The raw database ships without any, which makes the geolocation joins impractically slow.
4. Create a virtual environment and install dependencies:
   ```bash
   python -m venv .venv
   source .venv/bin/activate   # or .venv\Scripts\activate on Windows
   pip install -r requirements.txt
   ```
5. Open and run `notebooks/analysis.ipynb`. Total runtime is under a minute on a laptop.

The SQL queries in `queries/` are also independently runnable against the database using any SQLite client (DB Browser, SQLTools, DuckDB, the sqlite3 CLI).

## Tools

Python (pandas, matplotlib), SQL (SQLite), Jupyter, VS Code with SQLTools.

## Data source

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), provided as a [pre-built SQLite database](https://www.kaggle.com/datasets/terencicp/e-commerce-dataset-by-olist-as-an-sqlite-database). Real anonymised commercial data covering approximately 100,000 orders placed between 2016 and 2018.
