#!/usr/bin/env python3
"""Generate catalog seed.sql, CSVs, and optional data migration from one source.

Run from repo root:
  python3 scripts/generate_catalog_seed.py
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "supabase" / "seed.sql"
IMPORT_DIR = ROOT / "supabase" / "import"
MIGRATION_PATH = (
    ROOT / "supabase" / "migrations" / "20260728110000_seed_initial_catalog.sql"
)


def uid(prefix: int, n: int) -> str:
    return f"{prefix:08x}-0000-4000-8000-{n:012d}"


def sql_str(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def sql_json(obj: dict) -> str:
    return sql_str(json.dumps(obj, ensure_ascii=False)) + "::jsonb"


def sql_num(value: float | int | None) -> str:
    if value is None:
        return "null"
    return f"{value:.2f}"


def sql_bool(value: bool) -> str:
    return "true" if value else "false"


CATEGORIES = [
    (1, "Vợt cầu lông", "vot-cau-long", "Vợt thi đấu và luyện tập cho mọi trình độ", 10),
    (2, "Giày cầu lông", "giay-cau-long", "Giày chuyên dụng sân trong nhà", 20),
    (3, "Cầu lông", "cau-long", "Cầu lông ống thi đấu và luyện tập", 30),
    (4, "Cước đan vợt", "cuoc-dan-vot", "Dây đan vợt cảm giác và độ bền", 40),
    (5, "Quấn cán", "quan-can", "Grip và overgrip chống trượt", 50),
    (6, "Túi và balo cầu lông", "tui-balo-cau-long", "Túi vợt và balo đựng phụ kiện", 60),
    (7, "Quần áo cầu lông", "quan-ao-cau-long", "Áo quần thi đấu và tập luyện", 70),
    (8, "Vớ thể thao", "vo-the-thao", "Vớ đệm êm cho sân cầu lông", 80),
    (9, "Đồ bảo hộ", "do-bao-ho", "Băng hỗ trợ cổ tay, gối, mắt cá", 90),
    (10, "Phụ kiện tập luyện", "phu-kien-tap-luyen", "Dụng cụ rèn chân và thể lực", 100),
]

BRANDS = [
    (1, "Yonex", "yonex", "Thương hiệu tham chiếu trong dữ liệu demo", "Japan", 10),
    (2, "Victor", "victor", "Thương hiệu tham chiếu trong dữ liệu demo", "Taiwan", 20),
    (3, "Li-Ning", "li-ning", "Thương hiệu tham chiếu trong dữ liệu demo", "China", 30),
    (4, "Mizuno", "mizuno", "Thương hiệu tham chiếu trong dữ liệu demo", "Japan", 40),
    (5, "Kumpoo", "kumpoo", "Thương hiệu tham chiếu trong dữ liệu demo", "China", 50),
    (6, "Apacs", "apacs", "Thương hiệu tham chiếu trong dữ liệu demo", "Malaysia", 60),
    (7, "Kamito", "kamito", "Thương hiệu tham chiếu trong dữ liệu demo", "Vietnam", 70),
    (8, "ProAce", "proace", "Thương hiệu tham chiếu trong dữ liệu demo", "Vietnam", 80),
]

# product: n, cat, brand, name, slug, short, desc, specs, keywords, status, featured, published
PRODUCTS = [
    (1, 1, 1, "Vợt cầu lông Yonex Aero Strike 88", "vot-yonex-aero-strike-88",
     "Vợt cân bằng tốc độ dành cho trình độ trung cấp",
     "Sản phẩm demo minh họa vợt cân bằng. Không phải bản thương mại chính thức.",
     {"material": "High Modulus Graphite", "balance": "Even", "shaft_stiffness": "Medium",
      "recommended_tension_lbs": "20-28", "player_level": "Intermediate", "play_style": "All-round"},
     "vot yonex aero strike 88", "active", True, "2026-06-01T00:00:00Z"),
    (2, 1, 2, "Vợt cầu lông Victor Power Core X7", "vot-victor-power-core-x7",
     "Vợt thiên công lực đập mạnh",
     "Sản phẩm demo minh họa vợt head-heavy cho lối đánh tấn công.",
     {"material": "Graphite Composite", "balance": "Head Heavy", "shaft_stiffness": "Stiff",
      "recommended_tension_lbs": "24-30", "player_level": "Advanced", "play_style": "Attack"},
     "vot victor power core x7", "active", True, "2026-06-02T00:00:00Z"),
    (3, 1, 3, "Vợt cầu lông Li-Ning Wind Blade 900", "vot-li-ning-wind-blade-900",
     "Vợt nhẹ tối ưu tốc độ phản xạ",
     "Sản phẩm demo minh họa vợt nhẹ cho lối đánh nhanh.",
     {"material": "Carbon Fiber", "balance": "Head Light", "shaft_stiffness": "Flexible",
      "recommended_tension_lbs": "20-26", "player_level": "Intermediate", "play_style": "Speed"},
     "vot li-ning wind blade 900", "active", True, "2026-06-03T00:00:00Z"),
    (4, 1, 4, "Vợt cầu lông Mizuno Thunder Pulse", "vot-mizuno-thunder-pulse",
     "Vợt ổn định khung cho người mới lên trung cấp",
     "Sản phẩm demo với khung ổn định và cảm giác trung tính.",
     {"material": "Graphite", "balance": "Even", "shaft_stiffness": "Medium",
      "recommended_tension_lbs": "18-24", "player_level": "Beginner-Intermediate", "play_style": "Control"},
     "vot mizuno thunder pulse", "active", False, "2026-06-04T00:00:00Z"),
    (5, 1, 5, "Vợt cầu lông Kumpoo Speed Light 5", "vot-kumpoo-speed-light-5",
     "Vợt siêu nhẹ hỗ trợ chuyển cánh tay nhanh",
     "Sản phẩm demo phân khúc nhẹ cho phòng tập.",
     {"material": "Carbon", "balance": "Head Light", "shaft_stiffness": "Flexible",
      "recommended_tension_lbs": "18-24", "player_level": "Beginner", "play_style": "Defense"},
     "vot kumpoo speed light 5", "active", False, "2026-06-05T00:00:00Z"),
    (6, 1, 6, "Vợt cầu lông Apacs Force Pro 99", "vot-apacs-force-pro-99",
     "Bản nháp đang hoàn thiện thông số",
     "Sản phẩm draft — chưa công bố bán.",
     {"material": "Graphite", "balance": "Head Heavy", "shaft_stiffness": "Stiff",
      "recommended_tension_lbs": "22-28", "player_level": "Advanced", "play_style": "Attack"},
     "vot apacs force pro 99 draft", "draft", False, None),
    (7, 2, 4, "Giày cầu lông Mizuno Court Flex Pro", "giay-mizuno-court-flex-pro",
     "Giày đệm êm cho sân trong nhà",
     "Sản phẩm demo giày cầu lông đế chống trượt trong nhà.",
     {"upper_material": "Synthetic Mesh", "sole_material": "Non-marking Rubber",
      "court_type": "Indoor", "player_level": "All levels"},
     "giay mizuno court flex pro", "active", True, "2026-06-06T00:00:00Z"),
    (8, 2, 1, "Giày cầu lông Yonex Court Glide", "giay-yonex-court-glide",
     "Giày nhẹ hỗ trợ đổi hướng nhanh",
     "Sản phẩm demo tập trung độ ôm chân và độ bám.",
     {"upper_material": "Mesh", "sole_material": "Gum Rubber",
      "court_type": "Indoor", "player_level": "Intermediate"},
     "giay yonex court glide", "active", False, "2026-06-07T00:00:00Z"),
    (9, 2, 3, "Giày cầu lông Li-Ning Swift Step", "giay-li-ning-swift-step",
     "Mẫu ngừng trưng bày tạm thời",
     "Sản phẩm inactive phục vụ kiểm thử catalog.",
     {"upper_material": "Synthetic", "sole_material": "Rubber",
      "court_type": "Indoor", "player_level": "Beginner"},
     "giay li-ning swift step", "inactive", False, "2026-05-01T00:00:00Z"),
    (10, 3, 1, "Cầu lông thi đấu Feather Pro 12 quả", "cau-feather-pro-12",
     "Ống 12 quả tốc độ 77 dùng thi đấu nghiệp dư",
     "Sản phẩm demo cầu lông bán theo ống.",
     {"material": "Goose Feather", "speed": "77", "quantity_per_tube": 12,
      "usage": "Training and competition"},
     "cau long feather pro 12", "active", True, "2026-06-08T00:00:00Z"),
    (11, 3, 8, "Cầu lông luyện tập Club Tube 12", "cau-club-tube-12",
     "Ống cầu luyện tập bền cho phòng tập",
     "Sản phẩm demo cầu luyện tập giá hợp lý.",
     {"material": "Duck Feather", "speed": "76", "quantity_per_tube": 12,
      "usage": "Training"},
     "cau long club tube 12", "active", False, "2026-06-09T00:00:00Z"),
    (12, 4, 2, "Cước đan vợt Control Spin 0.66 mm", "cuoc-control-spin-066",
     "Dây cảm giác xoáy và kiểm soát",
     "Sản phẩm demo dây đan nhiều màu.",
     {"gauge_mm": 0.66, "feel": "Medium", "durability": "Medium", "control": "High"},
     "cuoc control spin 0.66", "active", False, "2026-06-10T00:00:00Z"),
    (13, 4, 1, "Cước đan vợt Power Smash 0.68", "cuoc-power-smash-068",
     "Dây thiên lực cho lối đánh smash",
     "Sản phẩm demo dây đan độ bền trung bình.",
     {"gauge_mm": 0.68, "feel": "Firm", "durability": "High", "control": "Medium"},
     "cuoc power smash 0.68", "active", False, "2026-06-11T00:00:00Z"),
    (14, 4, 8, "Cước đan vợt Soft Feel 0.70", "cuoc-soft-feel-070",
     "Bản draft đang hiệu chỉnh thông số",
     "Sản phẩm draft chưa mở bán.",
     {"gauge_mm": 0.70, "feel": "Soft", "durability": "Medium", "control": "Medium"},
     "cuoc soft feel 0.70 draft", "draft", False, None),
    (15, 5, 8, "Quấn cán Comfort Dry Pack", "quan-can-comfort-dry-pack",
     "Quấn cán thấm hút bán lẻ và theo pack",
     "Sản phẩm demo grip Comfort Dry.",
     {"material": "PU", "absorbency": "High", "thickness_mm": 0.6},
     "quan can comfort dry", "active", True, "2026-06-12T00:00:00Z"),
    (16, 5, 7, "Quấn cán Towel Grip Classic", "quan-can-towel-grip-classic",
     "Grip khăn thấm mồ hôi tốt",
     "Sản phẩm demo towel grip.",
     {"material": "Towel", "absorbency": "Very High", "thickness_mm": 1.2},
     "quan can towel grip", "active", False, "2026-06-13T00:00:00Z"),
    (17, 5, 2, "Quấn cán Pro Overgrip Thin", "quan-can-pro-overgrip-thin",
     "Overgrip mỏng tăng cảm giác cầm",
     "Sản phẩm demo overgrip mỏng.",
     {"material": "PU Thin", "absorbency": "Medium", "thickness_mm": 0.4},
     "quan can overgrip thin", "active", False, "2026-06-14T00:00:00Z"),
    (18, 6, 6, "Túi vợt Tournament Pro 6 ngăn", "tui-tournament-pro-6",
     "Túi 6 ngăn có ngăn giày riêng",
     "Sản phẩm demo túi vợt thi đấu.",
     {"capacity_rackets": 6, "has_shoe_compartment": True, "material": "Polyester"},
     "tui vot tournament pro 6", "active", False, "2026-06-15T00:00:00Z"),
    (19, 6, 7, "Balo cầu lông Court Daypack", "balo-court-daypack",
     "Balo hàng ngày tạm ngưng bán",
     "Sản phẩm inactive kiểm thử RLS/catalog.",
     {"capacity_rackets": 2, "has_shoe_compartment": False, "material": "Nylon"},
     "balo court daypack", "inactive", False, "2026-04-01T00:00:00Z"),
    (20, 7, 3, "Áo thi đấu Match Jersey Pro", "ao-match-jersey-pro",
     "Áo thi đấu thoáng khí nhiều size",
     "Sản phẩm demo áo cầu lông.",
     {"fit": "Regular", "fabric": "Polyester Mesh", "breathability": "High"},
     "ao match jersey pro", "active", False, "2026-06-16T00:00:00Z"),
    (21, 7, 7, "Quần short Court Flex", "quan-short-court-flex",
     "Quần short co giãn cho tập luyện",
     "Sản phẩm demo quần short.",
     {"fit": "Athletic", "fabric": "Stretch Polyester", "pockets": 2},
     "quan short court flex", "active", False, "2026-06-17T00:00:00Z"),
    (22, 8, 7, "Vớ thể thao Court Cushion", "vo-court-cushion",
     "Vớ đệm gót và bàn chân trước",
     "Sản phẩm demo vớ thể thao.",
     {"cushion": "Medium", "length": "Ankle", "pairs_per_pack": 1},
     "vo court cushion", "active", False, "2026-06-18T00:00:00Z"),
    (23, 9, 5, "Băng hỗ trợ cổ tay Support Band", "bang-co-tay-support-band",
     "Mẫu đã lưu trữ lịch sử",
     "Sản phẩm archived — giữ tham chiếu lịch sử.",
     {"support_level": "Medium", "side": "Unisex", "material": "Elastic"},
     "bang co tay support band", "archived", False, "2026-01-15T00:00:00Z"),
    (24, 10, 8, "Thang tập chân Footwork Ladder 4m", "thang-footwork-ladder-4m",
     "Thang tập chân dài 4 mét",
     "Sản phẩm demo phụ kiện luyện tập chân.",
     {"length_m": 4, "rungs": 8, "material": "Nylon webbing"},
     "thang tap chan footwork ladder", "active", False, "2026-06-19T00:00:00Z"),
]


def build_variants() -> list[dict]:
    """Return variant dicts with stable sequential ids."""
    rows: list[dict] = []
    n = 0

    def add(product: int, sku: str, name: str, price: int, cost: int, **kw) -> None:
        nonlocal n
        n += 1
        compare = kw.pop("compare", None)
        rows.append(
            {
                "id": n,
                "product_id": product,
                "sku": sku,
                "name": name,
                "price": price,
                "cost": cost,
                "compare": compare,
                "color_name": kw.get("color_name"),
                "color_hex": kw.get("color_hex"),
                "racket_weight_class": kw.get("racket_weight_class"),
                "grip_size": kw.get("grip_size"),
                "shoe_size": kw.get("shoe_size"),
                "clothing_size": kw.get("clothing_size"),
                "unit": kw.get("unit", "item"),
                "is_default": kw.get("is_default", False),
                "is_active": kw.get("is_active", True),
                "sort_order": kw.get("sort_order", 1),
            }
        )

    # Racket 1 — 4 variants
    add(1, "RKT-YON-AS88-RED-3U-G5", "3U / G5 Đỏ", 1890000, 1200000,
        compare=2190000, color_name="Đỏ", color_hex="#C62828",
        racket_weight_class="3U", grip_size="G5", is_default=True, sort_order=1)
    add(1, "RKT-YON-AS88-RED-4U-G5", "4U / G5 Đỏ", 1890000, 1200000,
        compare=2190000, color_name="Đỏ", color_hex="#C62828",
        racket_weight_class="4U", grip_size="G5", sort_order=2)
    add(1, "RKT-YON-AS88-BLU-4U-G6", "4U / G6 Xanh", 1920000, 1220000,
        color_name="Xanh dương", color_hex="#1565C0",
        racket_weight_class="4U", grip_size="G6", sort_order=3)
    add(1, "RKT-YON-AS88-BLK-4U-G5", "4U / G5 Đen", 1920000, 1220000,
        color_name="Đen", color_hex="#212121",
        racket_weight_class="4U", grip_size="G5", sort_order=4)

    # Racket 2 — 4
    add(2, "RKT-VIC-PCX7-BLK-3U-G5", "3U / G5 Đen", 2450000, 1500000,
        compare=2690000, color_name="Đen", color_hex="#212121",
        racket_weight_class="3U", grip_size="G5", is_default=True, sort_order=1)
    add(2, "RKT-VIC-PCX7-BLK-4U-G5", "4U / G5 Đen", 2450000, 1500000,
        compare=2690000, color_name="Đen", color_hex="#212121",
        racket_weight_class="4U", grip_size="G5", sort_order=2)
    add(2, "RKT-VIC-PCX7-ORG-4U-G6", "4U / G6 Cam", 2490000, 1520000,
        color_name="Cam", color_hex="#EF6C00",
        racket_weight_class="4U", grip_size="G6", sort_order=3)
    add(2, "RKT-VIC-PCX7-WHT-3U-G5", "3U / G5 Trắng", 2490000, 1520000,
        color_name="Trắng", color_hex="#FAFAFA",
        racket_weight_class="3U", grip_size="G5", sort_order=4)

    # Racket 3 — 3
    add(3, "RKT-LIN-WB900-BLU-4U-G5", "4U / G5 Xanh", 1650000, 980000,
        color_name="Xanh dương", color_hex="#1E88E5",
        racket_weight_class="4U", grip_size="G5", is_default=True, sort_order=1)
    add(3, "RKT-LIN-WB900-BLU-4U-G6", "4U / G6 Xanh", 1650000, 980000,
        color_name="Xanh dương", color_hex="#1E88E5",
        racket_weight_class="4U", grip_size="G6", sort_order=2)
    add(3, "RKT-LIN-WB900-GRN-5U-G5", "5U / G5 Xanh lá", 1590000, 950000,
        color_name="Xanh lá", color_hex="#2E7D32",
        racket_weight_class="5U", grip_size="G5", sort_order=3)

    # Racket 4 — 3
    add(4, "RKT-MIZ-TP-GRY-3U-G5", "3U / G5 Xám", 1290000, 780000,
        color_name="Xám", color_hex="#757575",
        racket_weight_class="3U", grip_size="G5", is_default=True, sort_order=1)
    add(4, "RKT-MIZ-TP-GRY-4U-G5", "4U / G5 Xám", 1290000, 780000,
        color_name="Xám", color_hex="#757575",
        racket_weight_class="4U", grip_size="G5", sort_order=2)
    add(4, "RKT-MIZ-TP-BLU-4U-G6", "4U / G6 Xanh", 1320000, 800000,
        color_name="Xanh dương", color_hex="#1976D2",
        racket_weight_class="4U", grip_size="G6", sort_order=3)

    # Racket 5 — 2
    add(5, "RKT-KUM-SL5-YEL-5U-G5", "5U / G5 Vàng", 890000, 520000,
        color_name="Vàng", color_hex="#F9A825",
        racket_weight_class="5U", grip_size="G5", is_default=True, sort_order=1)
    add(5, "RKT-KUM-SL5-YEL-4U-G5", "4U / G5 Vàng", 920000, 540000,
        color_name="Vàng", color_hex="#F9A825",
        racket_weight_class="4U", grip_size="G5", sort_order=2)

    # Racket 6 draft — 1 inactive-ish but default
    add(6, "RKT-APA-FP99-BLK-4U-G5", "4U / G5 Đen (draft)", 2100000, 1300000,
        color_name="Đen", color_hex="#000000",
        racket_weight_class="4U", grip_size="G5", is_default=True,
        is_active=False, sort_order=1)

    # Shoes 7 — sizes 39-43
    for i, size in enumerate(["39", "40", "41", "42", "43"], start=1):
        add(7, f"SHO-MIZ-CFP-WHT-{size}", f"Size {size}", 1590000, 900000,
            color_name="Trắng", color_hex="#FAFAFA", shoe_size=size,
            is_default=(size == "41"), sort_order=i)

    # Shoes 8 — 39-43
    for i, size in enumerate(["39", "40", "41", "42", "43"], start=1):
        add(8, f"SHO-YON-CG-BLK-{size}", f"Size {size}", 1450000, 820000,
            color_name="Đen", color_hex="#212121", shoe_size=size,
            is_default=(size == "42"), sort_order=i)

    # Shoes 9 inactive — 40-42
    for i, size in enumerate(["40", "41", "42"], start=1):
        add(9, f"SHO-LIN-SS-GRY-{size}", f"Size {size}", 990000, 550000,
            compare=1190000, color_name="Xám", color_hex="#9E9E9E", shoe_size=size,
            is_default=(size == "41"), is_active=False, sort_order=i)

    # Shuttlecocks
    add(10, "SHT-YON-FP-TUBE12", "Ống 12 quả", 520000, 320000,
        unit="tube", is_default=True, sort_order=1)
    add(11, "SHT-PRO-CLUB-TUBE12", "Ống 12 quả", 280000, 160000,
        unit="tube", is_default=True, sort_order=1)

    # Strings colors
    for i, (name, hex_, code) in enumerate(
        [("Trắng", "#FFFFFF", "WHT"), ("Đen", "#000000", "BLK"),
         ("Vàng", "#F9A825", "YEL"), ("Xanh dương", "#1E88E5", "BLU"),
         ("Đỏ", "#E53935", "RED")],
        start=1,
    ):
        add(12, f"STR-CTL-066-{code}", name, 180000, 90000,
            color_name=name, color_hex=hex_, unit="set",
            is_default=(code == "WHT"), sort_order=i)

    for i, (name, hex_, code) in enumerate(
        [("Trắng", "#FFFFFF", "WHT"), ("Đen", "#000000", "BLK"), ("Đỏ", "#C62828", "RED")],
        start=1,
    ):
        add(13, f"STR-PWR-068-{code}", name, 220000, 110000,
            color_name=name, color_hex=hex_, unit="set",
            is_default=(code == "BLK"), sort_order=i)

    add(14, "STR-SFT-070-WHT", "Trắng (draft)", 150000, 70000,
        color_name="Trắng", color_hex="#FFFFFF", unit="set",
        is_default=True, is_active=False, sort_order=1)

    # Grips
    add(15, "GRP-COM-DRY-BLK-1", "1 cuốn", 35000, 15000,
        color_name="Đen", color_hex="#000000", unit="item",
        is_default=True, sort_order=1)
    add(15, "GRP-COM-DRY-BLK-P3", "Pack 3 cuốn", 99000, 40000,
        compare=105000, color_name="Đen", color_hex="#000000", unit="pack", sort_order=2)
    add(15, "GRP-COM-DRY-BLK-P5", "Pack 5 cuốn", 155000, 65000,
        compare=175000, color_name="Đen", color_hex="#000000", unit="pack", sort_order=3)

    add(16, "GRP-TWL-CLS-WHT-1", "1 cuốn Trắng", 45000, 20000,
        color_name="Trắng", color_hex="#FFFFFF", is_default=True, sort_order=1)
    add(16, "GRP-TWL-CLS-BLU-1", "1 cuốn Xanh", 45000, 20000,
        color_name="Xanh dương", color_hex="#1565C0", sort_order=2)

    add(17, "GRP-PRO-OVG-BLK-1", "1 cuốn", 39000, 18000,
        color_name="Đen", color_hex="#000000", is_default=True, sort_order=1)
    add(17, "GRP-PRO-OVG-RED-P3", "Pack 3 cuốn", 110000, 50000,
        color_name="Đỏ", color_hex="#E53935", unit="pack", sort_order=2)

    # Bags
    add(18, "BAG-APA-TP6-BLK", "Đen", 1290000, 700000,
        color_name="Đen", color_hex="#212121", is_default=True, sort_order=1)
    add(18, "BAG-APA-TP6-BLU", "Xanh dương", 1320000, 720000,
        color_name="Xanh dương", color_hex="#1565C0", sort_order=2)
    add(19, "BAG-KAM-CDP-GRY", "Xám", 690000, 380000,
        color_name="Xám", color_hex="#9E9E9E", is_default=True, is_active=False)

    # Clothing
    for i, size in enumerate(["S", "M", "L", "XL", "XXL"], start=1):
        add(20, f"CLT-LIN-MJP-RED-{size}", f"Size {size}", 390000, 180000,
            color_name="Đỏ", color_hex="#E53935", clothing_size=size,
            is_default=(size == "M"), sort_order=i)
    for i, size in enumerate(["S", "M", "L", "XL"], start=1):
        add(21, f"CLT-KAM-CSF-NVY-{size}", f"Size {size}", 320000, 150000,
            color_name="Navy", color_hex="#0D47A1", clothing_size=size,
            is_default=(size == "L"), sort_order=i)

    add(22, "SOK-KAM-CC-WHT-FREE", "Free size", 89000, 35000,
        color_name="Trắng", color_hex="#FFFFFF", unit="pair", is_default=True)
    add(23, "PRT-KUM-SB-BLK-ONE", "One size", 120000, 50000,
        color_name="Đen", color_hex="#000000", is_default=True, is_active=False)
    add(24, "TRN-PRO-FL-4M", "4 mét", 250000, 120000, is_default=True)

    return rows


def build_inventory(variants: list[dict]) -> list[dict]:
    """Assign stock scenarios by SKU patterns / index."""
    inv = []
    out_of_stock_skus = {
        "RKT-YON-AS88-BLK-4U-G5",
        "SHO-YON-CG-BLK-39",
        "STR-CTL-066-RED",
        "CLT-LIN-MJP-RED-XXL",
    }
    low_stock_skus = {
        "RKT-YON-AS88-BLU-4U-G6": (3, 1, 5, False),
        "RKT-VIC-PCX7-ORG-4U-G6": (2, 0, 5, False),
        "SHO-MIZ-CFP-WHT-39": (4, 1, 5, False),
        "STR-CTL-066-YEL": (2, 0, 5, False),
        "GRP-COM-DRY-BLK-1": (3, 0, 10, False),
    }
    backorder_sku = "BAG-APA-TP6-BLU"

    for v in variants:
        sku = v["sku"]
        if sku in out_of_stock_skus:
            on_hand, reserved, reorder, back = 0, 0, 5, False
        elif sku in low_stock_skus:
            on_hand, reserved, reorder, back = low_stock_skus[sku]
        elif sku == backorder_sku:
            on_hand, reserved, reorder, back = 0, 0, 3, True
        elif not v["is_active"]:
            on_hand, reserved, reorder, back = 0, 0, 0, False
        elif v["is_default"] and v["product_id"] <= 3:
            on_hand, reserved, reorder, back = 45, 2, 8, False
        else:
            # normal 5-25 range by id
            on_hand = 5 + (v["id"] % 21)
            reserved = 1 if on_hand > 10 and v["id"] % 7 == 0 else 0
            reorder, back = 5, False
        inv.append(
            {
                "variant_id": v["id"],
                "quantity_on_hand": on_hand,
                "quantity_reserved": reserved,
                "reorder_level": reorder,
                "allow_backorder": back,
            }
        )
    return inv


def build_images(variants: list[dict]) -> list[dict]:
    images = []
    n = 0
    featured = {1, 2, 3, 7, 10, 15}
    color_variant_products = {1, 2}  # add one variant-specific image each

    for p in PRODUCTS:
        pid = p[0]
        name = p[3]
        n += 1
        images.append(
            {
                "id": n,
                "product_id": pid,
                "variant_id": None,
                "storage_path": f"product-images/{uid(0x30000000, pid)}/main.webp",
                "alt_text": f"Ảnh chính {name}",
                "sort_order": 0,
                "is_primary": True,
            }
        )
        if pid in featured:
            n += 1
            images.append(
                {
                    "id": n,
                    "product_id": pid,
                    "variant_id": None,
                    "storage_path": f"product-images/{uid(0x30000000, pid)}/gallery-01.webp",
                    "alt_text": f"Ảnh phụ {name}",
                    "sort_order": 1,
                    "is_primary": False,
                }
            )

    # Variant-specific images for color differences (product 1 first blue variant)
    for v in variants:
        if v["product_id"] in color_variant_products and v["color_hex"] == "#1565C0":
            n += 1
            images.append(
                {
                    "id": n,
                    "product_id": v["product_id"],
                    "variant_id": v["id"],
                    "storage_path": (
                        f"product-images/{uid(0x30000000, v['product_id'])}/"
                        f"{v['sku'].lower()}.webp"
                    ),
                    "alt_text": f"Ảnh biến thể {v['name']}",
                    "sort_order": 0,
                    "is_primary": True,
                }
            )
            break
    for v in variants:
        if v["product_id"] == 2 and v["color_hex"] == "#EF6C00":
            n += 1
            images.append(
                {
                    "id": n,
                    "product_id": 2,
                    "variant_id": v["id"],
                    "storage_path": (
                        f"product-images/{uid(0x30000000, 2)}/{v['sku'].lower()}.webp"
                    ),
                    "alt_text": f"Ảnh biến thể {v['name']}",
                    "sort_order": 0,
                    "is_primary": True,
                }
            )
            break
    return images


def render_catalog_sql(include_transaction: bool = True) -> str:
    variants = build_variants()
    inventory = build_inventory(variants)
    images = build_images(variants)

    lines: list[str] = []
    lines.append("-- Catalog seed data for Badminton Store")
    lines.append("-- Generated by scripts/generate_catalog_seed.py — do not hand-edit.")
    lines.append("-- Scope: categories, brands, products, product_variants,")
    lines.append("--        product_images, inventory only.")
    lines.append("-- Idempotent via ON CONFLICT. Deterministic UUID ranges:")
    lines.append("--   categories 10000000-..., brands 20000000-...,")
    lines.append("--   products 30000000-..., variants 40000000-..., images 50000000-...")
    lines.append("")
    if include_transaction:
        lines.append("begin;")
        lines.append("")

    # Categories
    lines.append("-- ========== categories ==========")
    lines.append(
        "insert into public.categories "
        "(id, parent_id, name, slug, description, image_path, sort_order, is_active)"
    )
    lines.append("values")
    cat_vals = []
    for n, name, slug, desc, sort in CATEGORIES:
        cat_vals.append(
            "  ("
            f"{sql_str(uid(0x10000000, n))}, null, {sql_str(name)}, {sql_str(slug)}, "
            f"{sql_str(desc)}, {sql_str(f'category-assets/{uid(0x10000000, n)}/main.webp')}, "
            f"{sort}, true)"
        )
    lines.append(",\n".join(cat_vals))
    lines.append(
        "on conflict (id) do update set\n"
        "  name = excluded.name,\n"
        "  slug = excluded.slug,\n"
        "  description = excluded.description,\n"
        "  image_path = excluded.image_path,\n"
        "  sort_order = excluded.sort_order,\n"
        "  is_active = excluded.is_active,\n"
        "  updated_at = timezone('utc', now());"
    )
    lines.append("")

    # Brands
    lines.append("-- ========== brands ==========")
    lines.append(
        "insert into public.brands "
        "(id, name, slug, description, logo_path, country_of_origin, sort_order, is_active)"
    )
    lines.append("values")
    brand_vals = []
    for n, name, slug, desc, country, sort in BRANDS:
        brand_vals.append(
            "  ("
            f"{sql_str(uid(0x20000000, n))}, {sql_str(name)}, {sql_str(slug)}, "
            f"{sql_str(desc)}, {sql_str(f'brand-assets/{uid(0x20000000, n)}/logo.webp')}, "
            f"{sql_str(country)}, {sort}, true)"
        )
    lines.append(",\n".join(brand_vals))
    lines.append(
        "on conflict (id) do update set\n"
        "  name = excluded.name,\n"
        "  slug = excluded.slug,\n"
        "  description = excluded.description,\n"
        "  logo_path = excluded.logo_path,\n"
        "  country_of_origin = excluded.country_of_origin,\n"
        "  sort_order = excluded.sort_order,\n"
        "  is_active = excluded.is_active,\n"
        "  updated_at = timezone('utc', now());"
    )
    lines.append("")

    # Products
    lines.append("-- ========== products ==========")
    lines.append(
        "insert into public.products (\n"
        "  id, category_id, brand_id, name, slug, short_description, description,\n"
        "  specifications, search_keywords, status, is_featured, published_at\n"
        ")"
    )
    lines.append("values")
    prod_vals = []
    for row in PRODUCTS:
        n, cat, brand, name, slug, short, desc, specs, kw, status, featured, pub = row
        pub_sql = "null" if pub is None else sql_str(pub)
        prod_vals.append(
            "  ("
            f"{sql_str(uid(0x30000000, n))}, {sql_str(uid(0x10000000, cat))}, "
            f"{sql_str(uid(0x20000000, brand))}, {sql_str(name)}, {sql_str(slug)}, "
            f"{sql_str(short)}, {sql_str(desc)}, {sql_json(specs)}, {sql_str(kw)}, "
            f"{sql_str(status)}, {sql_bool(featured)}, {pub_sql})"
        )
    lines.append(",\n".join(prod_vals))
    lines.append(
        "on conflict (id) do update set\n"
        "  category_id = excluded.category_id,\n"
        "  brand_id = excluded.brand_id,\n"
        "  name = excluded.name,\n"
        "  slug = excluded.slug,\n"
        "  short_description = excluded.short_description,\n"
        "  description = excluded.description,\n"
        "  specifications = excluded.specifications,\n"
        "  search_keywords = excluded.search_keywords,\n"
        "  status = excluded.status,\n"
        "  is_featured = excluded.is_featured,\n"
        "  published_at = excluded.published_at,\n"
        "  updated_at = timezone('utc', now());"
    )
    lines.append("")

    # Variants
    lines.append("-- ========== product_variants ==========")
    lines.append(
        "insert into public.product_variants (\n"
        "  id, product_id, sku, name, color_name, color_hex, racket_weight_class,\n"
        "  grip_size, shoe_size, clothing_size, unit, price, compare_at_price,\n"
        "  cost_price, is_default, is_active, sort_order\n"
        ")"
    )
    lines.append("values")
    var_vals = []
    for v in variants:
        var_vals.append(
            "  ("
            f"{sql_str(uid(0x40000000, v['id']))}, "
            f"{sql_str(uid(0x30000000, v['product_id']))}, "
            f"{sql_str(v['sku'])}, {sql_str(v['name'])}, "
            f"{sql_str(v['color_name'])}, {sql_str(v['color_hex'])}, "
            f"{sql_str(v['racket_weight_class'])}, {sql_str(v['grip_size'])}, "
            f"{sql_str(v['shoe_size'])}, {sql_str(v['clothing_size'])}, "
            f"{sql_str(v['unit'])}, {sql_num(v['price'])}, {sql_num(v['compare'])}, "
            f"{sql_num(v['cost'])}, {sql_bool(v['is_default'])}, "
            f"{sql_bool(v['is_active'])}, {v['sort_order']})"
        )
    lines.append(",\n".join(var_vals))
    lines.append(
        "on conflict (id) do update set\n"
        "  product_id = excluded.product_id,\n"
        "  sku = excluded.sku,\n"
        "  name = excluded.name,\n"
        "  color_name = excluded.color_name,\n"
        "  color_hex = excluded.color_hex,\n"
        "  racket_weight_class = excluded.racket_weight_class,\n"
        "  grip_size = excluded.grip_size,\n"
        "  shoe_size = excluded.shoe_size,\n"
        "  clothing_size = excluded.clothing_size,\n"
        "  unit = excluded.unit,\n"
        "  price = excluded.price,\n"
        "  compare_at_price = excluded.compare_at_price,\n"
        "  cost_price = excluded.cost_price,\n"
        "  is_default = excluded.is_default,\n"
        "  is_active = excluded.is_active,\n"
        "  sort_order = excluded.sort_order,\n"
        "  updated_at = timezone('utc', now());"
    )
    lines.append("")

    # Images
    lines.append("-- ========== product_images ==========")
    lines.append(
        "insert into public.product_images "
        "(id, product_id, variant_id, storage_path, alt_text, sort_order, is_primary)"
    )
    lines.append("values")
    img_vals = []
    for img in images:
        vid = (
            "null"
            if img["variant_id"] is None
            else sql_str(uid(0x40000000, img["variant_id"]))
        )
        img_vals.append(
            "  ("
            f"{sql_str(uid(0x50000000, img['id']))}, "
            f"{sql_str(uid(0x30000000, img['product_id']))}, {vid}, "
            f"{sql_str(img['storage_path'])}, {sql_str(img['alt_text'])}, "
            f"{img['sort_order']}, {sql_bool(img['is_primary'])})"
        )
    lines.append(",\n".join(img_vals))
    lines.append(
        "on conflict (id) do update set\n"
        "  product_id = excluded.product_id,\n"
        "  variant_id = excluded.variant_id,\n"
        "  storage_path = excluded.storage_path,\n"
        "  alt_text = excluded.alt_text,\n"
        "  sort_order = excluded.sort_order,\n"
        "  is_primary = excluded.is_primary,\n"
        "  updated_at = timezone('utc', now());"
    )
    lines.append("")

    # Inventory
    lines.append("-- ========== inventory ==========")
    lines.append(
        "insert into public.inventory "
        "(variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder)"
    )
    lines.append("values")
    inv_vals = []
    for row in inventory:
        inv_vals.append(
            "  ("
            f"{sql_str(uid(0x40000000, row['variant_id']))}, "
            f"{row['quantity_on_hand']}, {row['quantity_reserved']}, "
            f"{row['reorder_level']}, {sql_bool(row['allow_backorder'])})"
        )
    lines.append(",\n".join(inv_vals))
    lines.append(
        "on conflict (variant_id) do update set\n"
        "  quantity_on_hand = excluded.quantity_on_hand,\n"
        "  quantity_reserved = excluded.quantity_reserved,\n"
        "  reorder_level = excluded.reorder_level,\n"
        "  allow_backorder = excluded.allow_backorder,\n"
        "  updated_at = timezone('utc', now());"
    )
    lines.append("")

    if include_transaction:
        lines.append("commit;")
        lines.append("")

    # Stats comment
    status_counts: dict[str, int] = {}
    for p in PRODUCTS:
        status_counts[p[9]] = status_counts.get(p[9], 0) + 1
    lines.append(
        f"-- Counts: categories={len(CATEGORIES)} brands={len(BRANDS)} "
        f"products={len(PRODUCTS)} variants={len(variants)} "
        f"images={len(images)} inventory={len(inventory)}"
    )
    lines.append(f"-- Product status: {status_counts}")
    lines.append(
        f"-- Featured active: {sum(1 for p in PRODUCTS if p[10] and p[9] == 'active')}"
    )

    return "\n".join(lines) + "\n", variants, inventory, images


def write_csvs(variants: list[dict], inventory: list[dict], images: list[dict]) -> None:
    IMPORT_DIR.mkdir(parents=True, exist_ok=True)

    with (IMPORT_DIR / "categories.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["id", "parent_id", "name", "slug", "description", "image_path",
             "sort_order", "is_active"]
        )
        for n, name, slug, desc, sort in CATEGORIES:
            w.writerow(
                [uid(0x10000000, n), "", name, slug, desc,
                 f"category-assets/{uid(0x10000000, n)}/main.webp", sort, "true"]
            )

    with (IMPORT_DIR / "brands.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["id", "name", "slug", "description", "logo_path", "website_url",
             "country_of_origin", "sort_order", "is_active"]
        )
        for n, name, slug, desc, country, sort in BRANDS:
            w.writerow(
                [uid(0x20000000, n), name, slug, desc,
                 f"brand-assets/{uid(0x20000000, n)}/logo.webp", "", country, sort, "true"]
            )

    with (IMPORT_DIR / "products.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["id", "category_id", "brand_id", "name", "slug", "short_description",
             "description", "specifications_json", "search_keywords", "status",
             "is_featured", "published_at"]
        )
        for row in PRODUCTS:
            n, cat, brand, name, slug, short, desc, specs, kw, status, featured, pub = row
            w.writerow(
                [
                    uid(0x30000000, n),
                    uid(0x10000000, cat),
                    uid(0x20000000, brand),
                    name,
                    slug,
                    short,
                    desc,
                    json.dumps(specs, ensure_ascii=False),
                    kw,
                    status,
                    "true" if featured else "false",
                    pub or "",
                ]
            )

    with (IMPORT_DIR / "product_variants.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["id", "product_id", "sku", "name", "color_name", "color_hex",
             "racket_weight_class", "grip_size", "shoe_size", "clothing_size",
             "unit", "price", "compare_at_price", "cost_price", "barcode",
             "is_default", "is_active", "sort_order"]
        )
        for v in variants:
            w.writerow(
                [
                    uid(0x40000000, v["id"]),
                    uid(0x30000000, v["product_id"]),
                    v["sku"],
                    v["name"],
                    v["color_name"] or "",
                    v["color_hex"] or "",
                    v["racket_weight_class"] or "",
                    v["grip_size"] or "",
                    v["shoe_size"] or "",
                    v["clothing_size"] or "",
                    v["unit"],
                    f"{v['price']:.2f}",
                    "" if v["compare"] is None else f"{v['compare']:.2f}",
                    f"{v['cost']:.2f}",
                    "",
                    "true" if v["is_default"] else "false",
                    "true" if v["is_active"] else "false",
                    v["sort_order"],
                ]
            )

    with (IMPORT_DIR / "product_images.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["id", "product_id", "variant_id", "storage_path", "alt_text",
             "sort_order", "is_primary"]
        )
        for img in images:
            w.writerow(
                [
                    uid(0x50000000, img["id"]),
                    uid(0x30000000, img["product_id"]),
                    "" if img["variant_id"] is None else uid(0x40000000, img["variant_id"]),
                    img["storage_path"],
                    img["alt_text"],
                    img["sort_order"],
                    "true" if img["is_primary"] else "false",
                ]
            )

    with (IMPORT_DIR / "inventory.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["variant_id", "quantity_on_hand", "quantity_reserved",
             "reorder_level", "allow_backorder"]
        )
        for row in inventory:
            w.writerow(
                [
                    uid(0x40000000, row["variant_id"]),
                    row["quantity_on_hand"],
                    row["quantity_reserved"],
                    row["reorder_level"],
                    "true" if row["allow_backorder"] else "false",
                ]
            )


def main() -> None:
    sql, variants, inventory, images = render_catalog_sql(include_transaction=True)
    SEED_PATH.write_text(sql, encoding="utf-8")

    migration_header = (
        "-- Demo catalog data migration (OPTIONAL deploy via db push).\n"
        "-- Inserts only public catalog tables — no auth/users/orders.\n"
        "-- Idempotent. Prefer local seed via `supabase db reset` during development.\n"
        "-- Generated by scripts/generate_catalog_seed.py\n\n"
    )
    mig_sql, _, _, _ = render_catalog_sql(include_transaction=True)
    MIGRATION_PATH.write_text(migration_header + mig_sql, encoding="utf-8")

    write_csvs(variants, inventory, images)

    status_counts: dict[str, int] = {}
    for p in PRODUCTS:
        status_counts[p[9]] = status_counts.get(p[9], 0) + 1

    print("Wrote", SEED_PATH)
    print("Wrote", MIGRATION_PATH)
    print("Wrote CSVs in", IMPORT_DIR)
    print(
        f"counts categories={len(CATEGORIES)} brands={len(BRANDS)} "
        f"products={len(PRODUCTS)} variants={len(variants)} "
        f"images={len(images)} inventory={len(inventory)}"
    )
    print("status", status_counts)
    print(
        "featured",
        sum(1 for p in PRODUCTS if p[10] and p[9] == "active"),
    )
    low = sum(1 for i in inventory if 0 < i["quantity_on_hand"] <= 4)
    oos = sum(1 for i in inventory if i["quantity_on_hand"] == 0 and not i["allow_backorder"])
    print(f"low_stock={low} out_of_stock={oos}")


if __name__ == "__main__":
    main()
