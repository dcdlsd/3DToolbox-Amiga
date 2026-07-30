#!/usr/bin/env python3
"""
SlicerServer - tiny HTTP bridge to PrusaSlicer.

This runs on the PC. The Amiga will later call it with simple HTTP requests.

Main test URL:
    http://PC_IP:18090/slice?input=G:/modele.stl&output=G:/Sortie.gcode&profile=standard

Then check:
    http://PC_IP:18090/job?id=1
"""

from __future__ import annotations

from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
import ipaddress
import re
import struct
import subprocess
import threading
import time
import traceback


SCRIPT_DIR = Path(__file__).resolve().parent
CFG_FILE = SCRIPT_DIR / "slicer_server.cfg"

DEFAULT_HOST = "0.0.0.0"
DEFAULT_PORT = 18090
DEFAULT_ALLOWED_CLIENTS = "127.0.0.1,::1"
DEFAULT_MAX_UPLOAD_MB = 64
DEFAULT_ALLOW_PC_PATHS = False
DEFAULT_PRUSA_EXE = Path(r"C:\Program Files\Prusa3D\PrusaSlicer\prusa-slicer-console.exe")
DEFAULT_PROFILE_STANDARD = Path(
    r"C:\Users\d.costils\AppData\Roaming\PrusaSlicer\Tina2s_denis_complete_standard.ini"
)
DEFAULT_BASE_DIR = SCRIPT_DIR / "SlicerBridge"

HOST = DEFAULT_HOST
PORT = DEFAULT_PORT
ALLOWED_CLIENTS_TEXT = DEFAULT_ALLOWED_CLIENTS
ALLOWED_CLIENTS: list[str] = []
MAX_UPLOAD_BYTES = DEFAULT_MAX_UPLOAD_MB * 1024 * 1024
ALLOW_PC_PATHS = DEFAULT_ALLOW_PC_PATHS
PRUSA_EXE = DEFAULT_PRUSA_EXE
PROFILES = {"standard": DEFAULT_PROFILE_STANDARD}
BASE_DIR = DEFAULT_BASE_DIR
IN_DIR = BASE_DIR / "in"
OUT_DIR = BASE_DIR / "out"
DONE_DIR = BASE_DIR / "done"
ERROR_DIR = BASE_DIR / "error"
WORK_DIR = BASE_DIR / "work"

JOBS: dict[int, "SliceJob"] = {}
JOBS_LOCK = threading.Lock()
NEXT_JOB_ID = 1
ACTIVITY_LOCK = threading.Lock()
CURRENT_ACTIVITY = "IDLE"


@dataclass
class SliceJob:
    id: int
    profile: str
    input_path: Path
    output_path: Path
    scale: float = 100.0
    status: str = "WAITING"
    message: str = ""
    return_code: int | None = None
    log: str = ""
    color_hint: str = ""
    error_path: Path | None = None
    created_at: float = field(default_factory=time.time)
    started_at: float | None = None
    finished_at: float | None = None


@dataclass
class StlInfo:
    min_x: float
    max_x: float
    min_y: float
    max_y: float
    min_z: float
    max_z: float

    @property
    def width(self) -> float:
        return self.max_x - self.min_x

    @property
    def depth(self) -> float:
        return self.max_y - self.min_y

    @property
    def height(self) -> float:
        return self.max_z - self.min_z


@dataclass
class ColorHint:
    color_z: float
    top_z: float
    layer_zero: int | None = None
    layer_one: int | None = None
    layer_z: float | None = None
    insert_layer_one: int | None = None
    insert_layer_z: float | None = None


def text_response(handler: BaseHTTPRequestHandler, status: int, text: str) -> None:
    body = text.encode("ascii", errors="replace")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/plain; charset=ascii")
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def binary_response(
    handler: BaseHTTPRequestHandler,
    status: int,
    data: bytes,
    filename: str = "download.bin",
) -> None:
    safe_name = sanitize_filename(filename, ".bin")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/octet-stream")
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Disposition", f'attachment; filename="{safe_name}"')
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def refresh_bridge_paths() -> None:
    global IN_DIR, OUT_DIR, DONE_DIR, ERROR_DIR, WORK_DIR

    IN_DIR = BASE_DIR / "in"
    OUT_DIR = BASE_DIR / "out"
    DONE_DIR = BASE_DIR / "done"
    ERROR_DIR = BASE_DIR / "error"
    WORK_DIR = BASE_DIR / "work"


def write_default_config() -> None:
    if CFG_FILE.exists():
        return

    text = (
        "# SlicerServer configuration\n"
        "# Edit this file when moving the bridge to another PC.\n"
        "# For distribution, keep ALLOWED_CLIENTS limited to your Amiga IP.\n"
        "\n"
        f"HOST={DEFAULT_HOST}\n"
        f"PORT={DEFAULT_PORT}\n"
        f"ALLOWED_CLIENTS={DEFAULT_ALLOWED_CLIENTS}\n"
        f"MAX_UPLOAD_MB={DEFAULT_MAX_UPLOAD_MB}\n"
        f"ALLOW_PC_PATHS={'yes' if DEFAULT_ALLOW_PC_PATHS else 'no'}\n"
        f"PRUSA_EXE={DEFAULT_PRUSA_EXE}\n"
        f"BASE_DIR={DEFAULT_BASE_DIR}\n"
        f"PROFILE_STANDARD={DEFAULT_PROFILE_STANDARD}\n"
    )
    CFG_FILE.write_text(text, encoding="utf-8")


