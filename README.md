# MdMd — offline PWA markdown editor

Fully offline browser-based markdown editor. After install, **no external
network access** is ever made (zero CDN, zero analytics, zero telemetry).
All assets are vendored locally under `vendor/` and pre-cached by the
service worker.

## Features

- Edit `.md` / `.markdown` / `.txt` files
- Live preview with markdown-it + DOMPurify + highlight.js
- CodeMirror 5 editor (markdown / GFM modes)
- Tabs, dark mode, font size, scroll-sync
- **Ctrl+S overwrites the original file** (via File System Access API,
  granted automatically when the OS launches the PWA for a double-click)

## Install on Windows (one time, ~30 seconds)

Requirements: Microsoft Edge (Chromium-based, version 102+).

1. Copy this whole folder anywhere on disk (e.g. `C:\Tools\mdeditor`).
2. Double-click `install.cmd`.
   - A short PowerShell window opens. A small HTTP server starts on
     `127.0.0.1:<random-port>` (loopback only, not exposed to LAN).
   - Edge opens automatically.
3. In Edge, click the **install icon** in the address bar (or
   `…` menu → "Apps" → "Install this site as an app").
4. After install, Edge asks: *"Open .md, .markdown, .txt with MdMd?"*
   → click **Allow**.
5. Close the PowerShell window. The installer is no longer needed.

The PWA is now registered in Windows as the handler for those file
types. Double-click any `.md` file → MdMd opens it directly.

## Usage

- **Open a file**: double-click in Explorer, or drag-and-drop onto the
  window, or `Ctrl+O`.
- **Save (overwrite)**: `Ctrl+S`. Works directly on the file that was
  opened via double-click. The first save for a drag-and-drop tab
  prompts for "Save As".
- **New tab**: `Ctrl+N`.
- **Close tab**: `Ctrl+W`.

## Network behaviour

| When | Outbound traffic |
|------|------------------|
| `install.cmd` running | None. 127.0.0.1 listener only. |
| First load in Edge | None. Service worker pre-caches every asset from the loopback server. |
| After install (every double-click thereafter) | **None.** Edge serves the PWA from the SW cache. |
| Service worker `fetch` handler | Same-origin requests only. Any cross-origin attempt would error (this build intentionally has none). |

You can verify in Edge DevTools → Network: nothing leaves the machine.

## Files

```
mdeditor/
├── index.html              # Entry point (vendor refs only)
├── app.js                  # Pre-compiled UI (esbuild)
├── styles.css              # App styles
├── manifest.json           # PWA manifest (file_handlers for .md/.markdown/.txt)
├── sw.js                   # Service worker (precache-only)
├── install.cmd             # One-shot PWA installer entry
├── install.ps1             # Loopback HTTP server used by install.cmd
├── icons/                  # PWA icons (192 / 512 / maskable)
└── vendor/                 # All third-party libs + fonts (offline copy)
    ├── react.production.min.js          (MIT)
    ├── react-dom.production.min.js      (MIT)
    ├── codemirror/                      (MIT)
    ├── markdown-it.min.js               (MIT)
    ├── purify.min.js                    (Apache-2.0 / MPL-2.0)
    ├── highlight/                       (BSD-3-Clause)
    └── fonts/                           (SIL OFL-1.1: Inter, JetBrains Mono)
```

## Third-party licenses

All bundled libraries permit commercial use:

| Library | License |
|---------|---------|
| React 18 / ReactDOM 18 | MIT |
| CodeMirror 5.65 | MIT |
| markdown-it 14 | MIT |
| DOMPurify 3 | Apache-2.0 OR MPL-2.0 |
| highlight.js 11 | BSD-3-Clause |
| Inter (font) | SIL OFL-1.1 |
| JetBrains Mono (font) | SIL OFL-1.1 |

## Distribution (offline / restricted networks)

Target machines that cannot reach github.com or any public CDN can
still run MdMd: prepare the bundle on an internet-connected machine,
hand-carry the folder to the target, run `install.cmd` once.

### A. Prepare the bundle (on a machine with internet)

```bash
git clone https://github.com/trie0000/MdMd.git mdeditor
cd mdeditor
# (Optional) rebuild app.js from the JSX source if you changed it.
# See "Updating" below.
```

The repository already contains every vendored library and font, so
no `npm install` is required for normal distribution.

### B. Package it

Pick the form that fits the receiving environment:

| Form | Use when |
|------|----------|
| ZIP archive | USB stick, email attachment, SharePoint, file share |
| `git clone` on the target | Target can reach GitHub but not the public CDNs the app would otherwise use |
| Internal Git mirror | Org has its own GitLab / Azure DevOps / etc — push there and clone from inside the network |
| Network share / `\\server\share\mdeditor\` | Multiple users on the same intranet — they all install from one copy |

For a ZIP:

```bash
# From the parent directory:
zip -r mdeditor-vX.Y.zip mdeditor \
    -x 'mdeditor/.git/*' 'mdeditor/.github/*' 'mdeditor/.DS_Store' \
       'mdeditor/design_handoff_mdeditor/*'
```

Resulting archive is ~1.2 MB.

### C. Deliver

Whichever transport the receiving environment approves:

- Approved USB stick
- IT-sanctioned file transfer portal
- Pre-staged on a managed network share by IT
- Internal package manager (Chocolatey internal repo, Intune Win32 app, etc.)

### D. Install on each Windows machine

Each end-user (or IT, deploying centrally) does:

1. Extract `mdeditor/` anywhere on disk (e.g. `C:\Tools\mdeditor\`).
2. Double-click `install.cmd`.
3. In the Edge tab that opens, click the **install icon** in the
   address bar → **Install**.
4. Tick **Allow** when Edge asks about opening `.md` / `.markdown`
   / `.txt` with the app.
5. Close the PowerShell window. Done.

If the install icon does not appear or `.md` keeps opening in another
app, see [install-help.html](install-help.html) for troubleshooting.

### E. Centralized rollout (optional)

For larger deployments via SCCM / Intune / Group Policy:

- Place the extracted folder under a per-machine path
  (e.g. `C:\Program Files\MdMd\`).
- Run `install.cmd` from a logon script or a one-shot scheduled task
  under each user's context. PWA install is per-user in Edge.
- Pre-staging file associations via DISM `defaultAppAssociations.xml`
  is possible but requires the PWA's progID, which Edge mints at
  install time — easier to let `install.cmd` handle it.

### F. Updating an installed copy

1. Replace the folder contents with the new version.
2. Bump `CACHE_VERSION` in `sw.js` (already done if you pulled a
   release).
3. Re-run `install.cmd`. Edge picks up the new service worker and
   refreshes the cached assets.
4. If a major change happened, users can uninstall via
   `edge://apps` → MdMd → Uninstall, then re-run `install.cmd`.

## Updating (for developers)

To update a vendored library:

1. Re-download into `vendor/`.
2. If `app.js` (the compiled JSX) needs to change, edit the JSX source
   and re-run esbuild:

   ```bash
   npx esbuild app.jsx --minify --target=es2020 --outfile=app.js
   ```

3. **Bump `CACHE_VERSION` in `sw.js`** — otherwise the old service
   worker keeps serving stale assets.
4. Re-install the PWA (or visit the SW page in Edge and click "Update").

## Limitations

- Requires Edge / Chrome 102+ (File Handling API and `launchQueue`).
  Firefox / Safari are not supported for the double-click flow.
- Group policies that disable PWA install or file-association changes
  will block the install step. Verify with IT if needed.
- HTTP listener on `127.0.0.1` may be flagged by some EDR products
  during `install.cmd`. It is a one-shot, loopback-only listener.
