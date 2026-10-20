#!/usr/bin/env python3
"""Merge defaults and validate with the bundled JSON schema using only stdlib."""

import argparse
import json
import re
import sys
from copy import deepcopy
from pathlib import Path
from urllib.parse import urlparse


DEFAULT = {
    "artifacts": {"root": ".devflow-ui"},
    "runtime": {
        "target": "simulator",
        "deviceId": None,
        "bridge": {"baseUrl": "http://127.0.0.1:37777"},
    },
    "build": {
        "command": "xcodebuild {workspace|project} -scheme {scheme} -configuration {configuration} -derivedDataPath {derivedDataPath} -destination {destination} build",
        "scheme": "",
        "workspace": None,
        "project": None,
        "configuration": "Debug",
        "derivedDataPath": None,
        "destination": "platform=iOS Simulator,name=iPhone 16",
    },
    "review": {
        "nodeGate": {"mode": "self"},
        "finalGate": {"mode": "subagent", "agent": "ui-reviewer"},
        "requireIndependentNodeGate": False,
    },
    "evidence": {
        "mode": "runtime-geometry",
        "imageIdentity": "assetName",
        "tolerances": {"origin": 0.5, "size": 0.5, "font": 0.1, "colorChannel": 1, "radius": 0.5},
        "profiles": [
            {"id": "primary", "width": 402, "destination": "platform=iOS Simulator,name=iPhone 16 Pro"},
            {"id": "secondary", "width": 393, "destination": "platform=iOS Simulator,name=iPhone 16"},
        ],
    },
    "finalVerifier": {"mode": "builtin", "command": ""},
}

SCRIPT_DIR = Path(__file__).resolve().parent
SCHEMA_PATH = SCRIPT_DIR.parent / "config.schema.json"


def merge(base, override, path="config"):
    if not isinstance(override, dict):
        raise ValueError(f"{path} must be an object")
    for key, value in override.items():
        if key in base and isinstance(base[key], dict):
            merge(base[key], value, f"{path}.{key}")
        else:
            base[key] = value


def type_matches(value, expected):
    if expected == "null": return value is None
    if expected == "object": return isinstance(value, dict)
    if expected == "array": return isinstance(value, list)
    if expected == "string": return isinstance(value, str)
    if expected == "boolean": return isinstance(value, bool)
    if expected == "integer": return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number": return isinstance(value, (int, float)) and not isinstance(value, bool)
    return False


def schema_errors(value, schema, root, path="config", quiet=False):
    errors = []
    if "$ref" in schema:
        target = root
        for part in schema["$ref"].removeprefix("#/").split("/"):
            target = target[part]
        return schema_errors(value, target, root, path, quiet)
    expected = schema.get("type")
    if expected is not None:
        choices = expected if isinstance(expected, list) else [expected]
        if not any(type_matches(value, choice) for choice in choices):
            return [f"{path} must have type {'|'.join(choices)}"]
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path} must equal {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path} has unknown enum value {value!r}")
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0): errors.append(f"{path} must be non-empty")
        if "pattern" in schema and not re.search(schema["pattern"], value): errors.append(f"{path} has invalid format")
        if schema.get("format") == "uri":
            parsed = urlparse(value)
            if parsed.scheme not in ("http", "https") or not parsed.netloc:
                errors.append(f"{path} must be an http:// or https:// URI")
    if type_matches(value, "number"):
        if "minimum" in schema and value < schema["minimum"]: errors.append(f"{path} must be >= {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]: errors.append(f"{path} must be <= {schema['maximum']}")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for key in value.keys() - properties.keys(): errors.append(f"unknown field {path}.{key}")
        for key in schema.get("required", []):
            if key not in value: errors.append(f"{path}.{key} is required")
        for key, child in properties.items():
            if key in value: errors.extend(schema_errors(value[key], child, root, f"{path}.{key}", quiet))
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0): errors.append(f"{path} must contain at least {schema['minItems']} items")
        if "items" in schema:
            for index, item in enumerate(value): errors.extend(schema_errors(item, schema["items"], root, f"{path}[{index}]", quiet))
    for clause in schema.get("allOf", []):
        if "if" in clause:
            if not schema_errors(value, clause["if"], root, path, True):
                errors.extend(schema_errors(value, clause.get("then", {}), root, path, quiet))
        else:
            errors.extend(schema_errors(value, clause, root, path, quiet))
    if "oneOf" in schema:
        matches = sum(not schema_errors(value, option, root, path, True) for option in schema["oneOf"])
        if matches != 1: errors.append(f"{path} must match exactly one allowed form")
    return errors


