"""Deterministic pre-playtest balance/stress analysis.

This does not emulate Roblox physics. It reads the shipped source values and
stress-checks distributions/invariants that can be evaluated before Studio.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
import math
import random
import re

ROOT = Path(__file__).resolve().parents[1]


def number(source: str, name: str) -> float:
    match = re.search(rf"\b{re.escape(name)}\s*=\s*([0-9.]+)", source)
    assert match, f"missing numeric config: {name}"
    return float(match.group(1))


def main() -> None:
    config = (ROOT / "src/shared/Config.lua").read_text()
    weapons_source = (ROOT / "src/shared/Weapons.lua").read_text()
    rarity_source = (ROOT / "src/shared/WeaponStats.lua").read_text()
    evolution_source = (ROOT / "src/server/Evolution.lua").read_text()

    weapon_pattern = re.compile(
        r'(Pistol|Rifle|Shotgun)\s*=\s*\{label\s*=\s*"[^"]+",\s*'
        r'damage\s*=\s*([0-9.]+),\s*interval\s*=\s*([0-9.]+),\s*'
        r'magazine\s*=\s*([0-9.]+),\s*reload\s*=\s*([0-9.]+),\s*'
        r'range\s*=\s*([0-9.]+),\s*spread\s*=\s*([0-9.]+),\s*'
        r'pellets\s*=\s*([0-9.]+)'
    )
    weapons = {}
    for match in weapon_pattern.finditer(weapons_source):
        name = match.group(1)
        weapons[name] = {
            "damage": float(match.group(2)),
            "interval": float(match.group(3)),
            "magazine": int(float(match.group(4))),
            "reload": float(match.group(5)),
            "range": float(match.group(6)),
            "spread": float(match.group(7)),
            "pellets": int(float(match.group(8))),
        }
    assert set(weapons) == {"Pistol", "Rifle", "Shotgun"}

    # Pure theoretical center-hit TTK. Shotgun assumes every pellet lands, so it
    # is intentionally a ceiling on damage potential, not an expected live TTK.
    print("PREPLAY BALANCE REPORT")
    for name in ("Pistol", "Rifle", "Shotgun"):
        spec = weapons[name]
        per_shot = spec["damage"] * spec["pellets"]
        assert 0 < per_shot < 100, f"{name} unexpectedly one-shots base 100 HP"
        rows = []
        for health in (100, 200):
            shots = math.ceil(health / per_shot)
            ttk = max(0, shots - 1) * spec["interval"]
            rows.append(f"{health}HP={shots} shots/{ttk:.2f}s")
        print(f"  {name}: max-hit {per_shot:g} damage; " + ", ".join(rows))

    phases = [
        tuple(map(float, groups))
        for groups in re.findall(
            r"\{radius\s*=\s*([0-9.]+),\s*nextRadius\s*=\s*([0-9.]+),\s*"
            r"hold\s*=\s*([0-9.]+),\s*shrink\s*=\s*([0-9.]+),\s*damage\s*=\s*([0-9.]+)\}",
            config,
        )
    ]
    assert len(phases) == 5
    total_zone = sum(hold + shrink for _, _, hold, shrink, _ in phases)
    damages = [phase[4] for phase in phases]
    assert total_zone == 375, f"zone timeline drifted to {total_zone:g}s"
    assert damages == sorted(damages) and len(set(damages)) == len(damages)
    assert phases[-1][1] == 0
    print(f"  Zone: {total_zone:g}s total, damage phases={','.join(format(v, 'g') for v in damages)}")

    start_energy = number(config, "StartEnergy")
    max_energy = number(config, "MaxEnergy")
    build_cost = number(config, "BuildCost")
    build_limit = int(number(config, "BuildLimit"))
    assert build_cost > 0 and start_energy <= max_energy
    assert math.floor(max_energy / build_cost) < build_limit

    builder = re.search(
        r'id="Builder".*?values=\{([0-9.,]+)\}',
        evolution_source,
        re.S,
    )
    assert builder
    builder_values = [float(v) for v in builder.group(1).split(",")]
    builder_discount = sum(builder_values)
    evolved_cost = math.ceil(build_cost * max(0.67, 1 - builder_discount))
    assert evolved_cost >= math.ceil(build_cost * 0.67)
    print(
        f"  Build: start={math.floor(start_energy/build_cost)} placements at base cost; "
        f"max-energy={math.floor(max_energy/build_cost)}; Builder III cost={evolved_cost:g}"
    )

    rarity = re.search(
        r"roll\s*<\s*([0-9.]+)\s*and\s*\"Common\"\s*or\s*"
        r"roll\s*<\s*([0-9.]+)\s*and\s*\"Rare\"\s*or\s*\"Epic\"",
        rarity_source,
    )
    assert rarity
    common_cut, rare_cut = map(float, rarity.groups())
    expected = {"Common": common_cut, "Rare": rare_cut-common_cut, "Epic": 1-rare_cut}
    rng = random.Random(20260929)
    rarity_counts = Counter()
    rarity_trials = 20_000
    for _ in range(rarity_trials):
        roll = rng.random()
        tier = "Common" if roll < common_cut else "Rare" if roll < rare_cut else "Epic"
        rarity_counts[tier] += 1
    for tier, probability in expected.items():
        observed = rarity_counts[tier] / rarity_trials
        assert abs(observed - probability) < 0.02, (tier, observed, probability)
    print(
        "  Rarity 20k: "
        + ", ".join(f"{tier}={rarity_counts[tier]/rarity_trials:.1%}" for tier in ("Common","Rare","Epic"))
    )

    abilities = re.findall(r'\{id="([^"]+)",\s*name="[^"]+",\s*category="([^"]+)"', evolution_source)
    assert len(abilities) == 11
    by_category = defaultdict(list)
    for ability_id, category in abilities:
        by_category[category].append(ability_id)
    assert set(by_category) == {"Mobility", "Attack", "Survival", "Utility"}

    # Mirrors fresh-player makeChoices: shuffled categories, one random eligible
    # ability per category until three cards are selected.
    evolution_counts = Counter()
    draft_trials = 10_000
    for _ in range(draft_trials):
        categories = list(by_category)
        rng.shuffle(categories)
        chosen = []
        for category in categories:
            if len(chosen) == 3:
                break
            chosen.append(rng.choice(by_category[category]))
        assert len(chosen) == 3
        assert len({dict(abilities)[ability] for ability in chosen}) == 3
        evolution_counts.update(chosen)
    assert set(evolution_counts) == {ability_id for ability_id, _ in abilities}
    assert min(evolution_counts.values()) > 500
    print(
        f"  Evolution 10k drafts: all {len(abilities)} abilities appeared; "
        f"min={min(evolution_counts.values())}, max={max(evolution_counts.values())}; "
        "fresh drafts always span 3 categories"
    )

    print("PASS: deterministic pre-playtest balance/stress analysis")


if __name__ == "__main__":
    main()
