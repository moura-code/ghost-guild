#!/usr/bin/env python3
"""Export comparable, entry-relative summaries from difficulty_report.gd JSON."""

import argparse
import csv
import json
from pathlib import Path


def summarize(path: Path):
    report = json.loads(path.read_text())
    for summary in report["summaries"]:
        row = {
            "revision": report["content_revision"],
            "seed_set": report["seed_set"],
            "seed_base": report["seed_base"],
            "seed_stride": report["seed_stride"],
            "engine_hash": report["engine_hash"],
        }
        for key in (
            "route", "profile", "policy", "n", "deaths", "first_fight_wins",
            "entry_floor", "checkpoint_floor",
        ):
            row[key] = summary[key]
        for prefix, metric in (
            ("checkpoint_loss", "checkpoint_exit_net_loss_survivors"),
            ("opening_normal_turns", "opening_normal_win_turns"),
            ("depth", "depth"),
        ):
            for statistic in ("n", "mean", "p10", "median", "p90"):
                row[f"{prefix}_{statistic}"] = summary[metric].get(statistic, "")
        for metric in (
            "gross_damage", "healing", "blocked", "enemy_actions", "coin_spent",
        ):
            row[f"{metric}_mean"] = summary[metric]["mean"]
        yield row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("reports", nargs="+", type=Path)
    args = parser.parse_args()
    rows = [row for path in args.reports for row in summarize(path)]
    if not rows:
        parser.error("Reports contain no summaries")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"{len(rows)} summaries -> {args.out}")


if __name__ == "__main__":
    main()
