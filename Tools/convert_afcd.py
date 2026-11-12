"""Convert the FSANZ AFCD 'Nutrient profiles' spreadsheet into FoodLogger/Resources/afcd.json.

Usage (from the project folder):  python3 Tools/convert_afcd.py "Data/AFCD Release 3 - Nutrient profiles.xlsx"
Needs: pip install openpyxl

Output per food: {"id", "name", "n": [kcal, protein g, fat g, saturated fat g,
                   available carbs g, total sugars g, fibre g, sodium mg]} per 100 g.
Columns are found by header name, so a future release with reordered columns still works.
"""
import json, re, sys
import openpyxl

SHEET = "All solids & liquids per 100 g"
COLUMNS = {
    "kj": r"^Energy with dietary fibre",
    "protein": r"^Protein",
    "fat": r"^Fat, total",
    "sat": r"^Total saturated fatty acids, equated \(g\)",
    "carbs": r"^Available carbohydrate, with sugar alcohols",
    "sugars": r"^Total sugars",
    "fibre": r"^Total dietary fibre",
    "sodium": r"^Sodium",
}

def main(path, out="FoodLogger/Resources/afcd.json"):
    ws = openpyxl.load_workbook(path, read_only=True)[SHEET]
    rows = ws.iter_rows(values_only=True)
    header = None
    for row in rows:
        if row and row[0] == "Public Food Key":
            header = [re.sub(r"\s+", " ", str(h or "")).strip() for h in row]
            break
    idx = {k: next(i for i, h in enumerate(header) if re.search(p, h, re.I)) for k, p in COLUMNS.items()}
    name_col = header.index("Food Name")

    def num(v):
        try:
            return float(v)
        except (TypeError, ValueError):
            return 0.0

    foods = []
    for r in rows:
        if not r or not r[0] or not r[name_col] or r[idx["kj"]] is None:
            continue
        n = [num(r[idx["kj"]]) / 4.184] + [num(r[idx[k]]) for k in ["protein", "fat", "sat", "carbs", "sugars", "fibre", "sodium"]]
        foods.append({"id": str(r[0]).strip(), "name": " ".join(str(r[name_col]).split()), "n": [round(x, 2) for x in n]})
    with open(out, "w") as f:
        json.dump(foods, f, separators=(",", ":"), ensure_ascii=False)
    print(f"Wrote {len(foods)} foods to {out}")

if __name__ == "__main__":
    main(sys.argv[1])
