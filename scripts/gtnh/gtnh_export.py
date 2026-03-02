#!/usr/bin/env python3
"""
GTNH Data Export - Extracts gameplay data from a GTNH Minecraft server
into gtnh_static.json and gtnh_session.json for Claude AI agent context.
"""

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

EXPORTER_VERSION = "1.0.0"
MAX_JSON_SIZE_MB = 25
GREG_TECH_MAX_TOTAL_MB = 5
GREG_TECH_MAX_FILE_KB = 500


def _strip_formatting(text: str) -> str:
    """Remove Minecraft §. formatting codes."""
    if not text:
        return ""
    return re.sub(r"§.", "", str(text))


def _quest_id_key(low: int, high: int) -> str:
    """Format compound quest ID for use as dict key."""
    if high == 0:
        return str(low)
    return f"{low}:{high}"


def _safe_read_json(path: Path) -> dict | None:
    """Read JSON file, return None on failure with warning."""
    if not path.exists():
        print(f"Warning: Missing file {path}", file=sys.stderr)
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print(f"Warning: Failed to read JSON {path}: {e}", file=sys.stderr)
        return None


def _safe_load_nbt(path: Path):
    """Load NBT file, return None on failure with warning."""
    if not path.exists():
        print(f"Warning: Missing file {path}", file=sys.stderr)
        return None
    try:
        import nbtlib

        return nbtlib.load(str(path))
    except Exception as e:
        print(f"Warning: Failed to load NBT {path}: {e}", file=sys.stderr)
        return None


def _resolve_world_path(server_root: Path) -> Path | None:
    """Return world or World path, whichever exists."""
    for name in ("World", "world"):
        p = server_root / name
        if p.is_dir():
            return p
    return None


def _parse_quest_database(quest_db: dict) -> dict:
    """Extract and trim quest database."""
    result = {}
    db = quest_db.get("questDatabase:9") or {}
    for _key, entry in db.items():
        if not isinstance(entry, dict):
            continue
        low = entry.get("questIDLow:4", 0)
        high = entry.get("questIDHigh:4", 0)
        qid = _quest_id_key(low, high)
        props = (entry.get("properties:10") or {}).get("betterquesting:10") or {}
        name = _strip_formatting(props.get("name:8", ""))
        desc = _strip_formatting(props.get("desc:8", ""))
        is_main = bool(props.get("isMain:1", 0))
        quest_logic = props.get("questLogic:8", "AND")
        prereqs_raw = entry.get("preRequisites:9") or {}
        prereqs = []
        for p in prereqs_raw.values():
            if isinstance(p, dict):
                pl = p.get("questIDLow:4", 0)
                ph = p.get("questIDHigh:4", 0)
                prereqs.append(pl if ph == 0 else f"{pl}:{ph}")
        required_items = []
        tasks = entry.get("tasks:9") or {}
        for task in tasks.values():
            if not isinstance(task, dict):
                continue
            items = task.get("requiredItems:9") or {}
            for item in items.values():
                if isinstance(item, dict):
                    required_items.append(
                        {
                            "id": item.get("id:8", ""),
                            "damage": item.get("Damage:2", 0),
                            "count": item.get("Count:3", 1),
                        }
                    )
        result[qid] = {
            "name": name,
            "desc": desc,
            "is_main": is_main,
            "quest_logic": quest_logic,
            "prereqs": prereqs,
            "required_items": required_items,
        }
    return result


def _parse_quest_lines(quest_db: dict) -> dict:
    """Extract quest lines from QuestDatabase.json questLines:9."""
    result = {}
    lines = quest_db.get("questLines:9") or {}
    for _key, line_entry in lines.items():
        if not isinstance(line_entry, dict):
            continue
        props = (line_entry.get("properties:10") or {}).get("betterquesting:10") or {}
        name = _strip_formatting(props.get("name:8", "Unknown"))
        quests_raw = line_entry.get("quests:9") or {}
        quest_ids = []
        for q in quests_raw.values():
            if isinstance(q, dict):
                low = q.get("questIDLow:4", 0)
                high = q.get("questIDHigh:4", 0)
                quest_ids.append(_quest_id_key(low, high))
        result[name] = {"quest_ids": quest_ids, "total_quests": len(quest_ids)}
    return result


