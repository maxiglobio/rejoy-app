# Rejoy Analytics Dashboard

A local web dashboard to view Rejoy app analytics: user counts, session activity, and activity breakdown.

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
