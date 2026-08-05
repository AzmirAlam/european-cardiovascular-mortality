from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/raw/cardiovascular_mortality.csv"
OUTPUT = ROOT / "data/processed/tableau_cardiovascular_mortality.csv"
CHART = ROOT / "visuals/cardiovascular_mortality_by_sex.png"
REQUIRED = {"Country", "Country_code", "Year", "Sex", "Age_standardised_rate"}


def main() -> None:
    if not INPUT.exists():
        raise FileNotFoundError(f"Add the WHO data file here: {INPUT}")
    df = pd.read_csv(INPUT)
    missing = REQUIRED - set(df.columns)
    if missing:
        raise ValueError(f"Missing columns: {sorted(missing)}")
    df[["Year", "Age_standardised_rate"]] = df[["Year", "Age_standardised_rate"]].apply(pd.to_numeric, errors="coerce")
    df = df.dropna(subset=["Country", "Year", "Sex", "Age_standardised_rate"])
    pivot = df.pivot_table(index=["Country", "Year"], columns="Sex", values="Age_standardised_rate", aggfunc="mean")
    if {"Males", "Females"}.issubset(pivot.columns):
        gaps = (pivot["Males"] - pivot["Females"]).rename("Male_female_gap").reset_index()
        df = df.merge(gaps, on=["Country", "Year"], how="left")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUTPUT, index=False)
    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(9, 7))
    total = df[df["Sex"] == "Total"].sort_values("Year").groupby("Country", as_index=False).tail(1)
    top = total.nlargest(15, "Age_standardised_rate").sort_values("Age_standardised_rate")
    ax = sns.barplot(data=top, x="Age_standardised_rate", y="Country", color="#4C78A8")
    ax.set(title="Highest latest cardiovascular mortality rates", xlabel="Age-standardised rate per 100,000", ylabel="Country")
    plt.tight_layout()
    plt.savefig(CHART, dpi=200)
    print(f"Created {OUTPUT} and {CHART}")


if __name__ == "__main__":
    main()
