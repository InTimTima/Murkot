# Prod vs demo Supabase

Сейчас веб и демо-аккаунты бьют в один проект `zjozceddfueowkaokpok`. Перед приглашением «настоящих» людей заведите **отдельный** prod-проект.

## 1. Создать проект
1. [Supabase Dashboard](https://supabase.com/dashboard) → New project (регион ближе к СНГ, напр. Frankfurt).
2. Сохранить DB password и project ref.

## 2. Накатить схему
В SQL Editor **по порядку** из `supabase/`:
`schema.sql` → `features_v2`…`v20` (как в README), плюс `fix_profiles_grants.sql` / `push_webhooks.sql` если ещё не влиты в цепочку.

## 3. Ключи в приложении
- Prod URL + anon → отдельный конфиг (например `lib/config/supabase_config_prod.dart`) или `--dart-define=SUPABASE_URL=…`.
- Не коммитить service_role.
- Web release / gh-pages должен указывать на **prod**, локальная разработка — на demo.

## 4. Auth
- Confirm email: включить на prod.
- Redirect URLs: `https://quannxxii.github.io/Murkot/**`, Vercel URL (`https://*.vercel.app/**`) и будущий кастомный домен.
- Site URL: prod web origin.

## 5. Push
Повторить VAPID secrets + deploy `push-on-message` / `push-on-event` + webhooks на **prod** проекте (см. README).

## 6. Данные
- Демо-юзеров в prod **не** сидить (или сидить в отдельном staging).
- Модератора: `insert into app_moderators …` для своего логина.

## 7. Проверка
```bash
# временно подставив prod URL/anon в конфиг
dart run tool/backend_smoke_test.dart
```