def _parse_level_dat(level_path: Path) -> tuple[list[dict], dict | None]:
    """Extract mod list and world state from level.dat. Returns (mod_list, world_state)."""
    nbt = _safe_load_nbt(level_path)
    if nbt is None:
        return [], None
    mod_list = []
    world_state = {}
    try:
        data = nbt.get("Data") or nbt
        if hasattr(data, "get"):
            world_state["day_time"] = int(data.get("DayTime", 0))
            world_state["total_time"] = int(data.get("Time", 0))
            world_state["difficulty"] = int(data.get("Difficulty", 0))
            world_state["hardcore"] = bool(data.get("hardcore", 0))
            rules = data.get("GameRules") or {}
            if hasattr(rules, "items"):
                world_state["game_rules"] = dict(rules)
            else:
                world_state["game_rules"] = {}
        fml = data.get("FML") if hasattr(data, "get") else None
        if fml is None:
            fml = nbt.get("FML")
        mod_list_data = (fml or {}).get("ModList") if hasattr(fml or {}, "get") else None
        if mod_list_data is not None:
            for mod in mod_list_data:
                if hasattr(mod, "get"):
                    mod_list.append(
                        {
                            "id": str(mod.get("ModId", "")),
                            "version": str(mod.get("ModVersion", "")),
                        }
                    )
    except Exception as e:
        print(f"Warning: Error parsing level.dat: {e}", file=sys.stderr)
    return mod_list, world_state if world_state else None


def _walk_gregtech_configs(server_root: Path) -> dict:
    """Walk config/GregTech/ and include text config files."""
    result = {}
    gt_path = server_root / "config" / "GregTech"
    if not gt_path.exists():
        gt_path = server_root / "config" / "gregtech"
    if not gt_path.is_dir():
        return result
    total_size = 0
    max_total = GREG_TECH_MAX_TOTAL_MB * 1024 * 1024
    max_file = GREG_TECH_MAX_FILE_KB * 1024
    files_to_add = []
    for p in gt_path.rglob("*"):
        if not p.is_file():
            continue
        suf = p.suffix.lower()
        if suf not in (".cfg", ".json", ".conf", ".properties"):
            continue
        try:
            size = p.stat().st_size
        except OSError:
            continue
        if size > max_file:
            continue
        try:
            with open(p, "rb") as f:
                raw = f.read(1024)
                if b"\x00" in raw:
                    continue
        except OSError:
            continue
        rel = p.relative_to(server_root)
        files_to_add.append((str(rel), p, size))
    files_to_add.sort(key=lambda x: -x[2])
    for rel, p, size in files_to_add:
        if total_size + size > max_total:
            print(f"Warning: GregTech config total exceeds {GREG_TECH_MAX_TOTAL_MB}MB, skipping {rel}", file=sys.stderr)
            break
        try:
            with open(p, encoding="utf-8", errors="replace") as f:
                result[rel] = f.read()
            total_size += size
        except OSError as e:
            print(f"Warning: Failed to read {p}: {e}", file=sys.stderr)
    return result