def semantic_errors(config, capabilities=None):
    errors = []
    build, runtime = config["build"], config["runtime"]
    if capabilities is not None and config["evidence"]["imageIdentity"] == "hash":
        fields = capabilities.get("nodeFields", []) if isinstance(capabilities, dict) else []
        if "imageHash" not in fields:
            errors.append("evidence.imageIdentity=hash requires a bridge version that supports imageHash")
    if not isinstance(build.get("scheme"), str) or not build["scheme"].strip():
        errors.append("必须配置 build.scheme (build.scheme must be non-empty)")
    sources = [key for key in ("workspace", "project") if isinstance(build.get(key), str) and build[key].strip()]
    if len(sources) != 1: errors.append("build.workspace and build.project must have exactly one non-empty value")
    simulator = runtime["target"] == "simulator"
    expected = "platform=iOS Simulator" if simulator else "platform=iOS"
    destinations = [("build.destination", build["destination"])] + [
        (f"evidence.profiles[{index}].destination", profile["destination"])
        for index, profile in enumerate(config["evidence"]["profiles"])
    ]
    for path, destination in destinations:
        is_simulator = destination.startswith("platform=iOS Simulator")
        is_device = destination.startswith("platform=iOS") and not is_simulator
        if (simulator and not is_simulator) or (not simulator and not is_device):
            errors.append(f"{path} must be a {expected} destination")
    profiles = config["evidence"]["profiles"]
    ids = [profile["id"] for profile in profiles]
    widths = [profile["width"] for profile in profiles]
    if len(ids) != len(set(ids)): errors.append("evidence.profiles ids must be unique")
    if len(widths) != len(set(widths)): errors.append("evidence.profiles widths must be unique")
    command = build["command"]
    source_value = f"-workspace {build['workspace']}" if sources and sources[0] == "workspace" else (f"-project {build['project']}" if sources else None)
    values = {key: build.get(key) for key in ("scheme", "configuration", "derivedDataPath", "destination")}
    values["workspace|project"] = source_value
    for placeholder in re.findall(r"\{([^{}]+)\}", command):
        if placeholder not in values: errors.append(f"build.command has unknown placeholder {{{placeholder}}}")
        elif values[placeholder] is None or not str(values[placeholder]).strip():
            errors.append(f"build.command placeholder {{{placeholder}}} resolves empty")
    return errors


def resolve_command(config):
    command = config["build"]["command"]
    build = config["build"]
    values = {key: build.get(key) for key in ("scheme", "configuration", "derivedDataPath", "destination")}
    values["workspace|project"] = f"-workspace {build['workspace']}" if build.get("workspace") else f"-project {build['project']}"
    for key, value in values.items(): command = command.replace("{" + key + "}", "" if value is None else str(value))
    if re.search(r"\{[^{}]+\}", command): raise ValueError("resolvedBuildCommand contains unresolved placeholder")
    return command


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config", nargs="?", help="optional partial JSON config")
    parser.add_argument("--capabilities", help="optional probed bridge capabilities JSON")
    args = parser.parse_args()
    try:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        supplied = json.loads(Path(args.config).read_text(encoding="utf-8")) if args.config else {}
        capabilities = json.loads(Path(args.capabilities).read_text(encoding="utf-8")) if args.capabilities else None
        resolved = deepcopy(DEFAULT)
        merge(resolved, supplied)
        errors = schema_errors(resolved, schema, schema) + semantic_errors(resolved, capabilities)
        if errors: raise ValueError("; ".join(dict.fromkeys(errors)))
        command = resolve_command(resolved)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"config error: {exc}", file=sys.stderr)
        return 1
    print(json.dumps({"config": resolved, "resolvedBuildCommand": command}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
