# LaunchDesk — Universal Business Planner

A reusable product/category-neutral Week 1 business research dashboard. **No product names, materials, 3D printing, or metal categories are preset.** Only eight generic Week 1 tasks (14–20 Oct 2026) are provided. Everything else starts empty.

## Files

- `index.html` — responsive dashboard; research tables, forms, tasks, scores and cost estimates
- `config.js` — *public* Supabase Project URL and publishable / anon key (optional until you enable shared cloud mode)
- `supabase_setup.sql` — database tables, authentication access policies, invite functions
- `README.md` — this guide

## Try it immediately, without a database

Open `index.html` in your browser (or put files on GitHub Pages). When `config.js` is blank, the app uses **LOCAL DEMO MODE**, with `localStorage` saving only in the current browser/profile. This is not synchronized with anybody else. Use **Settings > Export JSON backup** to protect your data. Clearing site storage can erase local-only research.

## Set up the shared online database

1. Go to https://supabase.com/dashboard and create a project. Keep your database password private.
2. Go to **SQL Editor**. Paste and run all of `supabase_setup.sql` on your new, empty project.
3. Go to **Authentication > Providers** and enable **Email** (magic-link/OTP authentication). Verify email sending works. Supabase's built-in email service may have rate limits; configure SMTP for sustained use.
4. In **Project Settings > API** (or **Connect > API Keys** in the new dashboard), copy the **Project URL** and **anon / publishable key** into `config.js`:

   ```js
   window.APP_CONFIG = {
     supabaseUrl: 'https://YOUR-PROJECT.supabase.co',
     supabaseAnonKey: 'YOUR-PUBLIC-ANON-OR-PUBLISHABLE-KEY'
   };
   ```

   The anon/publishable key is designed for client use **only when row-level security is correctly configured**. NEVER paste the `service_role` key, database password, or any secret key into GitHub, HTML or client-side JavaScript.
5. Upload `index.html`, `config.js`, `supabase_setup.sql`, and `README.md` to a GitHub repository. Make sure `index.html` is in the root (or use `/docs` and configure Pages accordingly).
6. In **GitHub repository > Settings > Pages > Build and deployment**, choose **Deploy from a branch**, branch **main**, root `/`, then save. Wait until GitHub shows the URL: `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/`.
7. In Supabase, set **Authentication > URL Configuration > Site URL** to your Pages URL. Add exactly that GitHub Pages URL as an **additional redirect URL** (including trailing slash; a wildcard URL is unnecessary). This ensures emailed sign-in links return to the correct website.
8. Open your GitHub Pages URL. Log in with your email magic link, click **Create Workspace**, and begin using the live cloud database. Entries are stored in Supabase, not the repository. Editing a record does not require a GitHub commit.
9. Invite someone: **Settings > Share this workspace > View only or Can edit > Create link**. Send the generated link privately. The person opens it, signs in, and joins your workspace. Everyone in the same workspace sees saved updates when they reload or navigate; this starter app does **not** implement instant websocket/live push.

## Privacy and collaboration

- Supabase database has **Row Level Security (RLS)** on all tables. Only logged-in workspace members can read data in that workspace. Owner/editor can add, edit and delete entries; viewer can read.
- Invite links are **valid for 24 hours, maximum 10 uses**, and anyone with the link who is signed in can join. They should not be posted publicly. A valid invitation grants *persistent* workspace access after joining; expiration stops new joins but does not remove existing members.
- The starter app does not yet offer a team-members/permission-revocation UI. To remove someone or revoke invite tokens, the owner must currently perform an admin operation directly in Supabase or add admin UI. Do not share extremely sensitive information until that capability exists.
- `Documents` tracks **checklist status only**. Never put raw Aadhaar/PAN numbers, ID scans, passwords, financial credentials or privately shared document URLs in this app. Store sensitive documents separately in a secured service.
- Database quotas, email limits, uptime and service prices depend on Supabase's current plan.
- A public GitHub Pages URL makes the **website** visible publicly; the **business data** remains protected behind Supabase authentication and RLS. Your repository's frontend source is public if the repository is public.

## App functionality

- Generic week targets (14–20 October 2026)
- Blank Idea Bank, Competitors, Scorecard, Cost Planner, Document tracker, Vendor tracker, Decision log
- Search, add/edit/delete, statuses, score out of 30, estimated contribution/margin
- Shared workspace with viewer/editor invitation
- JSON export; JSON import is provided for local-demo mode (not cloud import)

## Troubleshooting

- **Only local demo shows:** check `config.js` values and browser Developer Tools console. Project URL must include `https://`.
- **Magic link sends but sign-in fails:** review Supabase Authentication URL Configuration and authorized redirect URLs. Avoid `file://` when using cloud mode.
- **403/RLS error:** confirm you executed `supabase_setup.sql`, have logged in, are an actual workspace member, and are not trying to edit with viewer access.
- **Invite link no longer works:** generate a new one. Existing members remain members after expiry.
- **GitHub Pages 404:** confirm file is `index.html`, that Pages is enabled for the correct branch/folder and wait for deployment.

This starter tool is not a legal or export-compliance certification system. Verify registrations, marketplace requirements and customs rules at official sources before applying or shipping.