def _parse_quest_progress(
    progress_path: Path,
    quest_db: dict,
    quest_lines: dict,
    player_uuid: str,
) -> dict:
    """Parse quest progress and build summary by quest line."""
    progress_data = _safe_read_json(progress_path)
    if not progress_data:
        return {
            "summary": {"total_quests": 0, "completed": 0, "in_progress": 0, "not_started": 0},
            "by_quest_line": {},
            "completed_quest_ids": [],
            "in_progress_quest_ids": [],
        }
    quest_db_dict = _parse_quest_database(quest_db)
    qdb = quest_db_dict
    qlines = quest_lines
    progress_entries = progress_data.get("questProgress:9") or {}
    completed_ids = []
    in_progress_ids = []
    for _idx, entry in progress_entries.items():
        if not isinstance(entry, dict):
            continue
        low = entry.get("questIDLow:4", 0)
        high = entry.get("questIDHigh:4", 0)
        qid = _quest_id_key(low, high)
        completed = entry.get("completed:9") or {}
        is_completed = False
        for c in completed.values():
            if isinstance(c, dict) and c.get("uuid:8") == player_uuid:
                is_completed = True
                break
        if is_completed:
            completed_ids.append(qid)
            continue
        tasks = entry.get("tasks:9") or {}
        has_progress = False
        for t in tasks.values():
            if not isinstance(t, dict):
                continue
            cu = t.get("completeUsers:9") or {}
            for v in cu.values():
                if v == player_uuid:
                    has_progress = True
                    break
            if has_progress:
                break
            up = t.get("userProgress:9") or {}
            for u in up.values():
                if isinstance(u, dict) and u.get("uuid:8") == player_uuid:
                    has_progress = True
                    break
        if has_progress:
            in_progress_ids.append(qid)
    total = len(qdb)
    not_started = total - len(completed_ids) - len(in_progress_ids)
    if not_started < 0:
        not_started = 0
    by_line = {}
    for line_name, line_data in qlines.items():
        qids = line_data.get("quest_ids", [])
        line_completed = [q for q in qids if q in completed_ids]
        line_in_progress = [q for q in qids if q in in_progress_ids]
        qnames = {q: qdb.get(q, {}).get("name", "?") for q in qids}
        by_line[line_name] = {
            "total": len(qids),
            "completed": len(line_completed),
            "in_progress": len(line_in_progress),
            "completed_names": [qnames.get(q, "?") for q in line_completed],
            "in_progress_names": [qnames.get(q, "?") for q in line_in_progress],
        }
    return {
        "summary": {
            "total_quests": total,
            "completed": len(completed_ids),
            "in_progress": len(in_progress_ids),
            "not_started": not_started,
        },
        "by_quest_line": by_line,
        "completed_quest_ids": completed_ids,
        "in_progress_quest_ids": in_progress_ids,
    }


def _parse_player_stats(stats_path: Path) -> dict:
    """Parse player stats JSON."""
    data = _safe_read_json(stats_path)
    if not data:
        return {}
    play_ticks = data.get("stat.playOneMinute", 0)
    walk_cm = data.get("stat.walkOneCm", 0)
    deaths = data.get("stat.deaths", 0)
    mob_kills = data.get("stat.mobKills", 0)
    craft_items = {k: v for k, v in data.items() if k.startswith("stat.craftItem.")}
    items_crafted = sum(craft_items.values())
    blocks_mined = sum(v for k, v in data.items() if k.startswith("stat.mineBlock."))
    top_crafts = sorted(craft_items.items(), key=lambda x: -x[1])[:20]
    notable = {}
    for k, v in top_crafts:
        name = k.replace("stat.craftItem.autogen.", "").replace("stat.craftItem.", "")
        notable[name] = v
    return {
        "play_time_hours": round(play_ticks / 20 / 3600, 2),
        "distance_walked_km": round(walk_cm / 100000, 2),
        "deaths": deaths,
        "mobs_killed": mob_kills,
        "items_crafted": items_crafted,
        "blocks_mined": blocks_mined,
        "notable_crafts": notable,
    }


def _parse_player_dat(player_path: Path) -> dict | None:
    """Parse player .dat NBT."""
    nbt = _safe_load_nbt(player_path)
    if nbt is None:
        return None
    try:
        pos = nbt.get("Pos") or [0, 0, 0]
        dim = int(nbt.get("Dimension", 0))
        health = float(nbt.get("Health", 20))
        food = int(nbt.get("foodLevel", 20))
        xp = int(nbt.get("XpLevel", 0))
        mode = int(nbt.get("playerGameType", 0))
        return {
            "position": {"x": float(pos[0]), "y": float(pos[1]), "z": float(pos[2])},
            "dimension": dim,
            "health": health,
            "food_level": food,
            "xp_level": xp,
            "game_mode": mode,
        }
    except Exception as e:
        print(f"Warning: Error parsing player .dat: {e}", file=sys.stderr)
        return None


