# Cardiovascular Mortality Inequalities in Europe

## Public-health question

How do cardiovascular-disease mortality rates differ across European countries, sexes and years?

This project uses age- and sex-disaggregated population mortality data to study a major European non-communicable disease challenge.

## Data

Use the [WHO European Mortality Database](https://gateway.euro.who.int/en/datasets/european-mortality-database/) to download country-year cardiovascular mortality data. Save it as `data/raw/cardiovascular_mortality.csv` with:

`Country, Year, Sex, Deaths, Population, Age_standardised_rate`

## Analysis

- Validates and cleans mortality records.
- Compares age-standardised mortality rates across countries and sexes.
- Calculates the male-to-female mortality gap.
- Exports `data/processed/tableau_cardiovascular_mortality.csv` for Tableau.

## Run

```bash
pip install -r requirements.txt
python src/analyse_cardiovascular_mortality.py
jupyter lab
```

## Tableau dashboard

Include a country map, a time-series trend, a sex comparison, and a ranking showing the largest mortality gaps.

## Methods and limitations

Country reporting practices and the completeness of mortality registration vary. Prefer age-standardised rates for comparisons and interpret differences with caution.
