# UK Employment Density Analysis (1997–2025)

This project analyses long-term changes in the **employment density of UK industries**, measured as each industry’s share of total employment.  
Using Office for National Statistics (ONS) data, we compare industry-level employment in **1997** and **2025**, showing which sectors have gained or lost ground in the workforce.

---

## 📊 Key Results

The analysis highlights a clear divergence between service industries and traditional goods-producing sectors:

- **Growth sectors**:
  - Human health & social work (+3.14pp)
  - Professional, scientific & technical activities (+2.83pp)
  - Public administration & defence (+2.54pp)
  - Education (+2.48pp)
  - Information & communication (+2.12pp)

- **Declining sectors**:
  - Manufacturing (−8.78pp)
  - Wholesale, retail & repair of motor vehicles (−4.32pp)
  - Construction (−1.12pp)
  - Agriculture, forestry & fishing (−0.75pp)

Overall, the shift reflects the UK’s transition from manufacturing and agriculture towards services, knowledge work, and health/social care.

---

## 🗂 Repository Contents

- `data/` – Input files:
  - `people employment.csv`
  - `All Employment and Public Sector.csv`
- `workflow.sql` – DuckDB SQL pipeline:
  - Cleans and reshapes raw tables
  - Normalises industries by total employment
  - Computes start density (1997), end density (2025), and percentage-point changes
- `Output/Density_change.png` – Visualisation of industry employment density change
- `Density_Change_Visualiser.ipynb` – Notebook for plotting with Python/Matplotlib

---

## 🔧 Workflow

1. **Data ingestion** – Load ONS Excel/CSV tables into DuckDB.
2. **Cleaning** – Cast industry columns to numeric, drop unused total/public/private columns.
3. **Transformation** – `UNPIVOT` industries to long format; parse quarters (1997Q1 → 2025Q2).
4. **Normalisation** – Divide each industry’s employment by the `All in employment` total.
5. **Comparison** – Extract industry densities for 1997Q1 and 2025Q2.
6. **Output** – Summary table + bar chart.

SQL excerpt:

```sql
WITH params(start_q, end_q) AS (
  VALUES (DATE '1997-01-01', DATE '2025-04-01')
),
start_1997 AS (
  SELECT industry, ROUND(100 * density, 2) AS start_density
  FROM industry_density_uniq u, params p
  WHERE u.quarter_start = p.start_q
),
end_2025 AS (
  SELECT industry, ROUND(100 * density, 2) AS end_density
  FROM industry_density_uniq u, params p
  WHERE u.quarter_start = p.end_q
)
SELECT
  s.industry,
  s.start_density AS "Start Density (1997)",
  e.end_density   AS "End Density (2025)",
  ROUND(e.end_density - s.start_density, 2) AS "Density Change (2025)"
FROM start_1997 s
JOIN end_2025 e USING (industry)
ORDER BY "Density Change (2025)" DESC;
