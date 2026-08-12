# Custom domain for Murkot web

Сейчас: `https://quannxxii.github.io/Murkot/`.

## Вариант A — GitHub Pages + свой домен (проще)
1. Купить домен (например `murkot.app`).
2. Repo `quannxxii/Murkot` → Settings → Pages → Custom domain → `app.murkot.app` (или apex).
3. DNS:
   - subdomain: `CNAME app → quannxxii.github.io`
   - apex: `A`/`ALIAS` по инструкции GitHub Pages.
4. Включить Enforce HTTPS.
5. Пересобрать веб с новым base-href:
   - если сайт в корне домена: `flutter build web --release --base-href /`
   - обновить `web/404.html` redirect на `/` (не `/Murkot/`)
6. Supabase Auth → Redirect URLs / Site URL на новый origin.
7. Обновить `buildPublicProfileUrl` fallback в `lib/utils/profile_deep_link.dart`.

## Вариант B — Cloudflare Pages / Netlify
То же по сути: статика из `build/web`, SPA fallback на `index.html`, base-href `/`, HTTPS из коробки.

## Чеклист после смены домена
- [ ] Логин / OAuth redirect
- [ ] Deep link `/@login`
- [ ] Web Push (VAPID subject / origin)
- [ ] Ссылки в README и шаринге профиля
