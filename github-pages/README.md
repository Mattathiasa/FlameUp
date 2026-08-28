# FlameUp prototype — GitHub Pages

`index.html` is the complete prototype: one self-contained file, no build step, no
external requests except the Noto Sans Ethiopic webfont.

## Publish it

### Option A — a project site (`username.github.io/flameup`)

1. Create a new repo, e.g. `flameup`.
2. Copy **`index.html`** and **`.nojekyll`** from this folder into the repo root.
3. Commit and push to `main`.
4. Repo → **Settings → Pages** → Source: **Deploy from a branch** → Branch: `main`,
   folder: `/ (root)` → **Save**.
5. Live in ~1 minute at `https://<username>.github.io/flameup/`.

### Option B — your user site (`username.github.io`)

Same, but the repo must be named exactly `<username>.github.io`. It serves from the
root URL.

### Option C — command line

```bash
git init flameup && cd flameup
cp /path/to/index.html /path/to/.nojekyll .
git add . && git commit -m "FlameUp prototype"
git branch -M main
git remote add origin https://github.com/<username>/flameup.git
git push -u origin main
# then enable Pages in Settings → Pages
```

## Notes

- `.nojekyll` stops GitHub from running Jekyll over the file. Keep it.
- The page is ~1.4 MB — fine for Pages, loads instantly on a normal connection.
- It is a **desktop-framed prototype**: an iPhone mock sits centred with a screen
  directory on the left. On a phone-sized browser the frame will be wider than the
  viewport and the page will scroll horizontally. If you want a phone-friendly version
  (frame hidden, app filling the screen), say so and I'll build that variant.
- To update, replace `index.html` and push again.
