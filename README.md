# Murkot

**Murkot** — CIS IT-площадка, чтобы найти команду, проект или людей в стартап. Чаты внутри — чтобы договориться.

## Что внутри

- **Доска** — объявления, витрина проектов, матч по карточкам, сообщества
- **Чаты** — личные, группы и каналы
- **Профиль** — карточка разработчика, заметка «зачем я здесь»

## Запуск

```bash
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
```

Конфиг Supabase: `lib/config/supabase_config.dart` (URL + anon key). Для продакшена — отдельный Supabase-проект и свои ключи; anon key сам по себе не секрет, но RLS обязан быть жёстким.

## Миграции Supabase (по порядку)

В SQL Editor проекта применяйте файлы из `supabase/` **строго по порядку**, если база ещё не накатывалась:

1. `schema.sql` — база (если новый проект)
2. `features_v2.sql` … `features_v9.sql`
3. `features_v10.sql` … `features_v15.sql` — доска / матч / сообщества
4. **`features_v16.sql`** — security hardening (обязательно перед публичным доступом)
5. **`features_v17.sql`** — push events (матч), жалобы, скрытие объявлений, аналитика, инвайты в группы

### Push (после v17)

1. Deploy Edge Functions: `push-on-message`, `push-on-event`
2. Database Webhooks:
   - `messages` INSERT → `push-on-message`
   - `push_events` INSERT → `push-on-event`
3. Secrets: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`

## Проверка после v16

- нельзя править чужое сообщение
- приватную группу нельзя найти/вступить через поиск
- в `profiles` через REST не отдаётся `email` чужих пользователей
