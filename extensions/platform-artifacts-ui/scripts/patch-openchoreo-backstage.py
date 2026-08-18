#!/usr/bin/env python3
"""Patch an OpenChoreo Backstage checkout with the Platform Artifacts extension.

Supports the OpenChoreo v1.2.2 portal composition and the newer createPortalApp
composition used on main. The plugin overlay must already be copied under
plugins/. The patch is idempotent and fails loudly when upstream structure has
changed in an incompatible way.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def die(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def update_dependency(package_file: Path, name: str) -> None:
    if not package_file.exists():
        die(f"missing {package_file}")
    data = json.loads(package_file.read_text())
    dependencies = data.setdefault("dependencies", {})
    dependencies[name] = "workspace:^"
    data["dependencies"] = dict(sorted(dependencies.items()))
    package_file.write_text(json.dumps(data, indent=2) + "\n")


def patch_app(app_file: Path) -> str:
    if not app_file.exists():
        die(f"missing {app_file}")
    text = app_file.read_text()
    if "platformArtifactsPluginAlpha" in text:
        return "already-patched"

    plugin_import = (
        "import platformArtifactsPluginAlpha from "
        "'@demo/backstage-plugin-platform-artifacts/alpha';"
    )

    # OpenChoreo v1.2.2 / createApp composition.
    if "const app = createApp({" in text and "features: [" in text:
        import_anchor = (
            "import platformEngineerCorePluginAlpha from "
            "'@openchoreo/backstage-plugin-platform-engineer-core/alpha';"
        )
        if import_anchor not in text:
            die("v1.2-style App.tsx no longer exposes the platformEngineerCorePluginAlpha import")
        text = text.replace(import_anchor, import_anchor + "\n" + plugin_import, 1)

        feature_anchor = "    platformEngineerCorePluginAlpha,"
        if feature_anchor not in text:
            die("v1.2-style App.tsx no longer exposes the expected features array anchor")
        text = text.replace(
            feature_anchor,
            feature_anchor + "\n    platformArtifactsPluginAlpha,",
            1,
        )
        app_file.write_text(text)
        return "createApp"

    # Newer OpenChoreo main / createPortalApp composition.
    create_portal_import = "import { createPortalApp } from '@openchoreo/backstage-portal-app';"
    root_line = "export default createPortalApp().createRoot();"
    if create_portal_import in text and root_line in text:
        text = text.replace(create_portal_import, create_portal_import + "\n" + plugin_import, 1)
        text = text.replace(
            root_line,
            "export default createPortalApp({\n"
            "  features: [platformArtifactsPluginAlpha],\n"
            "}).createRoot();",
            1,
        )
        app_file.write_text(text)
        return "createPortalApp"

    die("packages/app/src/App.tsx does not match a supported OpenChoreo portal composition")
    return "unreachable"


def patch_backend(backend_file: Path) -> None:
    if not backend_file.exists():
        die(f"missing {backend_file}")
    text = backend_file.read_text()
    marker = "backend.add(import('@demo/backstage-plugin-platform-artifacts-backend'));"
    if marker in text:
        return
    anchor = "backend.start();"
    if anchor not in text:
        die("packages/backend/src/index.ts no longer contains backend.start()")
    backend_file.write_text(text.replace(anchor, f"{marker}\n\n{anchor}", 1))


def patch_sidebar(root_file: Path) -> None:
    if not root_file.exists():
        die(f"missing {root_file}")
    text = root_file.read_text()
    if 'to="platform-artifacts"' in text:
        return
    if "ExtensionIcon" not in text:
        die("OpenChoreo sidebar no longer exposes ExtensionIcon; review sidebar patch")

    sidebar = """
                <SidebarItem
                  icon={ExtensionIcon}
                  to="platform-artifacts"
                  text="Platform Artifacts"
                />"""

    marker = 'text="Platform"'
    pos = text.find(marker)
    if pos < 0:
        die("could not locate the Platform sidebar entry")
    close = text.find('/>', pos)
    if close < 0:
        die("could not locate the end of the Platform sidebar entry")
    close += 2
    root_file.write_text(text[:close] + sidebar + text[close:])


def locate_sidebar(root: Path) -> Path:
    candidates = [
        root / "packages/app/src/components/Root/Root.tsx",
        root / "packages/portal-app/src/components/Root/Root.tsx",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    die("could not locate OpenChoreo portal sidebar Root.tsx")
    raise AssertionError


def main() -> None:
    if len(sys.argv) != 2:
        die("usage: patch-openchoreo-backstage.py <backstage-source-dir>")
    root = Path(sys.argv[1]).resolve()
    if not (root / "package.json").exists():
        die(f"{root} does not look like an OpenChoreo Backstage checkout")

    update_dependency(root / "packages/app/package.json", "@demo/backstage-plugin-platform-artifacts")
    update_dependency(root / "packages/backend/package.json", "@demo/backstage-plugin-platform-artifacts-backend")
    composition = patch_app(root / "packages/app/src/App.tsx")
    patch_backend(root / "packages/backend/src/index.ts")
    patch_sidebar(locate_sidebar(root))
    print(f"Platform Artifacts UI source patch applied successfully ({composition}).")


if __name__ == "__main__":
    main()