def load_config() -> None:
    global HOST, PORT, ALLOWED_CLIENTS_TEXT, ALLOWED_CLIENTS
    global MAX_UPLOAD_BYTES, ALLOW_PC_PATHS
    global PRUSA_EXE, BASE_DIR, PROFILES

    write_default_config()

    values: dict[str, str] = {}
    try:
        for raw_line in CFG_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip().upper()] = value.strip().strip('"')
    except OSError:
        values = {}

    HOST = values.get("HOST", DEFAULT_HOST)

    try:
        PORT = int(values.get("PORT", str(DEFAULT_PORT)))
    except ValueError:
        PORT = DEFAULT_PORT

    ALLOWED_CLIENTS_TEXT = values.get("ALLOWED_CLIENTS", DEFAULT_ALLOWED_CLIENTS)
    ALLOWED_CLIENTS = [item.strip() for item in ALLOWED_CLIENTS_TEXT.split(",") if item.strip()]

    try:
        max_upload_mb = float(values.get("MAX_UPLOAD_MB", str(DEFAULT_MAX_UPLOAD_MB)))
    except ValueError:
        max_upload_mb = DEFAULT_MAX_UPLOAD_MB
    max_upload_mb = max(1.0, min(max_upload_mb, 1024.0))
    MAX_UPLOAD_BYTES = int(max_upload_mb * 1024 * 1024)

    ALLOW_PC_PATHS = values.get(
        "ALLOW_PC_PATHS",
        "yes" if DEFAULT_ALLOW_PC_PATHS else "no",
    ).strip().lower() in ("1", "yes", "true", "on")

    PRUSA_EXE = Path(values.get("PRUSA_EXE", str(DEFAULT_PRUSA_EXE)))
    BASE_DIR = Path(values.get("BASE_DIR", str(DEFAULT_BASE_DIR)))

    profiles = {"standard": Path(values.get("PROFILE_STANDARD", str(DEFAULT_PROFILE_STANDARD)))}
    for key, value in values.items():
        if key.startswith("PROFILE_") and key != "PROFILE_STANDARD":
            name = key[8:].lower()
            if name:
                profiles[name] = Path(value)
    PROFILES = profiles
    refresh_bridge_paths()


def client_allowed(address: str) -> bool:
    if not ALLOWED_CLIENTS:
        return False
    if "*" in ALLOWED_CLIENTS:
        return True

    try:
        client_ip = ipaddress.ip_address(address)
    except ValueError:
        return False

    for rule in ALLOWED_CLIENTS:
        try:
            if "/" in rule:
                if client_ip in ipaddress.ip_network(rule, strict=False):
                    return True
            elif client_ip == ipaddress.ip_address(rule):
                return True
        except ValueError:
            continue

    return False


def path_inside_base(path: Path) -> bool:
    try:
        resolved = path.resolve()
        base = BASE_DIR.resolve()
        return resolved == base or base in resolved.parents
    except OSError:
        return False


def ensure_bridge_dirs() -> None:
    for folder in (BASE_DIR, IN_DIR, OUT_DIR, DONE_DIR, ERROR_DIR, WORK_DIR):
        folder.mkdir(parents=True, exist_ok=True)


def set_activity(text: str) -> None:
    global CURRENT_ACTIVITY
    with ACTIVITY_LOCK:
        CURRENT_ACTIVITY = text
    print(text, flush=True)


def clear_activity() -> None:
    global CURRENT_ACTIVITY
    with ACTIVITY_LOCK:
        CURRENT_ACTIVITY = "IDLE"


def get_activity() -> str:
    with ACTIVITY_LOCK:
        return CURRENT_ACTIVITY


def server_status_text() -> str:
    lines = [
        "STATUS: OK",
        "NAME: SlicerServer",
        f"ACTIVITY: {get_activity()}",
        f"ALLOWED_CLIENTS: {ALLOWED_CLIENTS_TEXT}",
        f"ALLOW_PC_PATHS: {'yes' if ALLOW_PC_PATHS else 'no'}",
        f"MAX_UPLOAD_BYTES: {MAX_UPLOAD_BYTES}",
    ]

    with JOBS_LOCK:
        if JOBS:
            job = JOBS[max(JOBS)]
        else:
            job = None

    if job is not None:
        lines.extend(
            [
                f"LAST_JOB_ID: {job.id}",
                f"LAST_JOB_STATUS: {job.status}",
                f"LAST_JOB_MESSAGE: {job.message}",
            ]
        )

    return "\n".join(lines) + "\n"


def short_file_line(path: Path) -> str:
    try:
        size = path.stat().st_size
    except OSError:
        size = 0
    return f"  {path.name}  ({size} bytes)"


def list_bridge_files() -> str:
    ensure_bridge_dirs()
    sections = [
        ("STL waiting", IN_DIR, "*.stl"),
        ("STL done", DONE_DIR, "*.stl"),
        ("G-code", OUT_DIR, "*.gcode"),
        ("Errors", ERROR_DIR, "*"),
    ]
    lines = ["STATUS: OK", f"BASE_DIR: {BASE_DIR}"]

    print("", flush=True)
    print("FILES REQUEST", flush=True)
    print(f"  BASE_DIR      : {BASE_DIR}", flush=True)

    for title, folder, pattern in sections:
        lines.append("")
        lines.append(f"{title}:")
        files = sorted(folder.glob(pattern), key=lambda item: item.name.lower())
        print(f"  {title:<13}: {folder}", flush=True)
        if files:
            lines.extend(short_file_line(path) for path in files)
            for path in files:
                print(f"                  {path}", flush=True)
        else:
            lines.append("  (empty)")
            print("                  (empty)", flush=True)

    return "\n".join(lines) + "\n"


def add_candidate(candidates: list[Path], path: Path) -> None:
    if path not in candidates:
        candidates.append(path)