def _parse_thaumcraft(thaum_path: Path) -> dict:
    """Parse Thaumcraft .thaum NBT."""
    nbt = _safe_load_nbt(thaum_path)
    if nbt is None:
        return {
            "researches_completed": [],
            "aspects_discovered": {},
            "scanned_entities": [],
            "scanned_objects": [],
            "scanned_phenomena": [],
        }
    result = {
        "researches_completed": [],
        "aspects_discovered": {},
        "scanned_entities": [],
        "scanned_objects": [],
        "scanned_phenomena": [],
    }
    try:
        if hasattr(nbt, "get"):
            res = nbt.get("research") or nbt.get("researches") or []
            if isinstance(res, (list, tuple)):
                result["researches_completed"] = [str(x) for x in res]
            elif isinstance(res, dict):
                result["researches_completed"] = list(res.keys())
    except Exception:
        pass
    return result


def _parse_baubles(baub_path: Path) -> dict:
    """Parse Baubles .baub NBT."""
    nbt = _safe_load_nbt(baub_path)
    if nbt is None:
        return {"equipped": []}
    equipped = []
    try:
        items = nbt.get("Items") or nbt.get("items") or []
        if isinstance(items, (list, tuple)):
            for item in items:
                if hasattr(item, "get"):
                    slot = item.get("Slot") or item.get("slot") or 0
                    id_key = item.get("id") or item.get("id:8") or ""
                    damage = item.get("Damage") or item.get("Damage:2") or 0
                    equipped.append(
                        {"slot": int(slot), "item_id": str(id_key), "damage": int(damage)}
                    )
    except Exception:
        pass
    return {"equipped": equipped}


def _parse_journeymap_waypoints(server_root: Path) -> list:
    """Parse JourneyMap waypoints."""
    jm = server_root / "journeymap" / "data"
    if not jm.exists():
        return []
    waypoints = []
    for sub in ("sp", "mp"):
        sub_path = jm / sub
        if not sub_path.is_dir():
            continue
        for world_dir in sub_path.iterdir():
            if not world_dir.is_dir():
                continue
            wp_dir = world_dir / "waypoints"
            if not wp_dir.is_dir():
                continue
            for wp_file in wp_dir.glob("*.json"):
                data = _safe_read_json(wp_file)
                if not data:
                    continue
                if isinstance(data, dict):
                    waypoints.append(
                        {
                            "name": data.get("name", ""),
                            "x": data.get("x", data.get("iX", 0)),
                            "y": data.get("y", data.get("iY", 0)),
                            "z": data.get("z", data.get("iZ", 0)),
                            "dimension": data.get("dimension", 0),
                        }
                    )
                elif isinstance(data, list):
                    for w in data:
                        if isinstance(w, dict):
                            waypoints.append(
                                {
                                    "name": w.get("name", ""),
                                    "x": w.get("x", w.get("iX", 0)),
                                    "y": w.get("y", w.get("iY", 0)),
                                    "z": w.get("z", w.get("iZ", 0)),
                                    "dimension": w.get("dimension", 0),
                                }
                            )
    return waypoints


def export_static(
    server_root: Path,
    output_dir: Path,
    gtnh_version: str,
) -> dict:
    """Build gtnh_static.json content."""
    world_path = _resolve_world_path(server_root)
    if not world_path:
        print("Warning: No world folder found", file=sys.stderr)
    quest_db_path = (world_path or server_root) / "betterquesting" / "QuestDatabase.json"
    quest_db = _safe_read_json(quest_db_path)
    if not quest_db:
        quest_db = {}
    print("Processing QuestDatabase...")
    quest_database = _parse_quest_database(quest_db)
    print("Processing quest lines...")
    quest_lines = _parse_quest_lines(quest_db)
    level_path = (world_path or server_root) / "level.dat"
    if not level_path.exists():
        level_path = server_root / "World" / "level.dat"
    print("Processing level.dat...")
    mod_list, _ = _parse_level_dat(level_path)
    print("Processing GregTech configs...")
    gregtech_configs = _walk_gregtech_configs(server_root)
    return {
        "metadata": {
            "file_type": "static",
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "gtnh_version": gtnh_version,
            "exporter_version": EXPORTER_VERSION,
        },
        "quest_database": quest_database,
        "quest_lines": quest_lines,
        "mod_list": mod_list,
        "gregtech_configs": gregtech_configs,
    }


