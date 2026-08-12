# Custom domain for Murkot web

Предпочтительно хостить веб на **Vercel** (`docs/vercel.md`), затем повесить свой домен там.

Сейчас запасной зеркало: `https://quannxxii.github.io/Murkot/`.

## Вариант A — Vercel + свой домен (рекомендуется)
1. Задеплоить по `docs/vercel.md`.
2. Vercel → Project → Settings → Domains → добавить `app.murkot.app` (или apex).
3. DNS по подсказкам Vercel (обычно `CNAME` на `cname.vercel-dns.com`).
4. Supabase Auth → Site URL / Redirect URLs на новый origin.
5. Web Push: origin должен совпадать с prod URL.

## Вариант B — GitHub Pages + свой домен
1. Купить домен (например `murkot.app`).
2. Repo `quannxxii/Murkot` → Settings → Pages → Custom domain → `app.murkot.app` (или apex).
3. DNS:
   - subdomain: `CNAME app → quannxxii.github.io`
   - apex: `A`/`ALIAS` по инструкции GitHub Pages.
4. Включить Enforce HTTPS.
5. Пересобрать веб с новым base-href:
   - если сайт в корне домена: `flutter build web --release --base-href /`
   - обновить `web/404.html` (скрипт уже выбирает `/` vs `/Murkot/`)
6. Supabase Auth → Redirect URLs / Site URL на новый origin.

## Вариант C — Cloudflare Pages / Netlify
Статика из `build/web`, SPA fallback на `index.html`, base-href `/`.

## Чеклист после смены домена
- [ ] Логин / OAuth redirect
- [ ] Deep link `/@login`
- [ ] Web Push (VAPID subject / origin)
- [ ] Ссылки в README и шаринге профиля
