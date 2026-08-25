# murkot.space — подключение к Vercel

Проект уже билдится через `tool/vercel_build.sh` → `build/web` (`vercel.json`).
Осталось привязать домен. Я могу сделать всё со стороны Vercel, но DNS — только ты (доступ к регистратору).

## Что я сделаю сам (готово)
- `vercel.json` уже с `buildCommand: bash tool/vercel_build.sh` и rewrites `/(.*) → /index.html` — Flutter SPA готов.
- Добавлю домен в Vercel: `vercel domains add murkot.space` + `www.murkot.space` (нужен токен команды murkot).

## Что нужно от тебя (5 минут)

1. **Где покупал домен murkot.space** (Reg.ru / Timeweb / Cloudflare / Nic.ru) — зайди в панель → `DNS` / `Управление зоной`.

2. **Добавить записи:**
   - Тип `A` | Хост `@` | Значение `76.76.21.21` | TTL 3600
   - Тип `A` | Хост `@` | Значение `76.223.126.88` (второй IP Vercel для отказоустойчивости, опционально)
   - Тип `CNAME` | Хост `www` | Значение `cname.vercel-dns.com` | TTL 3600

   *Если регистратор не даёт A на @ — ставь `CNAME` `@` → `cname.vercel-dns.com` или включи Cloudflare proxy (оранжевое облако).*

3. **В Vercel Dashboard** → `murkot/murkot` → `Settings → Domains` → `Add` → введи `murkot.space` и `www.murkot.space` → `Add`. Vercel проверит DNS и выпустит SSL (Let's Encrypt, ~1-2 мин).

4. **Проверка:** через 5-15 мин `https://murkot.space` должен отдавать тот же что `murkot.vercel.app`. Проверь `dig murkot.space` или https://dnschecker.org.

5. **Редирект www:** в Vercel поставь `www.murkot.space → murkot.space (Redirect)` или наоборот — по вкусу.

## Альтернатива без тебя
Если дашь доступ к регистратору (логин/пароль или API-токен Cloudflare), я сам проставлю записи и дождусь `Verified` в Vercel.

## После подключения
- На проде включи `Force HTTPS` (Vercel делает автоматом).
- Старый `murkot.vercel.app` останется алиасом — ничего ломать не нужно.
- Если нужен почтовый домен `hello@murkot.space` — скажи, добавлю MX.
