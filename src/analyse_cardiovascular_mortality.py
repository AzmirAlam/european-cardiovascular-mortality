from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/raw/cardiovascular_mortality.csv"
OUTPUT = ROOT / "data/processed/tableau_cardiovascular_mortality.csv"
CHART = ROOT / "visuals/cardiovascular_mortality_by_sex.png"
REQUIRED = {"Country", "Year", "Sex", "Deaths", "Population", "Age_standardised_rate"}


def main() -> None:
    if not INPUT.exists():
        raise FileNotFoundError(f"Add the WHO data file here: {INPUT}")
    df = pd.read_csv(INPUT)
    missing = REQUIRED - set(df.columns)
    if missing:
        raise ValueError(f"Missing columns: {sorted(missing)}")
    for column in REQUIRED - {"Country", "Sex"}:
        df[column] = pd.to_numeric(df[column], errors="coerce")
    df = df.dropna(subset=["Country", "Year", "Sex", "Age_standardised_rate"])
    latest = df[df["Year"] == df["Year"].max()].copy()
    pivot = latest.pivot_table(index="Country", columns="Sex", values="Age_standardised_rate", aggfunc="mean")
    if {"Male", "Female"}.issubset(pivot.columns):
        latest = latest.merge((pivot["Male"] - pivot["Female"]).rename("Male_female_gap"), on="Country", how="left")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    latest.to_csv(OUTPUT, index=False)
    sns.set_theme(style="whitegrid")
    ax = sns.barplot(data=latest, x="Sex", y="Age_standardised_rate", errorbar=None)
    ax.set(title="Latest cardiovascular mortality rate by sex", xlabel="Sex", ylabel="Age-standardised mortality rate")
    plt.tight_layout()
    plt.savefig(CHART, dpi=200)
    print(f"Created {OUTPUT} and {CHART}")


if __name__ == "__main__":
    main()
