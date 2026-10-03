"""Lector mínimo de .xlsx con la librería estándar (zip + XML).

No depende de openpyxl. Devuelve cada hoja como lista de filas, y cada fila
como lista de celdas alineadas por columna (`None` en los huecos).
"""

from __future__ import annotations

import re
import zipfile
from xml.etree import ElementTree as ET

_NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}
_T = "{%s}t" % _NS["m"]


def _column_index(ref: str) -> int:
    letters = re.match(r"[A-Z]+", ref).group(0)
    index = 0
    for ch in letters:
        index = index * 26 + (ord(ch) - 64)
    return index - 1


def _number(text: str):
    try:
        value = float(text)
    except ValueError:
        return text
    return int(value) if value.is_integer() and "." not in text and "E" not in text.upper() else value


class Workbook:
    def __init__(self, path):
        self._zip = zipfile.ZipFile(path)
        names = set(self._zip.namelist())
        self._strings = []
        if "xl/sharedStrings.xml" in names:
            root = ET.fromstring(self._zip.read("xl/sharedStrings.xml"))
            for si in root.findall("m:si", _NS):
                self._strings.append("".join(t.text or "" for t in si.iter(_T)))
        rels = {
            rel.get("Id"): rel.get("Target")
            for rel in ET.fromstring(self._zip.read("xl/_rels/workbook.xml.rels"))
        }
        self._sheets = {}
        workbook = ET.fromstring(self._zip.read("xl/workbook.xml"))
        for sheet in workbook.find("m:sheets", _NS):
            target = rels[sheet.get("{%s}id" % _NS["r"])].lstrip("/")
            if target not in names:
                target = "xl/" + target
            self._sheets[sheet.get("name")] = target

    @property
    def sheet_names(self):
        return list(self._sheets)

    def has(self, name: str) -> bool:
        return name in self._sheets

    def rows(self, name: str):
        root = ET.fromstring(self._zip.read(self._sheets[name]))
        out = []
        for row in root.find("m:sheetData", _NS).findall("m:row", _NS):
            cells = []
            for cell in row.findall("m:c", _NS):
                index = _column_index(cell.get("r"))
                while len(cells) <= index:
                    cells.append(None)
                kind = cell.get("t")
                value = cell.find("m:v", _NS)
                if kind == "s" and value is not None:
                    cells[index] = self._strings[int(value.text)]
                elif kind == "inlineStr":
                    cells[index] = "".join(t.text or "" for t in cell.iter(_T))
                elif kind == "b" and value is not None:
                    cells[index] = value.text == "1"
                elif value is not None and value.text is not None:
                    cells[index] = value.text if kind == "str" else _number(value.text)
            out.append(cells)
        return out

    def records(self, name: str):
        """Filas como diccionarios, usando la primera fila como cabecera."""
        rows = self.rows(name)
        if not rows:
            return []
        headers = [str(h).strip() if h is not None else "" for h in rows[0]]
        out = []
        for row in rows[1:]:
            record = {
                header: (row[i] if i < len(row) else None)
                for i, header in enumerate(headers)
                if header
            }
            if any(v not in (None, "") for v in record.values()):
                out.append(record)
        return out
