# Akademia Kardiologii Zabiegowej 2026: landing page

Static page announcing the free AKZ 2026 course and collecting e-mails for the premiere notification.

- `landing/index.html`: main page, the "film" variant (360° room as the full hero background); `film.html` redirects here
- `landing/okno.html`: alternative with the room in a window card
- `landing/pierwszy.html` (the first index), `kartka.html`, `mix.html`, `prosty.html`: earlier variants

Preview locally (WebGL video textures need http, not file://):

```
PORT=8360 node tools/serve.mjs
```

then open http://localhost:8360/.

Publish to GitHub Pages (served from the `gh-pages` branch, which holds `landing/` as its root):

```
git subtree push --prefix landing origin gh-pages
```

Open items: `SIGNUP_ENDPOINT` in the notify script is empty (submit is simulated), the privacy policy link is a placeholder.
