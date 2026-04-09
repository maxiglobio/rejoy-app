# Rejoy Analytics Dashboard

A web dashboard to view Rejoy app analytics: user counts, session activity, retention, and activity breakdown.

This is **not** the marketing site (`website/` → [rejoy.help](https://rejoy.help)). Deploy the analytics app as a **separate Vercel project** (e.g. `rejoy-analytics`) so marketing stays unchanged.

## Setup

1. **Install dependencies**

   ```bash
   cd dashboard
   pip install -r requirements.txt
   ```
   (Use `python3 -m pip install -r requirements.txt` if `pip` is not on your PATH.)

2. **Configure Supabase**

   - Copy `.env.example` to `.env`
   - Get your **Service Role Key** from [Supabase Dashboard](https://supabase.com/dashboard) → your project → Settings → API
   - Add it to `.env`:
     ```
     SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
     ```

   The project URL is pre-filled. Change it if you use a different Supabase project.

## Run

```bash
python server.py
```
(Or `python3 server.py` on macOS.)

Open [http://localhost:8000](http://localhost:8000) in your browser.

## Metrics

- **Total users** – Count from `profiles`
- **Sessions today** – Sessions created today (UTC)
- **Total seeds** – Sum of seeds over the last 30 days
- **Sessions per day** – Line chart for the last 14 days
- **Activity breakdown** – Sessions by activity type
- **Daily active users** – Distinct users per day

Data refreshes on load and every hour.

---

## Deploy to Vercel (analytics only)

1. **Create a new Vercel project** (do not use the `website` / `rejoy-marketing` project).
2. **Root Directory**: set to `dashboard` if your repo root is the monorepo (e.g. `Projects/Rejoy`); or deploy from the `dashboard` folder only.
3. **Environment variables** (Project → Settings → Environment Variables), for **Production** (and Preview if you want):
   - `SUPABASE_URL` — same as in `.env.example` unless you use another project
   - `SUPABASE_SERVICE_ROLE_KEY` — **service role** key from Supabase → Settings → API (keep secret; never commit `.env`)
4. **Framework**: Other (or leave default). Vercel will detect Python under `api/`.
5. Deploy:

   ```bash
   cd dashboard
   npx vercel link    # once: create/link project e.g. rejoy-analytics
   npx vercel deploy --prod
   ```

6. Optional: add a subdomain (e.g. `analytics.rejoy.help`) on this project in Vercel → Domains. The marketing domain **rejoy.help** stays on the marketing project.

The app uses a FastAPI server locally (`server.py`) and a **Mangum** handler in `api/index.py` on Vercel. `vercel.json` rewrites all routes to that function so `/` and `/api/stats` work.

**Note:** Serverless has execution time limits; very large user lists may need a longer timeout (Vercel Pro) or pagination changes later.
