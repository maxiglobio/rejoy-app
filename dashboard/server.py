"""
Rejoy Analytics Dashboard - Local server that fetches stats from Supabase.
Run: python server.py
Open: http://localhost:8000
"""
import os
from datetime import datetime, timedelta
from collections import defaultdict

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, FileResponse
from dotenv import load_dotenv

# Load .env from dashboard directory, then cwd as fallback
_dashboard_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_dashboard_dir, ".env"))
if not os.getenv("SUPABASE_SERVICE_ROLE_KEY"):
    load_dotenv()
if not os.getenv("SUPABASE_SERVICE_ROLE_KEY"):
    load_dotenv(os.path.join(os.getcwd(), "dashboard", ".env"))

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://jvjsdcynjaamqfwkzpwf.supabase.co").rstrip("/")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

app = FastAPI(title="Rejoy Analytics")
app.add_middleware(CORSMiddleware, allow_origins=["*", "null"], allow_methods=["*"], allow_headers=["*"])


def supabase_headers():
    if not SUPABASE_KEY:
        raise ValueError("SUPABASE_SERVICE_ROLE_KEY is required. Add it to .env")
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }


@app.get("/api/stats")
def get_stats():
    """Fetch analytics from Supabase and return aggregated stats."""
    base = f"{SUPABASE_URL}/rest/v1"

    if not SUPABASE_KEY:
        return {
            "error": "SUPABASE_SERVICE_ROLE_KEY not set. Add it to dashboard/.env",
            "total_users": 0,
            "sessions_today": 0,
            "total_seeds": 0,
            "sessions_by_day": [],
            "activity_breakdown": [],
            "daily_active_users": [],
            "retention": {"cohort_size": 0, "day1_pct": 0, "day7_pct": 0, "day14_pct": 0},
        }

    headers = supabase_headers()

    with httpx.Client(timeout=30) as client:
        # Total users on platform (from auth.users via Admin API)
        auth_base = f"{SUPABASE_URL}/auth/v1"
        total_users = 0
        try:
            page = 1
            per_page = 1000
            while True:
                r = client.get(f"{auth_base}/admin/users", headers=headers, params={"page": str(page), "per_page": str(per_page)})
                if r.status_code != 200:
                    break
                data = r.json()
                users = data.get("users") or []
                total_users += len(users)
                if len(users) < per_page:
                    break
                page += 1
        except Exception:
            pass
        if total_users == 0:
            # Fallback: count from profiles
            r = client.get(f"{base}/profiles", headers=headers, params={"select": "id"})
            if r.status_code == 200:
                total_users = len(r.json())

        # Activity types (for names)
        r = client.get(f"{base}/activity_types", headers=headers, params={"select": "id,name"})
        r.raise_for_status()
        activity_names = {a["id"]: a["name"] for a in r.json()}

        # Sessions - last 30 days (for activity stats)
        since_30 = (datetime.utcnow() - timedelta(days=30)).isoformat()
        r = client.get(
            f"{base}/sessions",
            headers=headers,
            params={
                "select": "id,user_id,activity_type_id,start_date,seeds,created_at",
                "start_date": f"gte.{since_30}",
                "order": "start_date.desc",
            },
        )
        r.raise_for_status()
        sessions = r.json()

        # Sessions - last 90 days (for retention), request up to 10k rows
        since_90 = (datetime.utcnow() - timedelta(days=90)).isoformat()
        r_ret = client.get(
            f"{base}/sessions",
            headers={**headers, "Range": "0-9999", "Range-Unit": "items"},
            params={
                "select": "user_id,start_date",
                "start_date": f"gte.{since_90}",
                "order": "start_date.asc",
            },
        )
        r_ret.raise_for_status()
        sessions_ret = r_ret.json()

    # Aggregate
    today_str = datetime.utcnow().strftime("%Y-%m-%d")
    sessions_today = sum(1 for s in sessions if s["start_date"].startswith(today_str))

    total_seeds = sum(s["seeds"] for s in sessions)

    # Sessions by day (last 14 days)
    by_day = defaultdict(int)
    by_day_users = defaultdict(set)
    for s in sessions:
        day = s["start_date"][:10]  # YYYY-MM-DD from ISO string
        by_day[day] += 1
        by_day_users[day].add(s["user_id"])

    days_back = 14
    sessions_by_day = []
    daily_active_users = []
    for i in range(days_back - 1, -1, -1):
        d = (datetime.utcnow() - timedelta(days=i)).strftime("%Y-%m-%d")
        sessions_by_day.append({"date": d, "count": by_day[d]})
        daily_active_users.append({"date": d, "count": len(by_day_users[d])})

    # Activity breakdown
    by_activity = defaultdict(int)
    for s in sessions:
        aid = s["activity_type_id"]
        name = activity_names.get(aid, str(aid))
        by_activity[name] += 1
    activity_breakdown = [{"name": k, "count": v} for k, v in sorted(by_activity.items(), key=lambda x: -x[1])]

    # Retention: % of users who return on D1, D7, D14 after first session (90d cohort)
    first_session = {}  # user_id -> first date (YYYY-MM-DD)
    user_dates = set()  # (user_id, date) for all sessions
    today = datetime.utcnow().date()
    for s in sessions_ret:
        uid = s["user_id"]
        day = s["start_date"][:10]
        user_dates.add((uid, day))
        if uid not in first_session or day < first_session[uid]:
            first_session[uid] = day

    # D1 = returned next day; D7 = returned within 7 days; D14 = returned within 14 days
    retention_d1 = retention_d7 = retention_d14 = 0
    cohort_d1 = cohort_d7 = cohort_d14 = 0
    for uid, first_day in first_session.items():
        fd = datetime.strptime(first_day, "%Y-%m-%d").date()
        days_since_first = (today - fd).days
        returned_day1 = (uid, (fd + timedelta(days=1)).strftime("%Y-%m-%d")) in user_dates
        returned_within_7 = any((uid, (fd + timedelta(days=d)).strftime("%Y-%m-%d")) in user_dates for d in range(1, 8))
        returned_within_14 = any((uid, (fd + timedelta(days=d)).strftime("%Y-%m-%d")) in user_dates for d in range(1, 15))
        if days_since_first >= 1:
            cohort_d1 += 1
            if returned_day1:
                retention_d1 += 1
        if days_since_first >= 7:
            cohort_d7 += 1
            if returned_within_7:
                retention_d7 += 1
        if days_since_first >= 14:
            cohort_d14 += 1
            if returned_within_14:
                retention_d14 += 1
    retention = {
        "cohort_size": len(first_session),
        "day1_pct": round(100 * retention_d1 / cohort_d1, 1) if cohort_d1 else 0,
        "day7_pct": round(100 * retention_d7 / cohort_d7, 1) if cohort_d7 else 0,
        "day14_pct": round(100 * retention_d14 / cohort_d14, 1) if cohort_d14 else 0,
        "day1_retained": retention_d1,
        "day7_retained": retention_d7,
        "day14_retained": retention_d14,
    }

    return {
        "total_users": total_users,
        "sessions_today": sessions_today,
        "total_seeds": total_seeds,
        "sessions_by_day": sessions_by_day,
        "activity_breakdown": activity_breakdown,
        "daily_active_users": daily_active_users,
        "retention": retention,
    }


@app.get("/", response_class=HTMLResponse)
def index():
    return FileResponse(os.path.join(os.path.dirname(__file__), "index.html"))


if __name__ == "__main__":
    import uvicorn
    if not SUPABASE_KEY:
        print("WARNING: SUPABASE_SERVICE_ROLE_KEY not set. Create dashboard/.env with your key.")
        print("  See dashboard/.env.example for the format.")
    uvicorn.run(app, host="0.0.0.0", port=8000)