def delete_bridge_file(name: str, kind: str = "all") -> str:
    ensure_bridge_dirs()
    kind = clean_param(kind).lower()
    stl_name = sanitize_filename(name, ".stl")
    base = Path(stl_name).stem
    gcode_name = sanitize_filename(f"{base}.gcode", ".gcode")

    print("", flush=True)
    print("DELETE REQUEST", flush=True)
    print(f"  name received : {name}", flush=True)
    print(f"  sanitized STL : {stl_name}", flush=True)
    print(f"  kind          : {kind}", flush=True)
    print("  known STL     :", flush=True)
    known_stl = sorted(BASE_DIR.rglob("*.stl"), key=lambda item: str(item).lower())
    if known_stl:
        for path in known_stl:
            print(f"                  {path}", flush=True)
    else:
        print("                  (none)", flush=True)

    candidates: list[Path] = []
    if kind in ("all", "stl"):
        add_candidate(candidates, IN_DIR / stl_name)
        add_candidate(candidates, DONE_DIR / stl_name)
        for path in BASE_DIR.rglob(stl_name):
            add_candidate(candidates, path)
    if kind in ("all", "gcode"):
        add_candidate(candidates, OUT_DIR / gcode_name)
        for path in BASE_DIR.rglob(gcode_name):
            add_candidate(candidates, path)
    if kind in ("all", "error"):
        for path in ERROR_DIR.glob(f"{base}*"):
            add_candidate(candidates, path)
        for path in BASE_DIR.rglob(f"{base}*error*"):
            add_candidate(candidates, path)

    if kind not in ("all", "stl", "gcode", "error"):
        raise ValueError("Bad type. Use all, stl, gcode or error")

    deleted: list[str] = []
    missing: list[str] = []
    seen: set[Path] = set()

    for path in candidates:
        try:
            resolved = path.resolve()
        except OSError:
            resolved = path
        if resolved in seen:
            continue
        seen.add(resolved)

        print(f"  check         : {path}", flush=True)
        if not path_inside_base(path):
            print("                  -> skipped outside BASE_DIR", flush=True)
            continue
        if not path.exists():
            print("                  -> not found", flush=True)
            missing.append(str(path))
            continue
        if path.is_dir():
            print("                  -> skipped directory", flush=True)
            continue
        path.unlink()
        print("                  -> deleted", flush=True)
        deleted.append(str(path))

    print(f"  result        : {len(deleted)} deleted, {len(missing)} not found", flush=True)

    lines = ["STATUS: OK", f"REQUEST: delete {kind} {name}"]
    if deleted:
        lines.append("DELETED:")
        lines.extend(f"  {Path(item).name}" for item in deleted)
    else:
        lines.append("DELETED: none")
    if missing:
        lines.append("NOT_FOUND:")
        lines.extend(f"  {Path(item).parent.name}/{Path(item).name}" for item in missing)
    return "\n".join(lines) + "\n"


def next_job_id() -> int:
    global NEXT_JOB_ID
    with JOBS_LOCK:
        job_id = NEXT_JOB_ID
        NEXT_JOB_ID += 1
    return job_id


def make_output_path(input_path: Path) -> Path:
    base = input_path.with_suffix(".gcode")
    if not base.exists():
        return base

    for index in range(2, 1000):
        candidate = input_path.with_name(f"{input_path.stem}_{index}.gcode")
        if not candidate.exists():
            return candidate

    raise RuntimeError("No free output filename found")


def clean_param(value: str) -> str:
    return unquote(value).strip().strip('"')


def sanitize_filename(name: str, default_suffix: str = "") -> str:
    name = clean_param(name).replace("\\", "/").split("/")[-1].strip()
    name = re.sub(r"[^A-Za-z0-9._ -]", "_", name)
    name = name.strip(" .")
    if not name:
        name = "upload"
    if default_suffix and not Path(name).suffix:
        name += default_suffix
    return name


def uploaded_stl_path(name: str) -> Path:
    filename = sanitize_filename(name, ".stl")
    path = IN_DIR / filename
    if path.suffix.lower() != ".stl":
        raise ValueError("Uploaded file must be .stl")
    return path


def uploaded_gcode_path_for(stl_path: Path) -> Path:
    return OUT_DIR / f"{stl_path.stem}.gcode"


def parse_scale(value: str | None) -> float:
    if value is None:
        return 100.0

    cleaned = clean_param(value).replace("%", "").replace(",", ".")
    if not cleaned:
        return 100.0

    scale = float(cleaned)
    if scale <= 0.0 or scale > 1000.0:
        raise ValueError("Scale must be between 0.1 and 1000")
    return scale


def format_stl_info(
    stl: StlInfo,
    bed_x: float,
    bed_y: float,
    scale: float = 100.0,
    print_margin: float = 0.5,
) -> str:
    factor = scale / 100.0
    scaled_x = stl.width * factor
    scaled_y = stl.depth * factor
    scaled_z = stl.height * factor
    safe_bed_x = max(1.0, bed_x - (print_margin * 2.0))
    safe_bed_y = max(1.0, bed_y - (print_margin * 2.0))
    usable_scale = min(safe_bed_x / stl.width, safe_bed_y / stl.depth) if stl.width and stl.depth else 1.0
    raw_suggested_scale = min(100.0, max(1.0, usable_scale * 100.0))
    suggested_scale = int(raw_suggested_scale * 10.0) / 10.0
    if raw_suggested_scale < 100.0 and suggested_scale > 1.0:
        suggested_scale = max(1.0, suggested_scale - 0.1)
    return (
        f"STL_SIZE: {stl.width:.1f} x {stl.depth:.1f} x {stl.height:.1f} mm\n"
        f"STL_X: {stl.width:.1f}\n"
        f"STL_Y: {stl.depth:.1f}\n"
        f"STL_Z: {stl.height:.1f}\n"
        f"APPLIED_SCALE: {scale:.1f}%\n"
        f"SCALED_SIZE: {scaled_x:.1f} x {scaled_y:.1f} x {scaled_z:.1f} mm\n"
        f"BED_SIZE: {bed_x:.1f} x {bed_y:.1f} mm\n"
        f"PRINT_MARGIN: {print_margin:.1f} mm\n"
        f"SAFE_BED_SIZE: {safe_bed_x:.1f} x {safe_bed_y:.1f} mm\n"
        f"SUGGESTED_SCALE: {suggested_scale:.1f}%\n"
    )


def update_bounds(bounds: list[float] | None, x: float, y: float, z: float) -> list[float]:
    if bounds is None:
        return [x, x, y, y, z, z]

    bounds[0] = min(bounds[0], x)
    bounds[1] = max(bounds[1], x)
    bounds[2] = min(bounds[2], y)
    bounds[3] = max(bounds[3], y)
    bounds[4] = min(bounds[4], z)
    bounds[5] = max(bounds[5], z)
    return bounds


