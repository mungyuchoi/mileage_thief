from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, asdict
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[2]
DEFAULT_HTML = ROOT_DIR / "task" / "point" / "marriott.html"


@dataclass
class CalendarCell:
    date: str
    date_label: str
    disabled: bool
    selected: bool
    outside_month: bool
    price_text: str
    points: int | None
    button_label: str


class MarriottCalendarParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.cells: list[CalendarCell] = []
        self.current: dict[str, Any] | None = None
        self.div_depth = 0
        self.capture_price = False
        self.price_depth = 0
        self.price_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_map = {key: value or "" for key, value in attrs}
        if tag != "div":
            return

        class_name = attrs_map.get("class", "")
        is_gridcell = (
            attrs_map.get("role") == "gridcell"
            and "DayPicker-Day" in class_name
        )

        if is_gridcell:
            self._finish_current()
            self.current = {
                "date_label": attrs_map.get("aria-label", ""),
                "disabled": attrs_map.get("aria-disabled") == "true",
                "selected": attrs_map.get("aria-selected") == "true",
                "outside_month": "DayPicker-Day--outside" in class_name,
                "price_text": "",
                "button_label": "",
            }
            self.div_depth = 1
            return

        if self.current is None:
            return

        self.div_depth += 1

        if attrs_map.get("role") == "button":
            self.current["button_label"] = attrs_map.get("aria-label", "")

        if "price-section" in class_name:
            self.capture_price = True
            self.price_depth = self.div_depth
            self.price_parts = []

    def handle_data(self, data: str) -> None:
        if self.capture_price:
            stripped = data.strip()
            if stripped:
                self.price_parts.append(stripped)

    def handle_endtag(self, tag: str) -> None:
        if tag != "div" or self.current is None:
            return

        if self.capture_price and self.div_depth == self.price_depth:
            self.current["price_text"] = " ".join(self.price_parts)
            self.capture_price = False
            self.price_depth = 0
            self.price_parts = []

        if self.div_depth <= 1:
            self._finish_current()
            return

        self.div_depth -= 1

    def close(self) -> None:
        self._finish_current()
        super().close()

    def _finish_current(self) -> None:
        if self.current is None:
            return

        date_label = self.current["date_label"]
        iso_date = parse_date_label(date_label)
        if iso_date:
            price_text = self.current["price_text"]
            self.cells.append(
                CalendarCell(
                    date=iso_date,
                    date_label=date_label,
                    disabled=bool(self.current["disabled"]),
                    selected=bool(self.current["selected"]),
                    outside_month=bool(self.current["outside_month"]),
                    price_text=price_text,
                    points=parse_points(price_text),
                    button_label=self.current["button_label"],
                )
            )

        self.current = None
        self.div_depth = 0
        self.capture_price = False
        self.price_depth = 0
        self.price_parts = []


def parse_date_label(value: str) -> str:
    try:
        return datetime.strptime(value.strip(), "%a %b %d %Y").date().isoformat()
    except ValueError:
        return ""


def parse_points(value: str) -> int | None:
    if "available" in value.lower():
        return None
    match = re.search(r"\d[\d,]*", value)
    return int(match.group(0).replace(",", "")) if match else None


def parse_calendar_html(path: Path) -> list[CalendarCell]:
    parser = MarriottCalendarParser()
    parser.feed(path.read_text(encoding="utf-8", errors="ignore"))
    parser.close()
    return parser.cells


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parse Marriott availability calendar cells from copied HTML.",
    )
    parser.add_argument("--html", default=str(DEFAULT_HTML), help="Path to copied Marriott HTML.")
    parser.add_argument("--output", help="Optional JSON output path.")
    parser.add_argument(
        "--priced-only",
        action="store_true",
        help="Only include cells with a numeric points value.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    html_path = Path(args.html)
    cells = parse_calendar_html(html_path)
    if args.priced_only:
        cells = [cell for cell in cells if cell.points is not None]

    payload = [asdict(cell) for cell in cells]
    if args.output:
        Path(args.output).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    priced = sum(1 for cell in cells if cell.points is not None)
    unavailable = sum(1 for cell in cells if "available" in cell.price_text.lower())
    print(f"html={html_path}")
    print(f"cells={len(cells)} priced={priced} unavailable={unavailable}")
    if cells:
        print(f"first={cells[0].date} points={cells[0].points}")
        print(f"last={cells[-1].date} points={cells[-1].points}")
    if args.output:
        print(f"wrote={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
