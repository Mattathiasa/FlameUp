# Fonts

**Noto Sans Ethiopic** — SIL Open Font License 1.1 (see `OFL.txt`).

One family covers both Latin and Ethiopic, so an English/Amharic sentence never
hops fonts mid-line.

Google Fonts publishes this as a single variable font
(`NotoSansEthiopic[wdth,wght].ttf`). Flutter 3.19 matches weights most reliably
against static instances, so the four weights the design uses were instanced
from it with `fonttools`:

```bash
fonttools varLib.instancer 'NotoSansEthiopic[wdth,wght].ttf' \
    wght=400 wdth=100 -o NotoSansEthiopic-Regular.ttf
# ... and 500 Medium, 600 SemiBold, 700 Bold
```