def read_stl_info(path: Path) -> StlInfo:
    size = path.stat().st_size
    if size < 15:
        raise ValueError("STL file is empty or too small")

    with path.open("rb") as f:
        header = f.read(84)

    bounds: list[float] | None = None

    if len(header) == 84:
        triangle_count = struct.unpack("<I", header[80:84])[0]
        expected_size = 84 + triangle_count * 50
        if expected_size == size:
            with path.open("rb") as f:
                f.seek(84)
                for _ in range(triangle_count):
                    record = f.read(50)
                    if len(record) != 50:
                        break
                    values = struct.unpack("<12fH", record)
                    bounds = update_bounds(bounds, values[3], values[4], values[5])
                    bounds = update_bounds(bounds, values[6], values[7], values[8])
                    bounds = update_bounds(bounds, values[9], values[10], values[11])

            if bounds is None:
                raise ValueError("Binary STL contains no triangle")
            return StlInfo(*bounds)

    vertex_re = re.compile(
        r"^\s*vertex\s+([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)\s+"
        r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)\s+"
        r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)"
    )
    with path.open("r", encoding="ascii", errors="ignore") as f:
        for line in f:
            match = vertex_re.match(line)
            if match:
                bounds = update_bounds(
                    bounds,
                    float(match.group(1)),
                    float(match.group(2)),
                    float(match.group(3)),
                )

    if bounds is None:
        raise ValueError("ASCII STL contains no vertex")
    return StlInfo(*bounds)


def is_binary_stl(path: Path) -> tuple[bool, int]:
    size = path.stat().st_size
    if size < 84:
        return False, 0

    with path.open("rb") as f:
        header = f.read(84)

    triangle_count = struct.unpack("<I", header[80:84])[0]
    expected_size = 84 + triangle_count * 50
    return expected_size == size, triangle_count


def read_stl_triangles(path: Path) -> list[tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]]:
    binary, triangle_count = is_binary_stl(path)
    triangles = []

    if binary:
        with path.open("rb") as f:
            f.seek(84)
            for _ in range(triangle_count):
                record = f.read(50)
                if len(record) != 50:
                    break
                values = struct.unpack("<12fH", record)
                triangles.append((
                    (values[3], values[4], values[5]),
                    (values[6], values[7], values[8]),
                    (values[9], values[10], values[11]),
                ))
        return triangles

    vertex_re = re.compile(
        r"^\s*vertex\s+([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)\s+"
        r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)\s+"
        r"([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)"
    )
    vertices = []
    with path.open("r", encoding="ascii", errors="ignore") as f:
        for line in f:
            match = vertex_re.match(line)
            if not match:
                continue
            vertices.append((
                float(match.group(1)),
                float(match.group(2)),
                float(match.group(3)),
            ))
            if len(vertices) == 3:
                triangles.append((vertices[0], vertices[1], vertices[2]))
                vertices = []

    return triangles


def write_ascii_stl(
    path: Path,
    triangles: list[tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]],
    name: str,
) -> None:
    with path.open("w", encoding="ascii", newline="\n") as f:
        f.write(f"solid {name}\n")
        for triangle in triangles:
            f.write("  facet normal 0 0 0\n")
            f.write("    outer loop\n")
            for x, y, z in triangle:
                f.write(f"      vertex {x:.6f} {y:.6f} {z:.6f}\n")
            f.write("    endloop\n")
            f.write("  endfacet\n")
        f.write(f"endsolid {name}\n")


def triangle_xy_area(
    triangle: tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]],
) -> float:
    (x1, y1, _), (x2, y2, _), (x3, y3, _) = triangle
    return abs((x1 * (y2 - y3)) + (x2 * (y3 - y1)) + (x3 * (y1 - y2))) / 2.0


def infer_color_z_from_stl(input_path: Path, scale: float) -> ColorHint | None:
    stl = read_stl_info(input_path)
    triangles = read_stl_triangles(input_path)
    if not triangles:
        return None

    factor = scale / 100.0
    top_z = stl.height * factor
    if top_z <= 0.0:
        return None

    horizontal_areas: dict[float, float] = {}
    levels: set[float] = set()

    for triangle in triangles:
        scaled_z = [round((vertex[2] - stl.min_z) * factor, 3) for vertex in triangle]
        for z in scaled_z:
            levels.add(z)

        if max(scaled_z) - min(scaled_z) > 0.002:
            continue

        z = round(sum(scaled_z) / 3.0, 3)
        if z <= 0.01 or z >= top_z - 0.01:
            continue

        horizontal_areas[z] = horizontal_areas.get(z, 0.0) + triangle_xy_area(triangle) * factor * factor

    if horizontal_areas:
        color_z = max(horizontal_areas.items(), key=lambda item: item[1])[0]
        return ColorHint(color_z=color_z, top_z=top_z)

    sorted_levels = sorted(levels)
    if len(sorted_levels) >= 3:
        return ColorHint(color_z=sorted_levels[-2], top_z=top_z)

    return None


def read_gcode_layers(gcode_path: Path) -> list[tuple[int, float]]:
    layer = -1
    wait_for_z = False
    layers: list[tuple[int, float]] = []

    try:
        with gcode_path.open("r", encoding="ascii", errors="ignore") as f:
            for raw_line in f:
                line = raw_line.strip()

                if line.startswith(";LAYER_CHANGE"):
                    layer += 1
                    wait_for_z = True
                    continue

                if wait_for_z and line.startswith(";Z:"):
                    try:
                        z = float(line[3:].replace(",", "."))
                    except ValueError:
                        wait_for_z = False
                        continue

                    wait_for_z = False
                    layers.append((layer, z))
    except OSError:
        return []

    return layers


def find_gcode_layer_for_z(gcode_path: Path, color_z: float, top_z: float) -> tuple[int, float, int, float] | None:
    layers = read_gcode_layers(gcode_path)
    for index, (layer, z) in enumerate(layers):
        if z + 0.001 >= color_z:
            insert_layer = layer
            insert_z = z

            # PrusaSlicer can still close the top skin of the base on the
            # first layer at COLOR_Z. For raised text, pausing one layer later
            # avoids printing that last base pass in the text color.
            if index + 1 < len(layers):
                next_layer, next_z = layers[index + 1]
                if next_z <= top_z + 0.001:
                    insert_layer = next_layer
                    insert_z = next_z

            return layer, z, insert_layer, insert_z

    return None


