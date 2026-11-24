"""Apply host-selected authentication to the guest during sbx kit installation."""

import json
import os
import tempfile
import tomllib
from pathlib import Path


def _replace(path, content):
    if path.exists() and path.read_text() == content:
        return
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as staged:
        try:
            staged.write(content)
            staged.close()
            os.replace(staged.name, path)
        finally:
            Path(staged.name).unlink(missing_ok=True)


def _codex(directory, mode):
    config = directory / "config.toml"
    begin = "# >>> agentenv sbx auth >>>\n"
    end = "# <<< agentenv sbx auth <<<\n"
    body = config.read_text()
    if body.startswith(begin):
        _, marker, body = body.partition(end)
        if not marker:
            raise ValueError(f"Incomplete sbx auth block in {config}")

    settings = []
    if mode != "none":
        settings.append('forced_login_method = "api"')
    if mode == "oauth":
        settings.extend([
            'model_provider = "sandboxd"',
            'model_providers.sandboxd.name = "Sandbox Proxy"',
            'model_providers.sandboxd.base_url = "https://chatgpt.com/backend-api/codex"',
            'model_providers.sandboxd.experimental_bearer_token = "oai-oat01-proxy-managed"',
            'model_providers.sandboxd.requires_openai_auth = false',
        ])
    content = begin + "\n".join(settings) + "\n" + end + body if settings else body
    tomllib.loads(content)
    auth = directory / "auth.json"
    sentinel = {"OPENAI_API_KEY": "proxy-managed"}
    existing = json.loads(auth.read_text()) if auth.exists() else None
    if mode != "none" and existing is not None and existing != sentinel:
        raise ValueError(f"Use a fresh sandbox to bind host credentials. Found existing {auth}")
    if mode != "none":
        _replace(auth, json.dumps(sentinel) + "\n")
    elif existing == sentinel:
        auth.unlink()
    _replace(config, content)


def _claude(directory, mode):
    config = directory / "settings.json"
    settings = json.loads(config.read_text())
    helper = "echo proxy-managed"
    if mode != "none":
        if settings.get("apiKeyHelper", helper) != helper:
            raise ValueError(f"An existing apiKeyHelper in {config} conflicts with sbx")
        settings["apiKeyHelper"] = helper
    elif settings.get("apiKeyHelper") == helper:
        del settings["apiKeyHelper"]
    else:
        return
    _replace(config, json.dumps(settings, indent=2) + "\n")


def _mode(service):
    key = f"SBX_CRED_{service}_MODE"
    mode = os.environ.get(key) or "none"
    if mode not in {"apikey", "oauth", "none"}:
        raise ValueError(f"Unexpected credential mode for {key}")
    return mode


if __name__ == "__main__":
    _codex(Path.home() / ".codex", _mode("OPENAI"))
    _claude(Path.home() / ".claude", _mode("ANTHROPIC"))
