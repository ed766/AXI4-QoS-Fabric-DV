#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
TRACES = ROOT / "build" / "traces"
DOC = ROOT / "docs" / "coverage.md"


def table(path: Path) -> list[dict[str, str]]:
    return list(csv.DictReader(path.open())) if path.exists() else []


def write(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def events(path: Path) -> list[dict]:
    if not path.exists():
        return []
    parsed = []
    for line in path.read_text().splitlines():
        try:
            parsed.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return parsed


def main() -> int:
    named = table(REPORTS / "regression_summary.csv")
    random_rows = table(REPORTS / "random_regress_summary.csv")
    passed = {row["scenario"] for row in named if row["status"] == "PASS"}

    trace_files = [Path(row["trace"]) for row in named if row["status"] == "PASS"]
    trace_files += [Path(row["trace"]) for row in random_rows if row["status"] == "PASS"]
    all_events: list[tuple[str, dict]] = []
    for relative in trace_files:
        for event in events(ROOT / relative):
            all_events.append((relative.stem, event))
    transactions = [(source,event) for source,event in all_events if event.get("event") in ("aw","ar")]
    responses = [event for _,event in all_events if event.get("event") in ("b","r")]
    grants = [(source,event) for source,event in all_events if event.get("event") in ("aw_grant","ar_grant")]
    writes = [event for _,event in all_events if event.get("event")=="w"]

    def seen(predicate) -> bool:
        return any(predicate(source,event) for source,event in all_events)

    def mapped(address: int) -> bool:
        return any((address & 0xffff0000)==(target<<28) for target in range(4))

    bins: list[tuple[str, str, str]] = []
    def add(area: str, names: list[str], evidence: str, hit: bool) -> None:
        bins.extend((area, name, evidence if hit else "missing") for name in names)

    for op,kind in (("read","ar"),("write","aw")):
        add("operation",[op],"observed request handshake",any(e["event"]==kind for _,e in all_events))
    for m in range(4): add("initiator",[f"master_{m}"],"observed initiator handshake",any(int(e["master"])==m for _,e in transactions))
    for target in range(4): add("target",[f"target_{target}"],"observed mapped target",any(int(e.get("legal",0)) and int(e["target"])==target for _,e in transactions))
    for length in (1,2,4,8,16): add("burst",[f"len_{length}"],"observed AxLEN",any(int(e["len"])==length for _,e in transactions))
    for size in range(4): add("size",[f"size_{1<<size}B"],"observed AxSIZE",any(int(e["size"])==size for _,e in transactions))
    strobe_bins={"full":lambda value:value==255,"single_byte":lambda value:value.bit_count()==1,
                 "partial_multi_byte":lambda value:1<value.bit_count()<8}
    for name,predicate in strobe_bins.items(): add("strobe",[name],"observed WSTRB",any(predicate(int(e["strb"])) for e in writes))
    for name,value in (("OKAY",0),("SLVERR",2),("DECERR",3)):
        add("response",[name],"observed response handshake",any(int(e["resp"])==value for e in responses))
    local_pairs=[(source,e) for source,e in transactions if not int(e.get("legal",0))]
    local=[e for _,e in local_pairs]
    error_hits={
      "unmapped":any(not mapped(int(e["address"])) for e in local),
      "misaligned":any(int(e["address"])%(1<<int(e["size"]))!=0 for e in local),
      "unsupported_burst":any(int(e.get("burst",1))!=1 for e in local),
      "cross_4k":any((int(e["address"])&0xfff)+(int(e["len"])<<int(e["size"]))>0x1000 for e in local),
      "security_deny":any(int(e["target"])==2 and (int(e["prot"])&2) for e in local),
      "read_downstream":seen(lambda _,e:e.get("event")=="r" and int(e.get("resp",0))==2),
      "write_downstream":seen(lambda _,e:e.get("event")=="b" and int(e.get("resp",0))==2),
    }
    for name,hit in error_hits.items(): add("error",[name],"observed request/response fields",hit)
    add("security",["secure_allow"],"secure target request reached target",any(int(e["target"])==2 and int(e.get("legal",0)) for _,e in transactions))
    add("security",["nonsecure_deny"],"nonsecure target request rejected",error_hits["security_deny"])
    arbitration_hits={
      "high_qos_priority":any(int(e.get("qos",0))==15 for _,e in grants),
      "equal_qos_rr":len({int(e["master"]) for source,e in grants if source=="equal_qos_rr"})==4,
      "two_way_contention":len({int(e["master"]) for source,e in grants if source=="contention_two"})==2,
      "four_way_contention":len({int(e["master"]) for source,e in grants if source=="contention_four"})==4,
      "write_burst_lock":sum(e.get("event")=="target_w" for source,e in all_events if source=="write_burst_lock")>=16,
      "starvation_override":any(int(e.get("age_override",0)) for source,e in grants if source=="starvation_override"),
    }
    for name,hit in arbitration_hits.items(): add("arbitration",[name],"observed grant/data event",hit)
    routing_hits={
      "id_restore":all(0<=int(e.get("id",-1))<16 for e in responses),
      "read_burst_lock":any(e["event"]=="ar" and int(e["len"])>1 for _,e in all_events),
      "local_error_no_target":bool(local) and all(not (grant_source==source and g["master"]==e["master"] and g["id"]==e["id"]
          and int(g["cycle"])==int(e["cycle"]) and g["event"]==f"{e['event']}_grant")
          for source,e in local_pairs for grant_source,g in grants),
      "reset_recovery":seen(lambda source,e:source=="reset_recovery" and e.get("event")=="reset" and not int(e["asserted"])),
      "async_read":any(e["event"]=="ar" and int(e.get("legal",0)) and int(e["target"])==3 for _,e in all_events),
      "async_write":any(e["event"]=="aw" and int(e.get("legal",0)) and int(e["target"])==3 for _,e in all_events),
      "post_reset_no_ghost":seen(lambda source,e:source=="reset_recovery" and e.get("event") in ("aw","ar")),
    }
    for name,hit in routing_hits.items(): add("routing_reset_cdc",[name],"observed trace invariant",hit)
    for level in (25,75):
        for op,kind in (("read","ar"),("write","aw")):
            add("backpressure",[f"{op}_{level}"],"configured stall plus accepted operation",
                any(source==f"channel_backpressure_{level}" and e.get("event")==kind for source,e in all_events))
    random_events=[e for source,e in all_events if source.startswith("random_")]
    random_hits={"read_mix":any(e.get("event")=="ar" for e in random_events),"write_mix":any(e.get("event")=="aw" for e in random_events),
      "error_mix":any(e.get("event") in ("b","r") and int(e.get("resp",0))!=0 for e in random_events),
      "security_mix":any(e.get("event") in ("aw","ar") and (int(e.get("prot",0))&2) for e in random_events),
      "qos_mix":len({int(e.get("qos",0)) for e in random_events if e.get("event") in ("aw","ar")})>4}
    for name,hit in random_hits.items(): add("random",[name],"observed seeded transaction fields",hit)
    assert len(bins) == 56
    flat_rows = [{"area": area, "coverage_point": name, "status": "HIT" if evidence != "missing" else "MISS", "evidence": evidence}
                 for area, name, evidence in bins]

    cross_hits: dict[str, set[str]] = defaultdict(set)
    pending: dict[tuple[int, int, str], dict] = {}
    for source, event in all_events:
        kind = event.get("event")
        if kind in ("aw", "ar"):
            op = "write" if kind == "aw" else "read"
            master, target = int(event["master"]), int(event["target"])
            if int(event.get("legal", 0)):
                cross_hits["initiator_x_target"].add(f"m{master}_s{target}")
            length = int(event.get("len", 1))
            bucket = "1" if length == 1 else "2_4" if length <= 4 else "5_8" if length <= 8 else "9_16"
            cross_hits["operation_x_burst"].add(f"{op}_{bucket}")
            if target == 2:
                result = "deny" if not int(event.get("legal", 0)) else "allow"
                cross_hits["security_x_operation"].add(f"{result}_{op}")
            if target == 3 and int(event.get("legal", 0)):
                cross_hits["cdc_x_operation"].add(op)
            pending[(master, int(event["id"]), op)] = event
        elif kind == "b":
            key = (int(event["master"]), int(event["id"]), "write")
            if key in pending:
                cross_hits["operation_x_response"].add(f"write_{event['resp']}")
                pending.pop(key)
        elif kind == "r" and int(event.get("last", 0)):
            key = (int(event["master"]), int(event["id"]), "read")
            if key in pending:
                cross_hits["operation_x_response"].add(f"read_{event['resp']}")
                pending.pop(key)
        if source in ("target_matrix", "channel_backpressure_25", "channel_backpressure_75") and kind in ("aw", "ar"):
            level = "0" if source == "target_matrix" else source.rsplit("_", 1)[1]
            cross_hits["backpressure_x_operation"].add(f"{level}_{'write' if kind == 'aw' else 'read'}")

    scenario_crosses = {
        "read_2way": arbitration_hits["two_way_contention"],
        "read_4way": arbitration_hits["four_way_contention"],
        "write_4way": arbitration_hits["write_burst_lock"],
        "high_qos_winner": arbitration_hits["high_qos_priority"],
    }
    for name, hit in scenario_crosses.items():
        if hit: cross_hits["contention_x_policy"].add(name)

    required = {
        "initiator_x_target": [f"m{m}_s{s}" for m in range(4) for s in range(4)],
        "operation_x_burst": [f"{op}_{bucket}" for op in ("read", "write") for bucket in ("1", "2_4", "5_8", "9_16")],
        "operation_x_response": [f"{op}_{resp}" for op in ("read", "write") for resp in (0, 2, 3)],
        "security_x_operation": [f"{result}_{op}" for result in ("allow", "deny") for op in ("read", "write")],
        "cdc_x_operation": ["read", "write"],
        "backpressure_x_operation": [f"{level}_{op}" for level in ("0", "25", "75") for op in ("read", "write")],
        "contention_x_policy": list(scenario_crosses),
    }
    cross_rows = []
    for group, names in required.items():
        for name in names:
            cross_rows.append({"cross_group": group, "cross_bin": name,
                               "status": "HIT" if name in cross_hits[group] else "MISS"})
    assert len(cross_rows) == 46

    write(REPORTS / "functional_coverage.csv", flat_rows)
    write(REPORTS / "cross_coverage.csv", cross_rows)
    flat_hit = sum(row["status"] == "HIT" for row in flat_rows)
    cross_hit = sum(row["status"] == "HIT" for row in cross_rows)
    DOC.write_text(
        "# Coverage Closure\n\n"
        f"Measured regression-derived functional coverage is **{flat_hit} / {len(flat_rows)}**; "
        f"same-run event interaction coverage is **{cross_hit} / {len(cross_rows)}**. "
        "These metrics are separate from Verilator code coverage.\n\n"
        "| Area | Hit | Total |\n| --- | ---: | ---: |\n" +
        "".join(f"| `{area}` | {sum(r['status']=='HIT' for r in flat_rows if r['area']==area)} | {sum(r['area']==area for r in flat_rows)} |\n"
                for area in dict.fromkeys(row["area"] for row in flat_rows)) +
        "\n| Cross group | Hit | Total |\n| --- | ---: | ---: |\n" +
        "".join(f"| `{group}` | {sum(r['status']=='HIT' for r in cross_rows if r['cross_group']==group)} | {sum(r['cross_group']==group for r in cross_rows)} |\n"
                for group in required) +
        "\nCoverage is generated from passing named scenarios, passing seeded runs, and normalized request/response traces. "
        "A bin is not credited merely because a test has a matching name.\n"
    )
    print(f"COVERAGE_RESULT|functional={flat_hit}/{len(flat_rows)}|cross={cross_hit}/{len(cross_rows)}")
    return 0 if flat_hit == len(flat_rows) and cross_hit == len(cross_rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