def export_session(
    server_root: Path,
    output_dir: Path,
    player_uuid: str,
    player_name: str,
    gtnh_version: str,
) -> dict:
    """Build gtnh_session.json content."""
    world_path = _resolve_world_path(server_root)
    if not world_path:
        print("Warning: No world folder found", file=sys.stderr)
    quest_db_path = (world_path or server_root) / "betterquesting" / "QuestDatabase.json"
    quest_db = _safe_read_json(quest_db_path)
    if not quest_db:
        quest_db = {}
    quest_lines = _parse_quest_lines(quest_db)
    progress_path = (world_path or server_root) / "betterquesting" / "QuestProgress" / f"{player_uuid}.json"
    stats_path = (world_path or server_root) / "stats" / f"{player_uuid}.json"
    level_path = (world_path or server_root) / "level.dat"
    if not level_path.exists():
        level_path = server_root / "World" / "level.dat"
    player_dat_path = (world_path or server_root) / "playerdata" / f"{player_uuid}.dat"
    thaum_path = (world_path or server_root) / "playerdata" / f"{player_name}.thaum"
    baub_path = (world_path or server_root) / "playerdata" / f"{player_name}.baub"
    print("Processing quest progress...")
    quest_progress = _parse_quest_progress(progress_path, quest_db, quest_lines, player_uuid)
    print("Processing player stats...")
    player_stats = _parse_player_stats(stats_path)
    print("Processing level.dat (world state)...")
    _, world_state = _parse_level_dat(level_path)
    print("Processing player .dat...")
    player_state = _parse_player_dat(player_dat_path)
    print("Processing Thaumcraft...")
    thaumcraft = _parse_thaumcraft(thaum_path)
    print("Processing Baubles...")
    baubles = _parse_baubles(baub_path)
    print("Processing JourneyMap waypoints...")
    waypoints = _parse_journeymap_waypoints(server_root)
    return {
        "metadata": {
            "file_type": "session",
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "gtnh_version": gtnh_version,
            "player_uuid": player_uuid,
            "player_name": player_name,
            "exporter_version": EXPORTER_VERSION,
        },
        "quest_progress": quest_progress,
        "player_stats": player_stats,
        "thaumcraft": thaumcraft,
        "baubles": baubles,
        "player_state": player_state,
        "world_state": world_state,
        "journeymap_waypoints": waypoints,
    }


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 5:
        print("Usage: gtnh_export.py <server_root> <output_dir> <player_uuid> <player_name> [--session-only|--static-only]")
        return 1
    server_root = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    player_uuid = sys.argv[3]
    player_name = sys.argv[4]
    session_only = "--session-only" in sys.argv
    static_only = "--static-only" in sys.argv
    if not server_root.is_dir():
        print(f"Error: Server root not found: {server_root}", file=sys.stderr)
        return 1
    quest_db_path = _resolve_world_path(server_root)
    if quest_db_path:
        quest_db_path = quest_db_path / "betterquesting" / "QuestDatabase.json"
    else:
        quest_db_path = server_root / "World" / "betterquesting" / "QuestDatabase.json"
    quest_db = _safe_read_json(quest_db_path)
    gtnh_version = (quest_db or {}).get("build:8", "unknown")
    output_dir.mkdir(parents=True, exist_ok=True)
    if not static_only:
        print("Exporting session data...")
        session_data = export_session(server_root, output_dir, player_uuid, player_name, gtnh_version)
        out_path = output_dir / "gtnh_session.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(session_data, f, indent=2, ensure_ascii=False)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        print(f"Wrote {out_path} ({size_mb:.2f} MB)")
        if size_mb > MAX_JSON_SIZE_MB:
            print(f"Warning: {out_path} exceeds {MAX_JSON_SIZE_MB}MB", file=sys.stderr)
    if not session_only:
        print("Exporting static data...")
        static_data = export_static(server_root, output_dir, gtnh_version)
        out_path = output_dir / "gtnh_static.json"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(static_data, f, indent=2, ensure_ascii=False)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        print(f"Wrote {out_path} ({size_mb:.2f} MB)")
        if size_mb > MAX_JSON_SIZE_MB:
            print(f"Warning: {out_path} exceeds {MAX_JSON_SIZE_MB}MB", file=sys.stderr)
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
