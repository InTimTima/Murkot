# Deploy Murkot web on Vercel

Primary host for the Flutter web app (base-href `/`). GitHub Pages can stay as a mirror.

## One-time setup (Dashboard)

1. Open [vercel.com/new](https://vercel.com/new) → Import `quannxxii/Murkot`.
2. Framework Preset: **Other**.
3. Root Directory: `.` (repo root).
4. Build & Output are already in `vercel.json`:
   - Build Command: `bash tool/vercel_build.sh`
   - Output Directory: `build/web`
5. Deploy. First build clones Flutter stable (~a few minutes).

Project URL will look like `https://murkot-….vercel.app`.

## After first deploy

1. **Supabase** → Authentication → URL Configuration  
   - Site URL: `https://<your>.vercel.app`  
   - Redirect URLs: add `https://<your>.vercel.app/**`
2. Optional: custom domain in Vercel → Domains (see also `docs/custom_domain.md`).
3. Share links use `Uri.base` on web; no hardcoded Vercel URL required in Dart.

## Local check

```bash
bash tool/vercel_build.sh
# then: npx serve build/web
```

## Notes

- SPA deep links (`/@login`) are handled by `vercel.json` rewrites.
- `web/404.html` still helps GitHub Pages; on Vercel rewrites cover routing.
- Rebuilds on every push to the production branch (default `main`).