def format_color_hint(input_path: Path, scale: float, gcode_path: Path | None = None) -> str:
    try:
        hint = infer_color_z_from_stl(input_path, scale)
    except Exception as exc:
        return f"COLOR_HINT: ERROR {exc}\n"

    if hint is None:
        return "COLOR_HINT: NONE\n"

    if gcode_path is not None and gcode_path.exists():
        layer = find_gcode_layer_for_z(gcode_path, hint.color_z, hint.top_z)
        if layer is not None:
            hint.layer_zero = layer[0]
            hint.layer_one = layer[0] + 1
            hint.layer_z = layer[1]
            hint.insert_layer_one = layer[2] + 1
            hint.insert_layer_z = layer[3]

    lines = [
        "COLOR_HINT: RAISED_TEXT",
        f"COLOR_Z: {hint.color_z:.3f} mm",
        f"COLOR_TOP_Z: {hint.top_z:.3f} mm",
    ]

    if hint.layer_zero is not None and hint.layer_z is not None:
        lines.append(f"COLOR_LAYER_0: {hint.layer_zero}")
        lines.append(f"COLOR_LAYER_1: {hint.layer_one}")
        lines.append(f"COLOR_LAYER_Z: {hint.layer_z:.3f} mm")
        lines.append(f"INSERT_COLOR_LAYER: {hint.insert_layer_one}")
        lines.append(f"INSERT_COLOR_Z: {hint.insert_layer_z:.3f} mm")
        lines.append(f"COLOR_ACTION: change color at layer {hint.insert_layer_one}")
    else:
        lines.append("COLOR_ACTION: change color at first printed layer >= COLOR_Z")

    return "\n".join(lines) + "\n"


def transformed_stl_for_bed(profile_path: Path, input_path: Path, scale: float, job_id: int) -> Path:
    stl = read_stl_info(input_path)
    triangles = read_stl_triangles(input_path)
    if not triangles:
        raise ValueError("STL contains no triangle")

    bed_center_x, bed_center_y = profile_bed_center(profile_path)
    model_center_x = (stl.min_x + stl.max_x) / 2.0
    model_center_y = (stl.min_y + stl.max_y) / 2.0
    factor = scale / 100.0

    transformed = []
    for triangle in triangles:
        transformed_triangle = []
        for x, y, z in triangle:
            transformed_triangle.append((
                ((x - model_center_x) * factor) + bed_center_x,
                ((y - model_center_y) * factor) + bed_center_y,
                (z - stl.min_z) * factor,
            ))
        transformed.append((transformed_triangle[0], transformed_triangle[1], transformed_triangle[2]))

    output_path = WORK_DIR / f"{input_path.stem}_job{job_id}_centered.stl"
    write_ascii_stl(output_path, transformed, input_path.stem)
    return output_path


