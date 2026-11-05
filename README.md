# LSPD NIGHTFALL INTELL

A separate intelligence workspace for the Los Santos Police Department roleplay community. This repository is independent from the existing LSPD Nightwatch website.

## Current status

- Responsive Nightfall sign-in and dashboard interface.
- Supabase email/password authentication integration.
- Initial case, warrant, and persons-of-interest record views.
- Starter database schema with row-level security policies.
- No credentials or service-role keys are committed.

## Setup checklist

1. Create/use the separate Supabase project intended for Nightfall.
2. In **Project Settings → API**, copy the Project URL and the **anon/public** key.
3. Copy `config.example.js` to a new file named `config.js`; enter those two values. Never use a `service_role` key in browser code.
4. In the correct Supabase project's **SQL Editor**, run the complete contents of `supabase/schema.sql`.
5. In Supabase **Authentication → Providers**, enable Email. Create/invite department accounts using the authentication controls you choose for your community.
6. Sign in once with your account. In the SQL Editor, run the admin promotion statement at the bottom of `supabase/schema.sql`, replacing the email with your login email.
7. Enable GitHub Pages for this repository: **Settings → Pages → Deploy from a branch → main → /(root) → Save**.
8. Add `config.js` for the deployed site using the Project URL and anon/public key. The anon key is public by design; database access must be protected by RLS. Never publish the service-role key.

## Files

- `index.html` — application structure.
- `styles.css` — responsive visual design.
- `app.js` — authentication and record dashboard.
- `config.example.js` — safe configuration template.
- `supabase/schema.sql` — database tables, trigger, and RLS policies.

## Important limitations

This is a starter version. It does not yet include record editing/deletion in the interface, file uploads, audit-log automation, role-management screens, password reset UI, or production deployment configuration. The SQL file must be run manually in the correct Supabase project before the app can connect. Use fictional roleplay information only until your organization has reviewed security and retention requirements.
