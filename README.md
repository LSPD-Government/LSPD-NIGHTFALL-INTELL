# LSPD NIGHTFALL INTELL

A fresh intelligence workspace for the Los Santos Police Department roleplay community. This is a separate project from Nightwatch.

## Included sections
- Overview dashboard and workspace index
- Case management
- Warrants
- RICO investigations
- Corruption cases
- Suspect database
- Gang intelligence
- Intelligence reports
- Detective directory
- Administration and access guidance

The visual direction is a midnight navy night-sky theme with subtle stars, blue atmospheric lighting, and a responsive layout.

## Fresh setup
1. Use the dedicated, new Supabase project for Nightfall.
2. In **Project Settings → API**, copy the Project URL and the **anon/public** key.
3. Copy \`config.example.js\` to \`config.js\` and enter those two values. Never use a service-role/secret key in browser code.
4. In that same new project's **SQL Editor**, run the complete \`supabase/schema.sql\` file. It creates empty Nightfall tables only; no old records are imported.
5. Enable Email under **Authentication → Providers** and create your account.
6. Sign in once. Then run the admin promotion statement at the bottom of the SQL file after replacing the placeholder with your account email.
7. Enable GitHub Pages: **Repository Settings → Pages → Deploy from a branch → main → /(root) → Save**.
8. Ensure \`config.js\` exists in the repository for the published site. Do not commit secrets; the anon/public key is intended for browser use and must be protected by RLS.

## Security notes
- Row Level Security is enabled for all application tables.
- All authenticated staff can read records and create entries attributed to their own account.
- Command/Admin roles can update records; only Admin can delete records through database policies.
- Role changes are not exposed as a browser control.
- Use fictional roleplay information only. Review access and retention policies before storing sensitive material.

## Current limitations
This first full structure includes sign-in, record creation, searchable lists, dashboard counts, and a system/admin information page. Record editing/deletion screens, file attachments, password reset UI, and full activity-log viewer are not included yet. Those can be added after the initial deployment is tested.


## Account access flow
- Applicants register with an in-city name, a real email address for verification/recovery, and a password.
- The in-city name and email can both be used at sign-in with the same password. Username lookup is handled by the Supabase Edge Function, not by exposing email addresses in the public profile table.
- New accounts start as **Pending** and cannot read or create intelligence records until Command/Admin approves them.
- Command/Admin users can approve pending requests from the Administration page.
- The website does not persist the signed-in session in browser storage. A page refresh requires signing in again. The browser may independently offer to save a password; users can decline that prompt.
- The site does not display or store readable passwords. Supabase Authentication handles password verification.