def profile_bed_bounds(profile_path: Path) -> tuple[float, float, float, float]:
    bed_shape_re = re.compile(r"^\s*bed_shape\s*=\s*(.+?)\s*$")
    try:
        with profile_path.open("r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                match = bed_shape_re.match(line)
                if not match:
                    continue

                xs: list[float] = []
                ys: list[float] = []
                for point in match.group(1).split(","):
                    if "x" not in point:
                        continue
                    x_text, y_text = point.strip().split("x", 1)
                    xs.append(float(x_text))
                    ys.append(float(y_text))

                if xs and ys:
                    return min(xs), max(xs), min(ys), max(ys)
    except Exception:
        pass

    return 0.0, 100.0, 0.0, 110.0


def profile_bed_size(profile_path: Path) -> tuple[float, float]:
    min_x, max_x, min_y, max_y = profile_bed_bounds(profile_path)
    return max_x - min_x, max_y - min_y


def profile_value(profile_path: Path, key: str) -> str | None:
    pattern = re.compile(rf"^\s*{re.escape(key)}\s*=\s*(.*?)\s*$")
    try:
        with profile_path.open("r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                match = pattern.match(line)
                if match:
                    return match.group(1).strip()
    except Exception:
        pass
    return None


def profile_float(profile_path: Path, key: str, default: float = 0.0) -> float:
    value = profile_value(profile_path, key)
    if value is None:
        return default
    try:
        return float(value.replace(",", "."))
    except ValueError:
        return default


def profile_int(profile_path: Path, key: str, default: int = 0) -> int:
    value = profile_value(profile_path, key)
    if value is None:
        return default
    try:
        return int(float(value.replace(",", ".")))
    except ValueError:
        return default


def profile_print_margin(profile_path: Path) -> float:
    margin = 0.5

    if profile_int(profile_path, "skirts", 0) > 0:
        margin = max(margin, profile_float(profile_path, "skirt_distance", 0.0) + 0.6)

    brim_width = profile_float(profile_path, "brim_width", 0.0)
    if brim_width > 0.0:
        margin = max(margin, brim_width + 0.6)

    return margin


def profile_bed_center(profile_path: Path) -> tuple[float, float]:
    min_x, max_x, min_y, max_y = profile_bed_bounds(profile_path)
    return (min_x + max_x) / 2.0, (min_y + max_y) / 2.0


def format_xy_short(x: float, y: float) -> str:
    return f"{x:.1f},{y:.1f}"


def validate_stl_size(profile_path: Path, input_path: Path, scale: float = 100.0) -> str | None:
    try:
        stl = read_stl_info(input_path)
    except Exception as exc:
        return f"Cannot read STL size: {exc}"

    bed_x, bed_y = profile_bed_size(profile_path)
    print_margin = profile_print_margin(profile_path)
    safe_bed_x = max(1.0, bed_x - (print_margin * 2.0))
    safe_bed_y = max(1.0, bed_y - (print_margin * 2.0))
    factor = scale / 100.0
    scaled_width = stl.width * factor
    scaled_depth = stl.depth * factor

    if scaled_width <= safe_bed_x and scaled_depth <= safe_bed_y:
        return None

    if scaled_width <= safe_bed_y and scaled_depth <= safe_bed_x:
        return (
            "STL_TOO_LARGE\n"
            "MESSAGE: Model too large for current orientation.\n"
            + format_stl_info(stl, bed_x, bed_y, scale, print_margin)
            + "ACTION: Try rotating it.\n"
        )

    return (
        "STL_TOO_LARGE\n"
        "MESSAGE: Model too large for Tina2S bed.\n"
        + format_stl_info(stl, bed_x, bed_y, scale, print_margin)
        + "ACTION: Resize it before upload.\n"
    )


def validate_job(profile: str, input_path: Path, output_path: Path, scale: float = 100.0) -> str | None:
    if not PRUSA_EXE.exists():
        return f"PrusaSlicer not found: {PRUSA_EXE}"

    profile_path = PROFILES.get(profile)
    if profile_path is None:
        return f"Unknown profile: {profile}"

    if not profile_path.exists():
        return f"Profile not found: {profile_path}"

    if not input_path.exists():
        return f"Input STL not found: {input_path}"

    if input_path.suffix.lower() != ".stl":
        return "Input file must be .stl"

    stl_error = validate_stl_size(profile_path, input_path, scale)
    if stl_error:
        return stl_error

    parent = output_path.parent
    if parent and not parent.exists():
        return f"Output folder not found: {parent}"

    return None


def start_slice_job(profile: str, input_path: Path, output_path: Path, scale: float = 100.0) -> SliceJob:
    job = SliceJob(
        id=next_job_id(),
        profile=profile,
        input_path=input_path,
        output_path=output_path,
        scale=scale,
    )

    with JOBS_LOCK:
        JOBS[job.id] = job

    thread = threading.Thread(target=run_slice_job, args=(job,), daemon=True)
    thread.start()
    return job


def run_slice_job(job: SliceJob) -> None:
    job.started_at = time.time()
    job.status = "RUNNING"
    transformed_path: Path | None = None
    set_activity(f"Job {job.id} running: {job.input_path.name}")

    try:
        profile_path = PROFILES[job.profile]
        set_activity(f"Job {job.id}: centering STL")
        transformed_path = transformed_stl_for_bed(profile_path, job.input_path, job.scale, job.id)
        command = [
            str(PRUSA_EXE),
            "--export-gcode",
            "--load",
            str(profile_path),
            "--output",
            str(job.output_path),
            str(transformed_path),
        ]

        set_activity(f"Job {job.id}: PrusaSlicer")
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            shell=False,
        )

        job.return_code = result.returncode
        job.log = result.stdout[-6000:] if result.stdout else ""

        if result.returncode == 0 and job.output_path.exists():
            size = job.output_path.stat().st_size
            job.status = "OK"
            job.message = f"G-code created: {job.output_path} ({size} bytes)"
            set_activity(f"Job {job.id}: color layer info")
            job.color_hint = format_color_hint(job.input_path, job.scale, job.output_path)
            if job.input_path.parent == IN_DIR:
                done_path = DONE_DIR / job.input_path.name
                try:
                    if done_path.exists():
                        done_path.unlink()
                    job.input_path.replace(done_path)
                    job.input_path = done_path
                except Exception:
                    pass
        else:
            job.status = "ERROR"
            job.message = f"PrusaSlicer failed with code {result.returncode}"
            if job.input_path.parent == IN_DIR:
                err_path = ERROR_DIR / f"{job.input_path.stem}_error.txt"
                err_path.write_text(job.log or job.message, encoding="utf-8", errors="replace")
                job.error_path = err_path

    except Exception as exc:
        job.status = "ERROR"
        job.message = str(exc)
        job.log = traceback.format_exc()[-6000:]
        if job.input_path.parent == IN_DIR:
            err_path = ERROR_DIR / f"{job.input_path.stem}_error.txt"
            err_path.write_text(job.log, encoding="utf-8", errors="replace")
            job.error_path = err_path
    finally:
        if transformed_path is not None:
            try:
                transformed_path.unlink()
            except OSError:
                pass
        job.finished_at = time.time()
        clear_activity()


def format_job(job: SliceJob, include_log: bool = False) -> str:
    now = time.time()
    end = job.finished_at or now
    start = job.started_at or job.created_at
    elapsed = max(0.0, end - start)

    lines = [
        f"STATUS: {job.status}",
        f"ID: {job.id}",
        f"PROFILE: {job.profile}",
        f"SCALE: {job.scale:.1f}%",
        f"CENTER: {format_xy_short(*profile_bed_center(PROFILES[job.profile]))}",
        f"INPUT: {job.input_path}",
        f"OUTPUT: {job.output_path}",
        f"ELAPSED: {elapsed:.1f}",
        f"RETURN: {job.return_code if job.return_code is not None else ''}",
        f"MESSAGE: {job.message}",
    ]

    if job.status == "OK" and job.output_path.exists():
        lines.append(f"DOWNLOAD: /download?id={job.id}")
    if job.color_hint:
        lines.extend(job.color_hint.rstrip().splitlines())
    if job.status == "ERROR" and job.error_path is not None:
        lines.append(f"ERROR_FILE: {job.error_path}")

    if include_log and job.log:
        lines.append("LOG_BEGIN")
        lines.append(job.log.rstrip())
        lines.append("LOG_END")

    return "\n".join(lines) + "\n"


class SlicerHandler(BaseHTTPRequestHandler):
    def check_client_allowed(self) -> bool:
        address = self.client_address[0]
        if client_allowed(address):
            return True
        print(f"Rejected client: {address}", flush=True)
        text_response(self, 403, "ERROR: Client IP not allowed by ALLOWED_CLIENTS\n")
        return False

    def do_POST(self) -> None:
        if not self.check_client_allowed():
            return

        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path == "/upload":
            self.handle_upload(params, start_slice=False)
            return

        if path == "/upload-and-slice":
            self.handle_upload(params, start_slice=True)
            return

        text_response(self, 404, "ERROR: Not found\n")

    def do_GET(self) -> None:
        if not self.check_client_allowed():
            return

        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        if path in ("/", "/help"):
            text_response(self, 200, self.help_text())
            return

        if path == "/status":
            text_response(self, 200, server_status_text())
            return

        if path == "/profiles":
            lines = ["PROFILES:"]
            for name, profile_path in PROFILES.items():
                exists = "OK" if profile_path.exists() else "MISSING"
                lines.append(f"{name}: {exists}: {profile_path}")
            text_response(self, 200, "\n".join(lines) + "\n")
            return

        if path == "/slice":
            self.handle_slice(params)
            return

        if path == "/slice-uploaded":
            self.handle_slice_uploaded(params)
            return

        if path == "/stl-info":
            self.handle_stl_info(params)
            return

        if path == "/job":
            self.handle_job(params)
            return

        if path == "/last":
            self.handle_last(params)
            return

        if path == "/download":
            self.handle_download(params)
            return

        if path == "/files":
            text_response(self, 200, list_bridge_files())
            return

        if path == "/delete":
            self.handle_delete(params)
            return

        text_response(self, 404, "ERROR: Not found\n")

    def read_post_body(self) -> bytes | None:
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            text_response(self, 411, "ERROR: Bad Content-Length\n")
            return None

        if size <= 0:
            text_response(self, 400, "ERROR: Empty upload\n")
            return None

        if size > MAX_UPLOAD_BYTES:
            text_response(
                self,
                413,
                f"ERROR: Upload too large: {size} bytes, limit {MAX_UPLOAD_BYTES} bytes\n",
            )
            return None

        try:
            set_activity(f"Receiving upload: {size} bytes")
            body = self.rfile.read(size)
        except (ConnectionResetError, OSError) as exc:
            print(f"Upload interrupted by client: {exc}")
            clear_activity()
            return None

        if len(body) != size:
            print(f"Upload incomplete: received {len(body)} bytes, expected {size} bytes")
            try:
                text_response(
                    self,
                    400,
                    f"ERROR: Upload incomplete: received {len(body)} bytes, expected {size} bytes\n",
                )
            except (ConnectionResetError, OSError):
                pass
            clear_activity()
            return None

        return body

    def handle_upload(self, params: dict[str, list[str]], start_slice: bool) -> None:
        name_values = params.get("name", [])
        if not name_values:
            text_response(self, 400, "ERROR: Missing name parameter\n")
            return

        profile = clean_param(params.get("profile", ["standard"])[0]).lower()
        try:
            scale = parse_scale(params.get("scale", [None])[0])
        except ValueError as exc:
            text_response(self, 400, f"ERROR: {exc}\n")
            return

        try:
            input_path = uploaded_stl_path(name_values[0])
        except ValueError as exc:
            text_response(self, 400, f"ERROR: {exc}\n")
            return

        body = self.read_post_body()
        if body is None:
            return

        ensure_bridge_dirs()
        set_activity(f"Saving STL: {input_path.name}")
        input_path.write_bytes(body)

        if not start_slice:
            try:
                set_activity(f"Reading STL info: {input_path.name}")
                profile_path = PROFILES.get(profile, next(iter(PROFILES.values())))
                stl = read_stl_info(input_path)
                bed_x, bed_y = profile_bed_size(profile_path)
                info_text = format_stl_info(stl, bed_x, bed_y, scale, profile_print_margin(profile_path))
                set_activity(f"Finding color layer: {input_path.name}")
                info_text += format_color_hint(input_path, scale)
            except Exception as exc:
                info_text = f"STL_INFO_ERROR: {exc}\n"
            finally:
                clear_activity()

            text_response(
                self,
                200,
                f"STATUS: OK\nMESSAGE: STL uploaded\nINPUT: {input_path}\nSIZE: {len(body)}\n"
                + info_text,
            )
            return

        output_path = uploaded_gcode_path_for(input_path)
        set_activity(f"Validating slice: {input_path.name}")
        error = validate_job(profile, input_path, output_path, scale)
        if error:
            clear_activity()
            text_response(self, 400, f"ERROR: {error}\n")
            return

        set_activity(f"Starting slice: {input_path.name}")
        job = start_slice_job(profile, input_path, output_path, scale)
        text_response(self, 200, format_job(job))

    def handle_slice(self, params: dict[str, list[str]]) -> None:
        input_values = params.get("input", [])
        if not input_values:
            text_response(self, 400, "ERROR: Missing input parameter\n")
            return

        profile = clean_param(params.get("profile", ["standard"])[0]).lower()
        try:
            scale = parse_scale(params.get("scale", [None])[0])
        except ValueError as exc:
            text_response(self, 400, f"ERROR: {exc}\n")
            return
        input_path = Path(clean_param(input_values[0]))
        if not ALLOW_PC_PATHS:
            text_response(self, 403, "ERROR: Direct PC paths disabled. Use upload-and-slice.\n")
            return

        output_values = params.get("output", [])
        if output_values:
            output_path = Path(clean_param(output_values[0]))
        else:
            output_path = make_output_path(input_path)

        error = validate_job(profile, input_path, output_path, scale)
        if error:
            text_response(self, 400, f"ERROR: {error}\n")
            return

        set_activity(f"Starting slice: {input_path.name}")
        job = start_slice_job(profile, input_path, output_path, scale)
        text_response(self, 200, format_job(job))

    def handle_slice_uploaded(self, params: dict[str, list[str]]) -> None:
        name_values = params.get("name", [])
        if not name_values:
            text_response(self, 400, "ERROR: Missing name parameter\n")
            return

        profile = clean_param(params.get("profile", ["standard"])[0]).lower()
        try:
            scale = parse_scale(params.get("scale", [None])[0])
        except ValueError as exc:
            text_response(self, 400, f"ERROR: {exc}\n")
            return

        try:
            input_path = uploaded_stl_path(name_values[0])
        except ValueError as exc:
            text_response(self, 400, f"ERROR: {exc}\n")
            return

        output_path = uploaded_gcode_path_for(input_path)
        set_activity(f"Validating slice: {input_path.name}")
        error = validate_job(profile, input_path, output_path, scale)
        if error:
            clear_activity()
            text_response(self, 400, f"ERROR: {error}\n")
            return

        set_activity(f"Starting slice: {input_path.name}")
        job = start_slice_job(profile, input_path, output_path, scale)
        text_response(self, 200, format_job(job))

    def handle_stl_info(self, params: dict[str, list[str]]) -> None:
        name_values = params.get("name", [])
        path_values = params.get("path", [])

        profile = clean_param(params.get("profile", ["standard"])[0]).lower()
        try:
            scale = parse_scale(params.get("scale", [None])[0])
        except ValueError as exc:
            text_response(self, 400, f"ERROR: {exc}\n")
            return
        profile_path = PROFILES.get(profile)
        if profile_path is None:
            text_response(self, 400, f"ERROR: Unknown profile: {profile}\n")
            return

        if path_values:
            if not ALLOW_PC_PATHS:
                text_response(self, 403, "ERROR: Direct PC paths disabled. Use name= uploaded STL.\n")
                return
            input_path = Path(clean_param(path_values[0]))
        elif name_values:
            try:
                input_path = uploaded_stl_path(name_values[0])
            except ValueError as exc:
                text_response(self, 400, f"ERROR: {exc}\n")
                return
        else:
            text_response(self, 400, "ERROR: Missing name or path parameter\n")
            return

        if not input_path.exists():
            text_response(self, 404, f"ERROR: STL not found: {input_path}\n")
            return

        try:
            set_activity(f"Reading STL info: {input_path.name}")
            stl = read_stl_info(input_path)
            bed_x, bed_y = profile_bed_size(profile_path)
        except Exception as exc:
            clear_activity()
            text_response(self, 400, f"ERROR: Cannot read STL size: {exc}\n")
            return

        status = "OK" if validate_stl_size(profile_path, input_path, scale) is None else "TOO_LARGE"
        set_activity(f"Finding color layer: {input_path.name}")
        color_hint = format_color_hint(input_path, scale)
        clear_activity()
        text_response(
            self,
            200,
            f"STATUS: {status}\nINPUT: {input_path}\n"
            + format_stl_info(stl, bed_x, bed_y, scale, profile_print_margin(profile_path))
            + color_hint,
        )

    def handle_job(self, params: dict[str, list[str]]) -> None:
        id_values = params.get("id", [])
        if not id_values:
            text_response(self, 400, "ERROR: Missing id parameter\n")
            return

        try:
            job_id = int(clean_param(id_values[0]))
        except ValueError:
            text_response(self, 400, "ERROR: Bad id parameter\n")
            return

        include_log = clean_param(params.get("log", ["0"])[0]) in ("1", "yes", "true")

        with JOBS_LOCK:
            job = JOBS.get(job_id)

        if job is None:
            text_response(self, 404, "ERROR: Unknown job\n")
            return

        text_response(self, 200, format_job(job, include_log=include_log))

    def handle_last(self, params: dict[str, list[str]]) -> None:
        with JOBS_LOCK:
            if not JOBS:
                text_response(self, 404, "ERROR: No job yet\n")
                return
            job = JOBS[max(JOBS)]

        include_log = clean_param(params.get("log", ["0"])[0]) in ("1", "yes", "true")
        text_response(self, 200, format_job(job, include_log=include_log))

    def handle_download(self, params: dict[str, list[str]]) -> None:
        id_values = params.get("id", [])
        name_values = params.get("name", [])

        if id_values:
            try:
                job_id = int(clean_param(id_values[0]))
            except ValueError:
                text_response(self, 400, "ERROR: Bad id parameter\n")
                return

            with JOBS_LOCK:
                job = JOBS.get(job_id)

            if job is None:
                text_response(self, 404, "ERROR: Unknown job\n")
                return

            if job.status != "OK":
                text_response(self, 409, format_job(job, include_log=True))
                return

            output_path = job.output_path
        elif name_values:
            filename = sanitize_filename(name_values[0], ".gcode")
            output_path = OUT_DIR / filename
        else:
            text_response(self, 400, "ERROR: Missing id or name parameter\n")
            return

        if not output_path.exists():
            text_response(self, 404, f"ERROR: G-code not found: {output_path}\n")
            return

        binary_response(self, 200, output_path.read_bytes(), output_path.name)

    def handle_delete(self, params: dict[str, list[str]]) -> None:
        name_values = params.get("name", [])
        if not name_values:
            text_response(self, 400, "ERROR: Missing name parameter\n")
            return

        kind = clean_param(params.get("type", ["all"])[0])
        try:
            text_response(self, 200, delete_bridge_file(name_values[0], kind))
        except (OSError, ValueError) as exc:
            text_response(self, 400, f"ERROR: {exc}\n")

    def help_text(self) -> str:
        return (
            "SlicerServer\n"
            "============\n"
            "\n"
            "Status:\n"
            "  /status\n"
            "\n"
            "Profiles:\n"
            "  /profiles\n"
            "\n"
            "Start slicing:\n"
            "  /slice?input=G:/modele.stl&output=G:/Sortie.gcode&profile=standard&scale=100\n"
            "\n"
            "Upload STL:\n"
            "  POST /upload?name=modele.stl\n"
            "  POST /upload-and-slice?name=modele.stl&profile=standard&scale=100\n"
            "\n"
            "Slice uploaded STL:\n"
            "  /slice-uploaded?name=modele.stl&profile=standard&scale=100\n"
            "\n"
            "Read STL size:\n"
            "  /stl-info?name=modele.stl&profile=standard&scale=100\n"
            "  /stl-info?path=G:/modele.stl&profile=standard&scale=100\n"
            "\n"
            "Check job:\n"
            "  /job?id=1\n"
            "  /job?id=1&log=1\n"
            "\n"
            "Download G-code:\n"
            "  /download?id=1\n"
            "  /download?name=modele.gcode\n"
            "\n"
            "Last job:\n"
            "  /last\n"
            "\n"
            "Server files:\n"
            "  /files\n"
            "  /delete?name=modele.stl&type=all\n"
        )

    def log_message(self, format: str, *args) -> None:
        return


def main() -> None:
    load_config()
    ensure_bridge_dirs()
    server = ThreadingHTTPServer((HOST, PORT), SlicerHandler)
    print(f"SlicerServer running on http://{HOST}:{PORT}/")
    print(f"Config: {CFG_FILE}")
    print(f"Allowed clients: {ALLOWED_CLIENTS_TEXT}")
    print(f"Direct PC paths: {'yes' if ALLOW_PC_PATHS else 'no'}")
    print(f"Max upload: {MAX_UPLOAD_BYTES} bytes")
    print(f"PrusaSlicer: {PRUSA_EXE}")
    print(f"Hotfolder: {BASE_DIR}")
    for name, profile_path in PROFILES.items():
        print(f"Profile {name}: {profile_path}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping SlicerServer.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
