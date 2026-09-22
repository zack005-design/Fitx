"""Build the FitX Kerala, Tamil Nadu, and Karnataka food catalog.

The canonical values come from the open-access Anuvaad Indian Nutrient
Databank (INDB) workbook. Regional dishes that are not present in INDB retain
the legacy recipe estimate, but are explicitly marked as estimates instead of
being presented as measured values.
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

import openpyxl


ROOT = Path(__file__).resolve().parents[1]
LEGACY_PATH = ROOT / "tool" / "data" / "legacy_south_indian_foods.json"
INDB_PATH = ROOT / "tool" / "data" / "Anuvaad_INDB_2024.11.xlsx"
OUTPUT_PATH = ROOT / "assets" / "data" / "south_indian_foods.json"


INDB_CODE_BY_LEGACY_ID = {
    "si_001": "ASC144", "si_002": "BFP148", "si_003": "ASC146",
    "si_004": "ASC147", "si_005": "BFP152", "si_008": "BFP039",
    "si_009": "BFP040", "si_011": "ASC167", "si_013": "ASC126",
    "si_014": "ASC124", "si_015": "ASC127", "si_020": "ASC179",
    "si_022": "ASC219", "si_028": "ASC240", "si_030": "OSR113",
    "si_032": "BFP436", "si_040": "ASC282", "si_041": "OSR014",
    "si_045": "BFP153", "si_055": "BFP153", "si_059": "BFP230",
    "si_060": "BFP240", "si_068": "ASC236", "si_069": "ASC247",
    "si_072": "OSR105", "si_082": "ASC219", "si_088": "BFP230",
    "si_101": "ASC247", "si_109": "ASC167", "si_125": "ASC247",
    "si_127": "BFP240", "si_135": "BFP436", "si_139": "ASC124",
    "si_140": "ASC467", "si_141": "BFP579", "si_144": "ASC146",
    "si_145": "BFP176", "si_149": "ASC096", "si_152": "OSR014",
    "si_179": "ASC246", "si_180": "BFP230", "si_182": "ASC127",
    "si_184": "BFP148", "si_189": "ASC247",
}

COMMON_IDS = {
    "si_001", "si_002", "si_003", "si_004", "si_005", "si_008",
    "si_009", "si_011", "si_012", "si_013", "si_014", "si_015",
    "si_019", "si_022", "si_026", "si_027", "si_030", "si_031",
    "si_032", "si_033", "si_034", "si_035", "si_036", "si_037",
    "si_038", "si_039", "si_040", "si_041", "si_045", "si_046",
}

NUTRIENT_COLUMNS = {
    "calories_per100": "energy_kcal",
    "protein_per100": "protein_g",
    "carbs_per100": "carb_g",
    "fat_per100": "fat_g",
    "fiber_per100": "fibre_g",
    "sugar_per100": "freesugar_g",
    "saturated_fat_per100": "sfa_mg",
    "cholesterol_per100": "cholesterol_mg",
    "calcium_per100": "calcium_mg",
    "phosphorus_per100": "phosphorus_mg",
    "magnesium_per100": "magnesium_mg",
    "sodium_per100": "sodium_mg",
    "potassium_per100": "potassium_mg",
    "iron_per100": "iron_mg",
    "zinc_per100": "zinc_mg",
    "vitamin_a_per100": "vita_ug",
    "vitamin_c_per100": "vitc_mg",
    "folate_per100": "folate_ug",
}


EXTRAS = [
    # Tamil Nadu
    ("Kambu Koozh", "Tamil Nadu", "si_008", "porridge", 300, "கம்பு கூழ்|pearl millet porridge"),
    ("Ragi Kali", "Tamil Nadu", "si_137", "staple", 200, "கேழ்வரகு களி|keppai kali"),
    ("Adai", "Tamil Nadu", "si_002", "breakfast", 120, "அடை|mixed lentil dosa"),
    ("Kal Dosa", "Tamil Nadu", "si_065", "breakfast", 100, "கல் தோசை"),
    ("Wheat Dosa", "Tamil Nadu", "si_002", "breakfast", 110, "கோதுமை தோசை|godhumai dosai"),
    ("Kara Kozhukattai", "Tamil Nadu", "si_118", "snack", 120, "கார கொழுக்கட்டை|uppu kozhukattai"),
    ("Paal Kozhukattai", "Tamil Nadu", "si_119", "dessert", 180, "பால் கொழுக்கட்டை"),
    ("Paruppu Usili", "Tamil Nadu", "si_026", "side", 120, "பருப்பு உசிலி"),
    ("Thayir Vadai", "Tamil Nadu", "si_033", "snack", 160, "தயிர் வடை|curd vada"),
    ("Kothu Parotta", "Tamil Nadu", "si_077", "main", 250, "கொத்து பரோட்டா"),
    ("Chicken Salna", "Tamil Nadu", "si_028", "curry", 150, "சிக்கன் சால்னா"),
    ("Vegetable Salna", "Tamil Nadu", "si_019", "curry", 150, "வெஜிடபிள் சால்னா"),
    ("Kara Kuzhambu", "Tamil Nadu", "si_025", "curry", 150, "கார குழம்பு"),
    ("Poondu Kuzhambu", "Tamil Nadu", "si_025", "curry", 150, "பூண்டு குழம்பு|garlic kuzhambu"),
    ("Paruppu Urundai Kuzhambu", "Tamil Nadu", "si_026", "curry", 180, "பருப்பு உருண்டை குழம்பு"),
    ("Jigarthanda", "Tamil Nadu", "si_040", "beverage", 300, "ஜிகர்தண்டா|Madurai jigarthanda"),
    ("South Indian Filter Coffee", "Tamil Nadu|Karnataka|Kerala", "si_040", "beverage", 150, "filter kaapi|degree coffee"),
    ("Neer Mor", "Tamil Nadu", "si_024", "beverage", 250, "நீர் மோர்|spiced buttermilk"),
    ("Panagam", "Tamil Nadu", "si_007", "beverage", 200, "பானகம்|jaggery drink"),
    ("Nandu Rasam", "Tamil Nadu", "si_012", "soup", 180, "நண்டு ரசம்|crab rasam"),
    # Kerala
    ("Kerala Rice Kanji", "Kerala", "si_122", "porridge", 300, "കഞ്ഞി|rice gruel"),
    ("Kanji with Cherupayar", "Kerala", "si_072", "main", 400, "കഞ്ഞിയും ചെറുപയറും|rice gruel with green gram"),
    ("Cherupayar Curry", "Kerala", "si_031", "curry", 150, "ചെറുപയർ കറി|green gram curry"),
    ("Kallappam", "Kerala", "si_076", "breakfast", 90, "കള്ളപ്പം"),
    ("Vattayappam", "Kerala", "si_114", "snack", 100, "വട്ടയപ്പം|steamed rice cake"),
    ("Nool Puttu", "Kerala", "si_045", "breakfast", 150, "നൂൽപ്പുട്ട്|string hoppers"),
    ("Ragi Puttu", "Kerala", "si_072", "breakfast", 150, "റാഗി പുട്ട്"),
    ("Wheat Puttu", "Kerala", "si_072", "breakfast", 150, "ഗോതമ്പ് പുട്ട്"),
    ("Ela Ada", "Kerala", "si_118", "snack", 100, "ഇലയട|vazhayila ada"),
    ("Kalan", "Kerala", "si_083", "curry", 150, "കാളൻ|sadya kalan"),
    ("Pulissery", "Kerala", "si_024", "curry", 150, "പുളിശ്ശേരി|moru curry"),
    ("Theeyal", "Kerala", "si_025", "curry", 150, "തീയൽ"),
    ("Pineapple Pachadi", "Kerala", "si_083", "side", 100, "പൈനാപ്പിൾ പച്ചടി"),
    ("Beetroot Kichadi", "Kerala", "si_087", "side", 100, "ബീറ്റ്റൂട്ട് കിച്ചടി"),
    ("Inji Curry", "Kerala", "si_025", "condiment", 30, "ഇഞ്ചിക്കറി|puli inji"),
    ("Sambharam", "Kerala", "si_024", "beverage", 250, "സംഭാരം|spiced buttermilk"),
    ("Ghee Rice (Neychoru)", "Kerala", "si_089", "rice", 200, "നെയ്ച്ചോറ്|ney choru"),
    ("Kappa with Meen Curry", "Kerala", "si_122", "main", 350, "കപ്പയും മീൻ കറിയും|tapioca with fish curry"),
    ("Mutta Mala", "Kerala", "si_091", "dessert", 80, "മുട്ടമാല"),
    ("Ilaneer Pudding", "Kerala", "si_092", "dessert", 150, "ഇളനീർ പുഡ്ഡിംഗ്|tender coconut pudding"),
    # Karnataka
    ("Chow Chow Bath", "Karnataka", "si_172", "breakfast", 250, "ಚೌ ಚೌ ಬಾತ್|khara bath and kesari bath"),
    ("Khara Bath", "Karnataka", "si_008", "breakfast", 200, "ಖಾರ ಬಾತ್|uppittu"),
    ("Avalakki Oggarane", "Karnataka", "si_151", "breakfast", 200, "ಅವಲಕ್ಕಿ ಒಗ್ಗರಣೆ|poha"),
    ("Shavige Bath", "Karnataka", "si_009", "breakfast", 200, "ಶಾವಿಗೆ ಬಾತ್|vermicelli bath"),
    ("Akki Shavige", "Karnataka", "si_045", "breakfast", 150, "ಅಕ್ಕಿ ಶಾವಿಗೆ|rice noodles"),
    ("Ragi Ambli", "Karnataka", "si_137", "beverage", 300, "ರಾಗಿ ಅಂಬಲಿ|ragi malt"),
    ("Mosaranna", "Karnataka", "si_013", "rice", 200, "ಮೊಸರನ್ನ|curd rice"),
    ("Majjige Huli", "Karnataka", "si_024", "curry", 150, "ಮಜ್ಜಿಗೆ ಹುಳಿ|buttermilk curry"),
    ("Tambli", "Karnataka", "si_024", "curry", 120, "ತಂಬಳಿ|tambuli"),
    ("Bassaru", "Karnataka", "si_159", "curry", 180, "ಬಸ್ಸಾರು"),
    ("Kaalu Palya", "Karnataka", "si_161", "side", 120, "ಕಾಳು ಪಲ್ಯ|legume stir fry"),
    ("Menasinakai Bajji", "Karnataka", "si_034", "snack", 80, "ಮೆಣಸಿನಕಾಯಿ ಬಜ್ಜಿ|mirchi bajji"),
    ("Mosaru Bajji", "Karnataka", "si_024", "side", 120, "ಮೊಸರು ಬಜ್ಜಿ|raita"),
    ("Kayi Obbattu", "Karnataka", "si_140", "dessert", 100, "ಕಾಯಿ ಒಬ್ಬಟ್ಟು|coconut holige"),
    ("Gasagase Payasa", "Karnataka", "si_040", "dessert", 180, "ಗಸಗಸೆ ಪಾಯಸ|poppy seed payasam"),
    ("Hesaru Bele Payasa", "Karnataka", "si_040", "dessert", 180, "ಹೆಸರು ಬೇಳೆ ಪಾಯಸ|moong dal payasam"),
    ("Kashaya", "Karnataka", "si_012", "beverage", 150, "ಕಷಾಯ|herbal decoction"),
    ("Bonda Soup", "Karnataka", "si_036", "snack", 250, "ಬೋಂಡಾ ಸೂಪ್"),
    ("Mangalore Fish Curry", "Karnataka", "si_179", "curry", 180, "ಮಂಗಳೂರು ಮೀನು ಸಾರು|meen gassi"),
    ("Kori Gassi", "Karnataka", "si_185", "curry", 180, "ಕೋರಿ ಗಸ್ಸಿ|Mangalorean chicken curry"),
]


def clean_number(value):
    if value is None or isinstance(value, str) or not math.isfinite(float(value)):
        return None
    return round(float(value), 3)


def load_indb():
    sheet = openpyxl.load_workbook(INDB_PATH, read_only=True, data_only=True).active
    headers = [cell.value for cell in next(sheet.iter_rows(min_row=1, max_row=1))]
    return {
        row[0]: dict(zip(headers, row))
        for row in sheet.iter_rows(min_row=2, values_only=True)
        if row[0]
    }


def category_for(name):
    text = name.lower()
    rules = [
        ("beverage", ["coffee", "tea", "mor", "sambharam", "panagam", "ambli", "kashaya"]),
        ("dessert", ["payasam", "halwa", "kesari", "peda", "pak", "pradhaman", "sweet", "unniyappam", "neyyappam", "mala", "pudding"]),
        ("rice", ["rice", "biryani", "bath", "puliyogare", "chitranna", "pongal"]),
        ("breakfast", ["idli", "dosa", "appam", "puttu", "paniyaram", "upma", "rotti", "rotti", "pathiri", "kadubu", "pundi", "moode", "surnali"]),
        ("snack", ["vada", "bajji", "bonda", "murukku", "chips", "achappam", "sukhiyan", "nippattu", "chakkuli", "kodubale", "goli baje", "churmuri", "buns", "mulik"]),
        ("curry", ["curry", "kuzhambu", "sambar", "saaru", "huli", "gojju", "stew", "mappas", "molee", "gassi", "pulimunchi"]),
        ("seafood", ["fish", "prawn", "crab", "squid", "mussel", "meen", "netholi", "chemmeen", "koonthal", "bangude", "anjal"]),
        ("meat", ["chicken", "mutton", "beef", "duck", "pork", "quail", "irachi", "kori"]),
        ("side", ["poriyal", "thoran", "avial", "olan", "erissery", "palya", "kosambari", "pachadi"]),
    ]
    for category, words in rules:
        if any(word in text for word in words):
            return category
    return "main"


def serving_for(name, category):
    text = name.lower()
    if "idli" in text: return ("1 piece", 45.0)
    if "dosa" in text: return ("1 piece", 120.0)
    if "vada" in text or "bonda" in text or "bajji" in text: return ("1 piece", 70.0)
    if category == "beverage": return ("1 cup", 250.0)
    if category == "rice": return ("1 cup", 200.0)
    if category in {"curry", "seafood", "meat"}: return ("1 cup", 150.0)
    if category == "dessert": return ("1 small bowl", 120.0)
    if category == "snack": return ("1 piece", 50.0)
    if category == "breakfast": return ("1 serving", 150.0)
    return ("1 serving", 150.0)


def aliases_for(name):
    aliases = []
    for group in re.findall(r"\(([^)]+)\)", name):
        aliases.extend(re.split(r"[/,]", group))
    # Keep parenthetical qualifiers in the display name because they often
    # distinguish variants (beans vs carrot poriyal, or regional dosa styles).
    base = name.strip()
    return base, "|".join(a.strip() for a in aliases if a.strip())


def state_for(item_id):
    if item_id in COMMON_IDS:
        return "Tamil Nadu|Kerala|Karnataka"
    number = int(item_id.split("_")[1])
    if number <= 71: return "Tamil Nadu"
    if number <= 135: return "Kerala"
    return "Karnataka"


def from_indb(base, source):
    result = dict(base)
    for target, column in NUTRIENT_COLUMNS.items():
        value = clean_number(source.get(column))
        if target == "saturated_fat_per100" and value is not None:
            value = round(value / 1000, 3)  # INDB stores fatty acids as mg.
        result[target] = value
    serving_grams = None
    energy = clean_number(source.get("energy_kcal"))
    serving_energy = clean_number(source.get("unit_serving_energy_kcal"))
    if energy and serving_energy:
        serving_grams = round(serving_energy / energy * 100, 1)
    result.update({
        "source": "INDB 2024.11",
        "source_code": source["food_code"],
        "data_quality": "recipe_calculated",
        "serving_name": str(source.get("servings_unit") or result["serving_name"]),
        "serving_grams": serving_grams or result["serving_grams"],
    })
    return result


def estimated(base):
    result = dict(base)
    macro_energy = 4 * (result["protein_per100"] + result["carbs_per100"]) + 9 * result["fat_per100"]
    if abs(result["calories_per100"] - macro_energy) > max(25, result["calories_per100"] * .25):
        result["calories_per100"] = round(macro_energy)
    result["sugar_per100"] = None
    result["sodium_per100"] = None
    for key in NUTRIENT_COLUMNS:
        result.setdefault(key, None)
    result.update({
        "source": "Regional household recipe estimate",
        "source_code": None,
        "data_quality": "estimated",
    })
    return result


def main():
    legacy = json.loads(LEGACY_PATH.read_text(encoding="utf-8"))[:201]
    indb = load_indb()
    catalog = []
    by_id = {}

    for raw in legacy:
        base_name, aliases = aliases_for(raw["name"])
        category = category_for(raw["name"])
        serving_name, serving_grams = serving_for(raw["name"], category)
        item = {
            **raw,
            "name": base_name,
            "brand": "Regional recipe",
            "states": state_for(raw["id"]),
            "category": category,
            "aliases": aliases,
            "serving_name": serving_name,
            "serving_grams": serving_grams,
            "is_vegetarian": 0 if category in {"seafood", "meat"} or any(w in raw["name"].lower() for w in ["egg", "crab", "prawn", "fish", "mussel", "squid", "chicken", "mutton", "beef", "duck", "pork", "quail", "irachi", "kori rotti"]) else 1,
        }
        code = INDB_CODE_BY_LEGACY_ID.get(raw["id"])
        item = from_indb(item, indb[code]) if code else estimated(item)
        catalog.append(item)
        by_id[item["id"]] = item

    for index, (name, states, clone_id, category, grams, aliases) in enumerate(EXTRAS, 1):
        clone = dict(by_id[clone_id])
        clone.update({
            "id": f"regional_{index:03d}", "name": name, "states": states,
            "category": category, "aliases": aliases,
            "serving_name": "1 serving", "serving_grams": float(grams),
            "source": "Regional household recipe estimate", "source_code": None,
            "data_quality": "estimated", "is_custom": 0,
        })
        catalog.append(clone)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    state_counts = {
        state: sum(state in item["states"].split("|") for item in catalog)
        for state in ("Kerala", "Tamil Nadu", "Karnataka")
    }
    print(f"Wrote {len(catalog)} foods: {state_counts}")
    print(f"INDB-backed: {sum(i['data_quality'] == 'recipe_calculated' for i in catalog)}")


if __name__ == "__main__":
    main()
