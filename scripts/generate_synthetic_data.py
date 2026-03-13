#!/usr/bin/env python3
"""
Generate synthetic B2B SaaS data for b2b-saas-dbt.

Populates BigQuery raw source tables with realistic data:
  - raw_funnel.events          (~8M rows, 50K users, 24 months)
  - raw_billing.subscriptions  (~18-20K rows)
  - raw_billing.invoices       (~14-16K rows)
  - raw_marketing.spend        (~6K rows)
  - raw_support.tickets        (~50-55K rows)

Usage:
    source .venv/bin/activate
    python scripts/generate_synthetic_data.py
    python scripts/generate_synthetic_data.py --dry-run       # local parquet only
    python scripts/generate_synthetic_data.py --project my-gcp-project
"""

import argparse
import json
import os
import uuid
from datetime import datetime, timedelta, date, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from google.cloud import bigquery

# ── Configuration ──────────────────────────────────────────────────────────

SEED = 42
NUM_USERS = 50_000
START_DATE = date(2024, 3, 1)
END_DATE = date(2026, 2, 28)
NUM_DAYS = (END_DATE - START_DATE).days
END_DATETIME = datetime.combine(END_DATE, datetime.max.time(), tzinfo=timezone.utc)

# Plans and monthly MRR (prices before and after the price change)
PLANS = {"free": 0, "starter": 49, "pro": 149, "enterprise": 499}
PLANS_V2 = {"free": 0, "starter": 59, "pro": 149, "enterprise": 499}
PRICE_CHANGE_DATE = date(2025, 3, 1)  # starter $49 → $59 at year 2
PLAN_LIST = ["starter", "pro", "enterprise"]
ANNUAL_DISCOUNT = 0.83  # annual = monthly * 12 * 0.83


def get_plan_price(plan, event_date):
    """Return the correct plan price based on the price change date."""
    d = event_date.date() if isinstance(event_date, datetime) else event_date
    prices = PLANS_V2 if d >= PRICE_CHANGE_DATE else PLANS
    return prices.get(plan, 0)

# Funnel conversion rates
SIGNUP_TO_ACTIVATE = 0.60
ACTIVATE_TO_TRIAL = 0.35
TRIAL_TO_PAID = 0.55
MONTHLY_CHURN_RATE = 0.045
MONTHLY_UPGRADE_RATE = 0.025
MONTHLY_DOWNGRADE_RATE = 0.008
REACTIVATION_RATE = 0.12  # of churned accounts within 90 days

# Channel acquisition weights
CHANNELS = {
    "organic": 0.35,
    "paid_search": 0.20,
    "paid_social": 0.15,
    "referral": 0.15,
    "email": 0.10,
    "direct": 0.05,
}

PLATFORMS = {"web": 0.60, "ios": 0.25, "android": 0.15}
DEVICE_TYPES = {"desktop": 0.55, "mobile": 0.35, "tablet": 0.10}
BROWSERS = {"chrome": 0.55, "safari": 0.25, "firefox": 0.12, "other": 0.08}
OS_MAP = {
    "web": {"windows": 0.45, "macos": 0.40, "linux": 0.15},
    "ios": {"ios": 1.0},
    "android": {"android": 1.0},
}

SIGNUP_METHODS = {"google": 0.45, "email": 0.40, "github": 0.15}
FEATURES = [
    "dashboard_view", "report_create", "chart_edit", "data_export",
    "filter_apply", "share_report", "alert_create", "api_call",
    "integration_setup", "template_use",
]
PAGES = [
    "/", "/dashboard", "/reports", "/settings", "/billing",
    "/integrations", "/team", "/docs", "/pricing", "/changelog",
    "/features", "/onboarding", "/analytics", "/export", "/api-docs",
]
REFERRERS = [
    "https://google.com", "https://twitter.com", "https://linkedin.com",
    "https://reddit.com", "https://producthunt.com", "https://hn.algolia.com",
    None, None, None,  # direct traffic
]

TICKET_CATEGORIES = {"bug": 0.30, "feature_request": 0.25, "billing": 0.15,
                     "onboarding": 0.20, "other": 0.10}
TICKET_PRIORITIES = {"low": 0.30, "medium": 0.40, "high": 0.20, "critical": 0.10}

# User agent strings for bot detection signals
BOT_USER_AGENTS = [
    "python-requests/2.31.0",
    "curl/8.1.2",
    "Go-http-client/1.1",
    "Java/17.0.1",
    "Python/3.11 aiohttp/3.8.4",
]
USER_AGENTS = {
    "chrome": [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    ],
    "safari": [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
    ],
    "firefox": [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
        "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    ],
    "other": [
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    ],
}

# Marketing campaigns per paid channel
CAMPAIGNS = {
    "paid_search": [
        ("cmp_ps_brand", "Brand Search - Exact"),
        ("cmp_ps_generic", "Generic Analytics Keywords"),
        ("cmp_ps_competitor", "Competitor Targeting"),
    ],
    "paid_social": [
        ("cmp_pso_linkedin_retarget", "LinkedIn Retargeting"),
        ("cmp_pso_fb_lookalike", "Facebook Lookalike Audiences"),
        ("cmp_pso_tw_awareness", "Twitter Awareness Campaign"),
    ],
    "email": [
        ("cmp_em_newsletter", "Weekly Newsletter"),
        ("cmp_em_nurture", "Nurture Sequence"),
    ],
}

# Experiments (id, name, start_day_offset, duration_days, traffic_pct)
EXPERIMENTS = [
    # Year 1
    ("exp_onboarding_v2", "Onboarding Flow V2", 30, 60, 0.50),
    ("exp_pricing_page", "Pricing Page Redesign", 90, 45, 0.30),
    ("exp_checkout_flow", "Simplified Checkout", 150, 40, 0.40),
    ("exp_feature_tour", "Interactive Feature Tour", 200, 50, 0.35),
    ("exp_email_cadence", "Email Cadence Test", 60, 90, 0.25),
    # Year 2
    ("exp_onboarding_v3", "Onboarding Flow V3", 400, 60, 0.50),
    ("exp_annual_nudge", "Annual Plan Nudge", 450, 45, 0.35),
    ("exp_activation_cta", "Activation CTA Experiment", 500, 50, 0.40),
    ("exp_referral_program", "Referral Incentive Test", 550, 60, 0.30),
    ("exp_dashboard_redesign", "Dashboard Redesign", 620, 45, 0.45),
]


# ── Helpers ────────────────────────────────────────────────────────────────

rng = np.random.default_rng(SEED)


def rint(low, high):
    """Random int compatible with timedelta (returns Python int, not numpy.int64)."""
    return int(rng.integers(low, high))


def uuid4():
    """Seeded UUID for reproducibility — uses rng instead of OS randomness."""
    return str(uuid.UUID(bytes=rng.bytes(16), version=4))


def weighted_choice(options: dict) -> str:
    keys = list(options.keys())
    weights = list(options.values())
    return rng.choice(keys, p=weights)


def weighted_choices(options: dict, size: int) -> np.ndarray:
    keys = list(options.keys())
    weights = list(options.values())
    return rng.choice(keys, size=size, p=weights)


def random_time_on_day(d: date) -> datetime:
    """Random datetime on a given date with weekday/weekend weighting."""
    if d.weekday() < 5:  # weekday
        hour = int(rng.normal(14, 4))  # peak at 2pm
    else:
        hour = int(rng.normal(11, 3))  # later start on weekends
    hour = max(0, min(23, hour))
    minute = rint(0, 60)
    second = rint(0, 60)
    return datetime(d.year, d.month, d.day, hour, minute, second,
                    tzinfo=timezone.utc)


def add_ingest_delay(event_time: datetime, late_pct: float = 0.05) -> tuple:
    """Return (ingest_time, _loaded_at) with realistic delays."""
    if rng.random() < late_pct:
        # late-arriving event: 1-48 hours delay
        delay_s = int(rng.exponential(scale=14400))  # mean 4 hours
        delay_s = min(delay_s, 172800)  # cap at 48 hours
    else:
        # normal: 0.5-30 seconds
        delay_s = max(1, int(rng.exponential(scale=5)))
        delay_s = min(delay_s, 30)
    ingest_time = event_time + timedelta(seconds=delay_s)
    loaded_at = ingest_time + timedelta(seconds=rint(1, 10))
    return ingest_time, loaded_at


def date_range(start: date, end: date):
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


# ── Phase 1: User + Account Generation ────────────────────────────────────

def generate_users(num_users=NUM_USERS):
    """Generate users with signup dates, channels, platforms."""
    print(f"Generating {num_users:,} users...")

    # Signup distribution: growth over 24 months with seasonality
    n_signup_days = NUM_DAYS + 1  # include END_DATE
    day_weights = np.zeros(n_signup_days)
    for i in range(n_signup_days):
        d = START_DATE + timedelta(days=i)
        # Base growth: accelerating over time (early-stage → growth)
        growth = 1.0 + 2.5 * (i / NUM_DAYS)
        # Weekly rhythm
        weekly = 0.3 * np.sin(2 * np.pi * i / 7)
        # Seasonality: Q4 budget spike (Oct-Nov), holiday dip (Dec 20 – Jan 5),
        # summer slowdown (Jul-Aug)
        month, day_of_month = d.month, d.day
        if month in (10, 11):
            seasonal = 1.25  # Q4 budget flush
        elif (month == 12 and day_of_month >= 20) or (month == 1 and day_of_month <= 5):
            seasonal = 0.4  # holiday freeze
        elif month in (7, 8):
            seasonal = 0.75  # summer slowdown
        elif month in (1, 9):
            seasonal = 1.15  # new year / back from summer
        else:
            seasonal = 1.0
        day_weights[i] = (growth + weekly) * seasonal
        # Weekend dip
        if d.weekday() >= 5:
            day_weights[i] *= 0.6
    day_weights = np.maximum(day_weights, 0.01)  # floor
    day_weights /= day_weights.sum()

    signup_day_offsets = rng.choice(n_signup_days, size=num_users, p=day_weights)
    signup_day_offsets.sort()  # chronological order

    users = []
    for i in range(num_users):
        signup_date = START_DATE + timedelta(days=int(signup_day_offsets[i]))
        channel = weighted_choice(CHANNELS)
        platform = weighted_choice(PLATFORMS)

        # UTM fields for paid channels
        utm_source, utm_medium, utm_campaign = None, None, None
        if channel in CAMPAIGNS:
            campaign_id, _ = CAMPAIGNS[channel][rint(0, len(CAMPAIGNS[channel]))]
            utm_campaign = campaign_id
            utm_source = channel
            utm_medium = "cpc" if "search" in channel else "social" if "social" in channel else "email"

        # ~1% of signups are bot/spam — flag for downstream filtering
        is_bot = rng.random() < 0.01

        browser = "other" if is_bot else weighted_choice(BROWSERS)
        if is_bot:
            user_agent = BOT_USER_AGENTS[rint(0, len(BOT_USER_AGENTS))]
        else:
            ua_list = USER_AGENTS[browser]
            user_agent = ua_list[rint(0, len(ua_list))]

        user = {
            "user_id": f"usr_{uuid4()[:12]}",
            "anon_id": f"anon_{uuid4()[:12]}",
            "signup_date": signup_date,
            "channel": channel,
            "platform": platform,
            "device_type": weighted_choice(DEVICE_TYPES),
            "browser": browser,
            "os": weighted_choice(OS_MAP[platform]),
            "utm_source": utm_source,
            "utm_medium": utm_medium,
            "utm_campaign": utm_campaign,
            "signup_method": "email" if is_bot else weighted_choice(SIGNUP_METHODS),
            "user_agent": user_agent,
            "is_bot": is_bot,
        }
        users.append(user)

    return users


def assign_journeys(users):
    """Determine lifecycle stage for each user: activate, trial, subscribe, churn."""
    print("Simulating user journeys...")

    for user in users:
        signup_date = user["signup_date"]
        days_since_signup = (END_DATE - signup_date).days

        # Activation: 60% activate within 1-7 days (bots never activate)
        user["activated"] = False if user.get("is_bot") else rng.random() < SIGNUP_TO_ACTIVATE
        if user["activated"]:
            activate_delay = max(0, int(rng.exponential(scale=2.5)))
            activate_delay = min(activate_delay, 14)
            user["activation_date"] = signup_date + timedelta(days=activate_delay)
            if user["activation_date"] > END_DATE:
                user["activated"] = False
                user["activation_date"] = None
        else:
            user["activation_date"] = None

        # Account creation: activated users may create or join an account
        user["account_id"] = None
        user["account_role"] = None
        user["account_join_date"] = None

        # Trial and subscription (set in account phase)
        user["trialed"] = False
        user["subscribed"] = False
        user["plan"] = "free"
        user["billing_cycle"] = None

    return users


def generate_accounts(users):
    """Create accounts. ~70% of activated users create one; others join existing."""
    print("Generating accounts...")
    accounts = {}
    user_by_id = {u["user_id"]: u for u in users}
    activated = [u for u in users if u["activated"]]

    # 70% of activated users create an account
    creators = [u for u in activated if rng.random() < 0.70]

    for u in creators:
        account_id = f"acc_{uuid4()[:12]}"
        join_date = u["activation_date"] + timedelta(days=int(rint(0, 3)))
        if join_date > END_DATE:
            continue
        u["account_id"] = account_id
        u["account_role"] = "owner"
        u["account_join_date"] = join_date

        accounts[account_id] = {
            "account_id": account_id,
            "owner_user_id": u["user_id"],
            "created_date": join_date,
            "members": [u["user_id"]],
        }

    # Some accounts invite additional members (20% of accounts, 1-8 members)
    account_list = list(accounts.values())
    inviters = [a for a in account_list if rng.random() < 0.20]
    # Pool of activated users without accounts
    unassigned = [u for u in activated if u["account_id"] is None]
    rng.shuffle(unassigned)
    idx = 0

    for acct in inviters:
        n_invites = min(rint(1, 9), len(unassigned) - idx)
        if n_invites <= 0:
            break
        for _ in range(n_invites):
            u = unassigned[idx]
            idx += 1
            join_delay = rint(1, 30)
            join_date = acct["created_date"] + timedelta(days=int(join_delay))
            if join_date > END_DATE:
                continue
            u["account_id"] = acct["account_id"]
            u["account_role"] = "member"
            u["account_join_date"] = join_date
            acct["members"].append(u["user_id"])

    # Enterprise accounts get more members
    enterprise_candidates = [a for a in account_list if len(a["members"]) >= 3
                            and rng.random() < 0.15]
    for acct in enterprise_candidates:
        n_extra = min(rint(5, 16), len(unassigned) - idx)
        if n_extra <= 0:
            break
        for _ in range(n_extra):
            u = unassigned[idx]
            idx += 1
            join_delay = rint(1, 60)
            join_date = acct["created_date"] + timedelta(days=int(join_delay))
            if join_date > END_DATE:
                continue
            u["account_id"] = acct["account_id"]
            u["account_role"] = "member"
            u["account_join_date"] = join_date
            acct["members"].append(u["user_id"])

    print(f"  {len(accounts):,} accounts created, "
          f"{sum(1 for u in users if u['account_id']):,} users assigned")
    return accounts


def simulate_subscriptions(users, accounts):
    """Determine trial/subscription/churn lifecycle per account."""
    print("Simulating subscription lifecycles...")

    account_subs = {}
    for account_id, acct in accounts.items():
        owner = next(u for u in users if u["user_id"] == acct["owner_user_id"])
        if not owner["activated"]:
            continue

        # Trial: 35% of activated account owners start a trial
        if rng.random() >= ACTIVATE_TO_TRIAL:
            continue

        trial_start_date = owner["activation_date"] + timedelta(days=rint(1, 10))
        if trial_start_date > END_DATE:
            continue

        trial_start = random_time_on_day(trial_start_date)

        sub_id = f"sub_{uuid4()[:12]}"
        lifecycle = []
        current_plan = "pro" if rng.random() < 0.3 else "starter"
        billing_cycle = "monthly" if rng.random() < 0.75 else "annual"

        # Trial start
        lifecycle.append({
            "event_type": "trial_start",
            "event_time": trial_start,
            "plan": current_plan,
            "previous_plan": None,
            "billing_cycle": billing_cycle,
            "mrr_amount": 0,
            "cancel_reason": None,
            "is_voluntary": None,
        })

        trial_end = trial_start + timedelta(days=14)

        # Trial end → conversion?
        if trial_end <= END_DATETIME:
            converts = rng.random() < TRIAL_TO_PAID
            lifecycle.append({
                "event_type": "trial_end",
                "event_time": trial_end,
                "plan": current_plan if converts else "free",
                "previous_plan": current_plan,
                "billing_cycle": billing_cycle,
                "mrr_amount": 0,
                "cancel_reason": None if converts else "trial_expired",
                "is_voluntary": None if converts else True,
            })

            if converts:
                # Subscription start
                sub_start_time = trial_end + timedelta(hours=1)
                mrr = get_plan_price(current_plan, sub_start_time)
                if billing_cycle == "annual":
                    mrr = round(mrr * ANNUAL_DISCOUNT, 2)
                lifecycle.append({
                    "event_type": "subscription_start",
                    "event_time": trial_end + timedelta(hours=1),
                    "plan": current_plan,
                    "previous_plan": None,
                    "billing_cycle": billing_cycle,
                    "mrr_amount": mrr,
                    "cancel_reason": None,
                    "is_voluntary": None,
                })

                # Simulate monthly lifecycle events
                owner["subscribed"] = True
                owner["plan"] = current_plan
                owner["billing_cycle"] = billing_cycle

                first_step = 365 if billing_cycle == "annual" else 30
                current_time = trial_end + timedelta(days=first_step)
                active = True
                churned_time = None

                while current_time <= END_DATETIME and active:
                    roll = rng.random()

                    if roll < MONTHLY_CHURN_RATE:
                        # Churn
                        voluntary = rng.random() < 0.70
                        reasons = (["too_expensive", "not_using", "switched_competitor",
                                   "missing_features"]
                                  if voluntary else ["payment_failed", "card_expired"])
                        lifecycle.append({
                            "event_type": "cancellation",
                            "event_time": current_time,
                            "plan": "free",
                            "previous_plan": current_plan,
                            "billing_cycle": billing_cycle,
                            "mrr_amount": 0,
                            "cancel_reason": rng.choice(reasons),
                            "is_voluntary": voluntary,
                        })
                        active = False
                        churned_time = current_time

                    elif roll < MONTHLY_CHURN_RATE + MONTHLY_UPGRADE_RATE:
                        # Upgrade
                        plan_idx = PLAN_LIST.index(current_plan)
                        if plan_idx < len(PLAN_LIST) - 1:
                            new_plan = PLAN_LIST[plan_idx + 1]
                            new_mrr = get_plan_price(new_plan, current_time)
                            if billing_cycle == "annual":
                                new_mrr = round(new_mrr * ANNUAL_DISCOUNT, 2)
                            lifecycle.append({
                                "event_type": "upgrade",
                                "event_time": current_time,
                                "plan": new_plan,
                                "previous_plan": current_plan,
                                "billing_cycle": billing_cycle,
                                "mrr_amount": new_mrr,
                                "cancel_reason": None,
                                "is_voluntary": None,
                            })
                            current_plan = new_plan
                            owner["plan"] = current_plan

                    elif roll < MONTHLY_CHURN_RATE + MONTHLY_UPGRADE_RATE + MONTHLY_DOWNGRADE_RATE:
                        # Downgrade
                        plan_idx = PLAN_LIST.index(current_plan)
                        if plan_idx > 0:
                            new_plan = PLAN_LIST[plan_idx - 1]
                            new_mrr = get_plan_price(new_plan, current_time)
                            if billing_cycle == "annual":
                                new_mrr = round(new_mrr * ANNUAL_DISCOUNT, 2)
                            lifecycle.append({
                                "event_type": "downgrade",
                                "event_time": current_time,
                                "plan": new_plan,
                                "previous_plan": current_plan,
                                "billing_cycle": billing_cycle,
                                "mrr_amount": new_mrr,
                                "cancel_reason": None,
                                "is_voluntary": None,
                            })
                            current_plan = new_plan
                            owner["plan"] = current_plan
                    else:
                        # Renewal event for annual plans at anniversary
                        if billing_cycle == "annual":
                            mrr = get_plan_price(current_plan, current_time)
                            mrr = round(mrr * ANNUAL_DISCOUNT, 2)
                            lifecycle.append({
                                "event_type": "renewal",
                                "event_time": current_time,
                                "plan": current_plan,
                                "previous_plan": current_plan,
                                "billing_cycle": billing_cycle,
                                "mrr_amount": mrr,
                                "cancel_reason": None,
                                "is_voluntary": None,
                            })

                    # Step matches billing cycle
                    if billing_cycle == "annual":
                        current_time += timedelta(days=365)
                    else:
                        current_time += timedelta(days=30)

                # Reactivation for churned accounts
                churned_date = (churned_time.date() if isinstance(churned_time, datetime)
                               else churned_time) if churned_time else None
                if churned_date and (END_DATE - churned_date).days > 30:
                    if rng.random() < REACTIVATION_RATE:
                        reactivate_delay = rint(14, 90)
                        reactivate_time = churned_time + timedelta(days=int(reactivate_delay))
                        if reactivate_time <= END_DATETIME:
                            reactivate_plan = current_plan if current_plan != "free" else "starter"
                            mrr = get_plan_price(reactivate_plan, reactivate_time)
                            if billing_cycle == "annual":
                                mrr = round(mrr * ANNUAL_DISCOUNT, 2)
                            lifecycle.append({
                                "event_type": "reactivation",
                                "event_time": reactivate_time,
                                "plan": reactivate_plan,
                                "previous_plan": "free",
                                "billing_cycle": billing_cycle,
                                "mrr_amount": mrr,
                                "cancel_reason": None,
                                "is_voluntary": None,
                            })

        owner["trialed"] = True

        # ~12% of accounts are EUR-billed (European customers)
        currency = "EUR" if rng.random() < 0.12 else "USD"
        eur_rate = round(rng.uniform(0.88, 0.95), 4) if currency == "EUR" else 1.0

        account_subs[account_id] = {
            "subscription_id": sub_id,
            "owner_user_id": owner["user_id"],
            "lifecycle": lifecycle,
            "currency": currency,
            "eur_rate": eur_rate,
        }

    print(f"  {len(account_subs):,} accounts with subscription activity")
    return account_subs


# ── Phase 2: Event Generation ──────────────────────────────────────────────

def get_experiment_enrollments(signup_date):
    """Determine which experiments a user is enrolled in.

    A user is eligible if they signed up before the experiment ends (existing
    users can enter later experiments). Flags are only emitted on events that
    fall within the experiment's active window.

    Returns dict mapping exp_id -> {variant, start, end}.
    """
    enrollments = {}
    for exp_id, _, start_offset, duration, traffic_pct in EXPERIMENTS:
        exp_start = START_DATE + timedelta(days=start_offset)
        exp_end = exp_start + timedelta(days=duration)
        # User must exist (signed up) before experiment ends
        if signup_date <= exp_end:
            if rng.random() < traffic_pct:
                variant = "treatment" if rng.random() < 0.5 else "control"
                enrollments[exp_id] = {
                    "variant": variant,
                    "start": exp_start,
                    "end": exp_end,
                }
    return enrollments


def make_event(user, event_type, event_time, properties=None,
               include_user_id=True, experiments=None, plan_context=None):
    """Create a single event dict matching the source contract."""
    ingest_time, loaded_at = add_ingest_delay(event_time)

    # Filter experiment flags to those active on this event's date
    active_flags = None
    if experiments:
        event_d = event_time.date() if isinstance(event_time, datetime) else event_time
        active = [{"experiment_id": eid, "variant": info["variant"]}
                  for eid, info in experiments.items()
                  if info["start"] <= event_d <= info["end"]]
        active_flags = active if active else None

    event = {
        "event_id": uuid4(),
        "event_time": event_time,
        "ingest_time": ingest_time,
        "_loaded_at": loaded_at,
        "event_date": event_time.date(),
        "event_type": event_type,
        "user_id": user["user_id"] if include_user_id else None,
        "anon_id": user["anon_id"],
        "account_id": user.get("account_id"),
        "platform": user["platform"],
        "channel": user["channel"],
        "plan_context": plan_context if plan_context is not None else "free",
        "utm_source": user.get("utm_source"),
        "utm_medium": user.get("utm_medium"),
        "utm_campaign": user.get("utm_campaign"),
        "utm_term": None,
        "utm_content": None,
        "device_type": user["device_type"],
        "browser": user["browser"],
        "os": user["os"],
        "user_agent": user.get("user_agent"),
        "experiment_flags": active_flags,
        "properties": json.dumps(properties) if properties else None,
    }
    return event


def _build_plan_timeline(user, account_subs):
    """Build chronological plan transitions for a user's account."""
    transitions = []  # list of (datetime, plan)
    if user["account_id"] and user["account_id"] in account_subs:
        sub = account_subs[user["account_id"]]
        for evt in sub["lifecycle"]:
            et = evt["event_time"]
            evt_date = et.date() if isinstance(et, datetime) else et
            if evt["event_type"] in ("subscription_start", "upgrade",
                                     "downgrade", "reactivation"):
                transitions.append((evt_date, evt["plan"]))
            elif evt["event_type"] == "cancellation":
                transitions.append((evt_date, "free"))
    transitions.sort(key=lambda x: x[0])
    return transitions


def _get_plan_at(transitions, d):
    """Look up the active plan at a given date."""
    plan = "free"
    for trans_date, trans_plan in transitions:
        if trans_date <= d:
            plan = trans_plan
        else:
            break
    return plan


def generate_user_events(user, account_subs):
    """Generate all events for a single user's journey."""
    events = []
    signup_date = user["signup_date"]
    signup_dt = random_time_on_day(signup_date)
    experiments = get_experiment_enrollments(signup_date)
    plan_timeline = _build_plan_timeline(user, account_subs)

    # ── Pre-signup anonymous browsing (1-10 days before) ──
    # No experiment flags or user_id for pre-auth events
    n_presignup_days = rint(1, 8)
    for day_offset in range(n_presignup_days, 0, -1):
        browse_date = signup_date - timedelta(days=day_offset)
        if browse_date < START_DATE:
            continue
        n_pages = rint(1, 5)
        for _ in range(n_pages):
            t = random_time_on_day(browse_date)
            props = {
                "page_url": PAGES[rint(0, len(PAGES))],
                "referrer": REFERRERS[rint(0, len(REFERRERS))],
            }
            events.append(make_event(user, "page_view", t, props,
                                    include_user_id=False))

    # ── Signup ──
    props = {"signup_method": user["signup_method"]}
    events.append(make_event(user, "signup", signup_dt, props,
                            experiments=experiments))

    # If not activated, generate a few more page views and stop
    if not user["activated"]:
        n_post = rint(1, 8)
        for i in range(n_post):
            if user.get("is_bot"):
                # Bots: rapid-fire page views seconds apart
                t = signup_dt + timedelta(seconds=rint(1, 30) * (i + 1))
            else:
                t = signup_dt + timedelta(hours=rint(1, 72))
            if t.date() > END_DATE:
                break
            props = {"page_url": PAGES[rint(0, len(PAGES))], "referrer": None}
            events.append(make_event(user, "page_view", t, props,
                                    experiments=experiments))
        return events

    # ── Activation ──
    activation_date = user["activation_date"]
    if activation_date == signup_date:
        # Same-day activation: ensure activation happens after signup
        activation_dt = signup_dt + timedelta(minutes=rint(10, 120))
    else:
        activation_dt = random_time_on_day(activation_date)
    # Some page views between signup and activation
    days_to_activate = (activation_date - signup_date).days
    for d in range(1, min(days_to_activate + 1, 8)):
        browse_date = signup_date + timedelta(days=d)
        if browse_date >= activation_date:
            break
        n_pages = rint(1, 4)
        for _ in range(n_pages):
            t = random_time_on_day(browse_date)
            props = {"page_url": PAGES[rint(0, len(PAGES))], "referrer": None}
            events.append(make_event(user, "page_view", t, props,
                                    experiments=experiments))

    ttv_hours = round((activation_dt - signup_dt).total_seconds() / 3600, 1)
    activation_actions = ["complete_onboarding", "create_first_report",
                         "invite_teammate", "connect_datasource"]
    props = {
        "activation_action": activation_actions[rint(0, len(activation_actions))],
        "time_to_activate_hours": ttv_hours,
    }
    events.append(make_event(user, "activation", activation_dt, props,
                            experiments=experiments))

    # ── Account join ──
    if user["account_join_date"]:
        if user["account_join_date"] == activation_date:
            # Same-day join: ensure join happens after activation
            join_dt = activation_dt + timedelta(minutes=rint(5, 60))
        else:
            join_dt = random_time_on_day(user["account_join_date"])
        props = {"role": user["account_role"]}
        events.append(make_event(user, "member_joined", join_dt, props,
                                experiments=experiments))

        # Owners may invite others
        if user["account_role"] == "owner" and rng.random() < 0.3:
            invite_dt = join_dt + timedelta(hours=rint(1, 48))
            if invite_dt.date() <= END_DATE:
                props = {
                    "invited_email": f"invited_{uuid4()[:6]}@example.com",
                    "invited_role": "member",
                }
                events.append(make_event(user, "member_invited", invite_dt, props,
                                        experiments=experiments))

        # Some members get removed (~5% of non-owner members)
        if user["account_role"] == "member" and rng.random() < 0.05:
            remove_delay = rint(30, 180)
            remove_dt = join_dt + timedelta(days=remove_delay)
            if remove_dt.date() <= END_DATE:
                reasons = ["left_company", "role_change", "inactive", "license_reclaim"]
                props = {"reason": reasons[rint(0, len(reasons))]}
                events.append(make_event(user, "member_removed", remove_dt, props,
                                        experiments=experiments))

    # ── Ongoing activity (post-activation until END_DATE) ──
    will_churn = False
    churn_date = None

    if user["account_id"] and user["account_id"] in account_subs:
        sub_info = account_subs[user["account_id"]]
        for event in sub_info["lifecycle"]:
            if event["event_type"] == "cancellation":
                will_churn = True
                churn_date = event["event_time"].date() if isinstance(
                    event["event_time"], datetime) else event["event_time"]
                break

    # Base session rates by plan tier (determined per-day below)
    session_rates = {"free": rng.uniform(0.5, 2.0), "starter": rng.uniform(2, 5),
                     "pro": rng.uniform(4, 7), "enterprise": rng.uniform(5, 8)}

    current_date = activation_date + timedelta(days=1)
    while current_date <= END_DATE:
        # Plan at this point in time — drives engagement
        current_plan = _get_plan_at(plan_timeline, current_date)
        base_sessions_per_week = session_rates.get(current_plan, session_rates["free"])

        # Engagement decay for churning users
        activity_multiplier = 1.0
        if will_churn and churn_date:
            days_to_churn = (churn_date - current_date).days
            if days_to_churn < 0:
                activity_multiplier = 0.05  # minimal post-churn
            elif days_to_churn < 30:
                activity_multiplier = 0.2 + 0.8 * (days_to_churn / 30)

        # General engagement decay over time (dormancy for free users)
        days_active = (current_date - activation_date).days
        if days_active > 90 and current_plan == "free":
            activity_multiplier *= max(0.1, 1.0 - (days_active - 90) / 180)

        # Determine if user has a session today
        daily_session_prob = (base_sessions_per_week * activity_multiplier) / 7
        # Weekend reduction
        if current_date.weekday() >= 5:
            daily_session_prob *= 0.4

        if rng.random() < daily_session_prob:
            # Generate a session
            session_start = random_time_on_day(current_date)
            n_events = max(1, int(rng.exponential(scale=4)) + 1)
            n_events = min(n_events, 20)

            # Accumulate session offset to keep events within a realistic session
            session_offset = 0
            for i in range(n_events):
                gap = rint(1, 6)  # 1-5 min between events
                session_offset += gap
                if session_offset > 45:  # cap session at 45 min
                    break
                event_time = session_start + timedelta(minutes=session_offset)
                if event_time.date() > END_DATE:
                    break

                # Event type distribution within a session
                roll = rng.random()
                if roll < 0.45:
                    # page_view
                    props = {"page_url": PAGES[rint(0, len(PAGES))], "referrer": None}
                    events.append(make_event(user, "page_view", event_time, props,
                                            experiments=experiments,
                                            plan_context=current_plan))
                elif roll < 0.85:
                    # feature_use
                    props = {
                        "feature_name": FEATURES[rint(0, len(FEATURES))],
                        "duration_seconds": max(1, int(rng.exponential(scale=120))),
                    }
                    events.append(make_event(user, "feature_use", event_time, props,
                                            experiments=experiments,
                                            plan_context=current_plan))
                elif roll < 0.92:
                    # paywall_view (only if not enterprise)
                    if current_plan != "enterprise":
                        source_pages = ["/pricing", "/billing", "/features", "/settings"]
                        props = {
                            "source_page": source_pages[rint(0, len(source_pages))],
                            "plans_shown": PLAN_LIST,
                        }
                        events.append(make_event(user, "paywall_view", event_time, props,
                                                experiments=experiments,
                                                plan_context=current_plan))
                elif roll < 0.96:
                    # checkout_start (only before subscription or upgrade)
                    if current_plan in ("free", "starter", "pro"):
                        target = "starter" if current_plan == "free" else (
                            "pro" if current_plan == "starter" else "enterprise")
                        props = {
                            "target_plan": target,
                            "billing_cycle": "monthly" if rng.random() < 0.75 else "annual",
                        }
                        events.append(make_event(user, "checkout_start", event_time, props,
                                                experiments=experiments,
                                                plan_context=current_plan))
                else:
                    # upgrade_click (available for free through pro)
                    if current_plan != "enterprise":
                        if current_plan == "free":
                            target = "starter"
                        elif current_plan in PLAN_LIST:
                            idx = PLAN_LIST.index(current_plan)
                            target = PLAN_LIST[min(idx + 1, len(PLAN_LIST) - 1)]
                        else:
                            target = "starter"
                        props = {
                            "current_plan": current_plan,
                            "target_plan": target,
                        }
                        events.append(make_event(user, "upgrade_click", event_time, props,
                                                experiments=experiments,
                                                plan_context=current_plan))

        current_date += timedelta(days=1)

    return events


def generate_all_events(users, account_subs, batch_size=5000):
    """Generate events for all users, yielding DataFrames in batches."""
    print("Generating events...")
    all_events = []
    total = 0
    batches = []

    for i, user in enumerate(users):
        user_events = generate_user_events(user, account_subs)
        all_events.extend(user_events)

        if (i + 1) % batch_size == 0:
            print(f"  Users processed: {i+1:,}/{len(users):,} "
                  f"(events so far: {total + len(all_events):,})")

        if len(all_events) >= 250_000:
            df = pd.DataFrame(all_events)
            total += len(df)
            batches.append(df)
            all_events = []

    if all_events:
        df = pd.DataFrame(all_events)
        total += len(df)
        batches.append(df)

    # Add ~0.5% duplicate events for dedup testing
    print(f"  Total events: {total:,}")
    print("  Adding duplicate events for dedup testing...")
    dupe_batches = []
    for batch in batches:
        n_dupes = max(1, len(batch) // 200)
        dupe_indices = rng.choice(len(batch), size=n_dupes, replace=False)
        dupes = batch.iloc[dupe_indices].copy()
        # Same event_id, slightly different ingest/loaded times
        for idx in dupes.index:
            orig_time = dupes.at[idx, "ingest_time"]
            if isinstance(orig_time, datetime):
                dupes.at[idx, "ingest_time"] = orig_time + timedelta(seconds=rint(60, 3600))
                dupes.at[idx, "_loaded_at"] = dupes.at[idx, "ingest_time"] + timedelta(seconds=5)
        dupe_batches.append(dupes)
    batches.extend(dupe_batches)

    total_with_dupes = sum(len(b) for b in batches)
    print(f"  Total with duplicates: {total_with_dupes:,}")
    return batches


# ── Phase 3: Billing Data ─────────────────────────────────────────────────

def build_subscriptions_df(account_subs, accounts):
    """Build raw_billing.subscriptions DataFrame."""
    print("Building subscriptions table...")
    rows = []
    for account_id, sub_info in account_subs.items():
        sub_id = sub_info["subscription_id"]
        owner_id = sub_info["owner_user_id"]
        currency = sub_info["currency"]
        eur_rate = sub_info["eur_rate"]

        for event in sub_info["lifecycle"]:
            event_time = event["event_time"]
            if isinstance(event_time, date) and not isinstance(event_time, datetime):
                event_time = datetime.combine(event_time, datetime.min.time(),
                                             tzinfo=timezone.utc)
            ingest_time = event_time + timedelta(seconds=rint(1, 30))
            loaded_at = ingest_time + timedelta(seconds=rint(1, 10))

            mrr = event["mrr_amount"]
            if currency == "EUR" and mrr > 0:
                mrr = round(mrr * eur_rate, 2)

            rows.append({
                "subscription_event_id": uuid4(),
                "subscription_id": sub_id,
                "user_id": owner_id,
                "account_id": account_id,
                "event_type": event["event_type"],
                "event_time": event_time,
                "_loaded_at": loaded_at,
                "plan": event["plan"],
                "previous_plan": event["previous_plan"],
                "billing_cycle": event["billing_cycle"],
                "mrr_amount": mrr,
                "currency": currency,
                "cancel_reason": event["cancel_reason"],
                "is_voluntary": event["is_voluntary"],
            })

    df = pd.DataFrame(rows)
    print(f"  {len(df):,} subscription events")
    return df


def build_invoices_df(account_subs):
    """Build raw_billing.invoices DataFrame from subscription lifecycle.

    Walks forward through lifecycle events, generating invoices for each
    active paid period. Handles cancel→reactivate correctly.
    """
    print("Building invoices table...")
    rows = []
    end_dt = END_DATETIME

    for account_id, sub_info in account_subs.items():
        sub_id = sub_info["subscription_id"]
        owner_id = sub_info["owner_user_id"]
        lifecycle = sub_info["lifecycle"]
        currency = sub_info["currency"]
        eur_rate = sub_info["eur_rate"]

        # Build ordered list of paid periods: [(start, end, plan, billing_cycle)]
        paid_periods = []
        active_start = None
        current_plan = None
        billing_cycle = "monthly"

        for event in lifecycle:
            et = event["event_time"]
            if isinstance(et, date) and not isinstance(et, datetime):
                et = datetime.combine(et, datetime.min.time(), tzinfo=timezone.utc)

            if event["event_type"] == "subscription_start":
                active_start = et
                current_plan = event["plan"]
                billing_cycle = event["billing_cycle"]
            elif event["event_type"] in ("upgrade", "downgrade"):
                current_plan = event["plan"]
            elif event["event_type"] == "cancellation":
                if active_start:
                    paid_periods.append((active_start, et, current_plan, billing_cycle))
                active_start = None
            elif event["event_type"] == "reactivation":
                active_start = et
                current_plan = event["plan"]

        # Still-active subscription: period runs to END_DATE
        if active_start:
            paid_periods.append((active_start, end_dt, current_plan, billing_cycle))

        # Generate invoices for each paid period
        for period_start, period_end, plan, cycle in paid_periods:
            invoice_date = period_start

            # Walk through lifecycle to track plan changes within this period
            while invoice_date <= min(period_end, end_dt):
                # Find effective plan at this invoice date
                effective_plan = plan
                for event in lifecycle:
                    et = event["event_time"]
                    if isinstance(et, date) and not isinstance(et, datetime):
                        et = datetime.combine(et, datetime.min.time(),
                                             tzinfo=timezone.utc)
                    if et <= invoice_date:
                        if event["event_type"] in ("subscription_start", "upgrade",
                                                   "downgrade", "reactivation"):
                            effective_plan = event["plan"]

                # Invoice amount (respects price change date and currency)
                plan_price = get_plan_price(effective_plan, invoice_date)
                if cycle == "annual":
                    amount = round(plan_price * 12 * ANNUAL_DISCOUNT, 2)
                else:
                    amount = round(float(plan_price), 2)
                if currency == "EUR":
                    amount = round(amount * eur_rate, 2)

                # Payment status
                status_roll = rng.random()
                if status_roll < 0.92:
                    status = "paid"
                    paid_at = invoice_date + timedelta(hours=rint(0, 24))
                elif status_roll < 0.96:
                    status = "pending"
                    paid_at = None
                elif status_roll < 0.99:
                    status = "failed"
                    paid_at = None
                else:
                    status = "refunded"
                    paid_at = invoice_date + timedelta(hours=rint(0, 24))

                refund_amount = (round(amount * rng.uniform(0.3, 1.0), 2)
                                if status == "refunded" else 0)

                line_items = json.dumps([{
                    "description": f"{effective_plan.title()} Plan - "
                                  f"{'Annual' if cycle == 'annual' else 'Monthly'}",
                    "amount": amount,
                    "quantity": 1,
                }])

                loaded_at = invoice_date + timedelta(seconds=rint(1, 60))

                rows.append({
                    "invoice_id": uuid4(),
                    "subscription_id": sub_id,
                    "user_id": owner_id,
                    "account_id": account_id,
                    "issued_at": invoice_date,
                    "paid_at": paid_at,
                    "_loaded_at": loaded_at,
                    "amount": amount,
                    "currency": currency,
                    "status": status,
                    "refund_amount": refund_amount,
                    "line_items": line_items,
                })

                if cycle == "annual":
                    invoice_date += timedelta(days=365)
                else:
                    invoice_date += timedelta(days=30)

    df = pd.DataFrame(rows)
    print(f"  {len(df):,} invoices")
    return df


# ── Phase 4: Marketing Spend ──────────────────────────────────────────────

def build_marketing_spend_df():
    """Build raw_marketing.spend DataFrame — daily spend per channel × campaign."""
    print("Building marketing spend table...")
    rows = []

    for current_date in date_range(START_DATE, END_DATE):
        for channel, campaign_list in CAMPAIGNS.items():
            for campaign_id, campaign_name in campaign_list:
                # Base spend with growth over time and day-of-week variation
                day_idx = (current_date - START_DATE).days
                growth = 1.0 + 0.5 * (day_idx / NUM_DAYS)
                weekend_mult = 0.6 if current_date.weekday() >= 5 else 1.0

                if channel == "paid_search":
                    base_spend = rng.uniform(80, 250)
                elif channel == "paid_social":
                    base_spend = rng.uniform(50, 180)
                else:  # email
                    base_spend = rng.uniform(10, 40)

                spend = round(base_spend * growth * weekend_mult * rng.uniform(0.7, 1.3), 2)
                impressions = int(spend * rng.uniform(80, 200))
                clicks = int(impressions * rng.uniform(0.01, 0.05))

                loaded_at = datetime.combine(current_date + timedelta(days=1),
                                            datetime.min.time(), tzinfo=timezone.utc)
                loaded_at += timedelta(hours=rint(2, 8))

                rows.append({
                    "spend_id": uuid4(),
                    "date": current_date,
                    "channel": channel,
                    "campaign_id": campaign_id,
                    "campaign_name": campaign_name,
                    "impressions": impressions,
                    "clicks": clicks,
                    "spend_amount": spend,
                    "currency": "USD",
                    "_loaded_at": loaded_at,
                })

    df = pd.DataFrame(rows)
    print(f"  {len(df):,} spend rows")
    return df


# ── Phase 5: Support Tickets ──────────────────────────────────────────────

def build_support_tickets_df(users, accounts, account_subs):
    """Build raw_support.tickets DataFrame."""
    print("Building support tickets table...")
    rows = []

    # Only users with accounts generate tickets
    users_with_accounts = [u for u in users if u["account_id"]]

    for user in users_with_accounts:
        account_id = user["account_id"]
        join_date = user.get("account_join_date") or user["signup_date"]

        # Ticket rate: higher for churning accounts, lower for happy ones
        is_churning = False
        if account_id in account_subs:
            for event in account_subs[account_id]["lifecycle"]:
                if event["event_type"] == "cancellation":
                    is_churning = True
                    break

        # Base: ~0.3 tickets per user per month; churning: 2x
        monthly_rate = 0.3 * (2.0 if is_churning else 1.0)
        months_active = max(1, (END_DATE - join_date).days / 30)
        n_tickets = rng.poisson(lam=monthly_rate * months_active)
        n_tickets = min(n_tickets, 20)  # cap

        for _ in range(n_tickets):
            days_offset = rint(0, max(1, (END_DATE - join_date).days))
            created_date = join_date + timedelta(days=int(days_offset))
            if created_date > END_DATE:
                continue

            created_at = random_time_on_day(created_date)

            category = weighted_choice(TICKET_CATEGORIES)
            priority = weighted_choice(TICKET_PRIORITIES)

            # Resolution: most tickets get resolved
            if rng.random() < 0.85:
                resolution_hours = {
                    "critical": rng.exponential(scale=4),
                    "high": rng.exponential(scale=12),
                    "medium": rng.exponential(scale=36),
                    "low": rng.exponential(scale=72),
                }[priority]
                resolution_hours = max(0.5, min(resolution_hours, 336))  # cap at 2 weeks
                resolved_at = created_at + timedelta(hours=resolution_hours)
                if resolved_at.date() > END_DATE:
                    resolved_at = None
                    status = rng.choice(["open", "in_progress"])
                else:
                    status = rng.choice(["resolved", "closed"])
            else:
                resolved_at = None
                status = rng.choice(["open", "in_progress"])

            # First response time
            first_response_seconds = None
            if status in ("resolved", "closed", "in_progress"):
                resp_hours = max(0.1, rng.exponential(scale=2))
                first_response_seconds = int(resp_hours * 3600)

            # CSAT score (only on resolved/closed)
            csat_score = None
            if status in ("resolved", "closed") and rng.random() < 0.60:
                if is_churning:
                    csat_score = int(rng.choice([1, 2, 3, 4, 5], p=[0.20, 0.30, 0.25, 0.15, 0.10]))
                else:
                    csat_score = int(rng.choice([1, 2, 3, 4, 5], p=[0.03, 0.07, 0.15, 0.35, 0.40]))

            loaded_at = created_at + timedelta(seconds=rint(1, 30))

            rows.append({
                "ticket_id": uuid4(),
                "user_id": user["user_id"],
                "account_id": account_id,
                "created_at": created_at,
                "resolved_at": resolved_at,
                "_loaded_at": loaded_at,
                "category": category,
                "priority": priority,
                "status": status,
                "csat_score": csat_score,
                "first_response_seconds": first_response_seconds,
            })

    df = pd.DataFrame(rows)
    print(f"  {len(df):,} support tickets")
    return df


# ── BigQuery Upload ────────────────────────────────────────────────────────

EVENTS_SCHEMA = [
    bigquery.SchemaField("event_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("event_time", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("ingest_time", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("event_date", "DATE", mode="REQUIRED"),
    bigquery.SchemaField("event_type", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("user_id", "STRING"),
    bigquery.SchemaField("anon_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("account_id", "STRING"),
    bigquery.SchemaField("platform", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("channel", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("plan_context", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("utm_source", "STRING"),
    bigquery.SchemaField("utm_medium", "STRING"),
    bigquery.SchemaField("utm_campaign", "STRING"),
    bigquery.SchemaField("utm_term", "STRING"),
    bigquery.SchemaField("utm_content", "STRING"),
    bigquery.SchemaField("device_type", "STRING"),
    bigquery.SchemaField("browser", "STRING"),
    bigquery.SchemaField("os", "STRING"),
    bigquery.SchemaField("user_agent", "STRING"),
    bigquery.SchemaField("experiment_flags", "JSON"),
    bigquery.SchemaField("properties", "JSON"),
]

SUBSCRIPTIONS_SCHEMA = [
    bigquery.SchemaField("subscription_event_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("subscription_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("user_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("account_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("event_type", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("event_time", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("plan", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("previous_plan", "STRING"),
    bigquery.SchemaField("billing_cycle", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("mrr_amount", "NUMERIC", mode="REQUIRED"),
    bigquery.SchemaField("currency", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("cancel_reason", "STRING"),
    bigquery.SchemaField("is_voluntary", "BOOLEAN"),
]

INVOICES_SCHEMA = [
    bigquery.SchemaField("invoice_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("subscription_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("user_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("account_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("issued_at", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("paid_at", "TIMESTAMP"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("amount", "NUMERIC", mode="REQUIRED"),
    bigquery.SchemaField("currency", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("status", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("refund_amount", "NUMERIC", mode="REQUIRED"),
    bigquery.SchemaField("line_items", "JSON"),
]

SPEND_SCHEMA = [
    bigquery.SchemaField("spend_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("date", "DATE", mode="REQUIRED"),
    bigquery.SchemaField("channel", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("campaign_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("campaign_name", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("impressions", "INT64", mode="REQUIRED"),
    bigquery.SchemaField("clicks", "INT64", mode="REQUIRED"),
    bigquery.SchemaField("spend_amount", "NUMERIC", mode="REQUIRED"),
    bigquery.SchemaField("currency", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP", mode="REQUIRED"),
]

TICKETS_SCHEMA = [
    bigquery.SchemaField("ticket_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("user_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("account_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("created_at", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("resolved_at", "TIMESTAMP"),
    bigquery.SchemaField("_loaded_at", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("category", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("priority", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("status", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("csat_score", "INT64"),
    bigquery.SchemaField("first_response_seconds", "INT64"),
]


def create_datasets(client):
    """Create raw source datasets if they don't exist."""
    datasets = ["raw_funnel", "raw_billing", "raw_marketing", "raw_support"]
    for ds_name in datasets:
        ds_ref = bigquery.DatasetReference(client.project, ds_name)
        ds = bigquery.Dataset(ds_ref)
        ds.location = "EU"
        try:
            client.create_dataset(ds, exists_ok=True)
            print(f"  Dataset {ds_name}: OK")
        except Exception as e:
            print(f"  Dataset {ds_name}: {e}")


def upload_table(client, dataset, table_name, df, schema,
                partition_field=None, cluster_fields=None,
                write_disposition="WRITE_TRUNCATE"):
    """Upload DataFrame to BigQuery table."""
    table_id = f"{client.project}.{dataset}.{table_name}"
    print(f"  Uploading {table_id} ({len(df):,} rows, {write_disposition})...")

    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=write_disposition,
    )

    if partition_field:
        job_config.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field=partition_field,
        )

    if cluster_fields:
        job_config.clustering_fields = cluster_fields

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # wait
    table = client.get_table(table_id)
    print(f"    Loaded {table.num_rows:,} rows")


def save_parquet(df, path):
    """Save DataFrame as parquet for dry-run mode."""
    df.to_parquet(path, index=False)
    size_mb = os.path.getsize(path) / (1024 * 1024)
    print(f"    Saved {path} ({size_mb:.1f} MB, {len(df):,} rows)")


# ── Main ───────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate synthetic analytics data")
    parser.add_argument("--project", default=os.environ.get("GCP_PROJECT_ID"),
                       help="GCP project ID (default: $GCP_PROJECT_ID)")
    parser.add_argument("--dry-run", action="store_true",
                       help="Save to local parquet files instead of BigQuery")
    parser.add_argument("--seed", type=int, default=SEED,
                       help="Random seed for reproducibility")
    parser.add_argument("--users", type=int, default=NUM_USERS,
                       help="Number of users to generate (default: 50000)")
    args = parser.parse_args()

    global rng
    rng = np.random.default_rng(args.seed)
    num_users = args.users

    print("=" * 60)
    print("Analytics-dbt Synthetic Data Generator")
    print("=" * 60)
    print(f"  Users: {num_users:,}")
    print(f"  Period: {START_DATE} to {END_DATE} ({NUM_DAYS} days)")
    print(f"  Seed: {args.seed}")
    print(f"  Mode: {'dry-run (parquet)' if args.dry_run else 'BigQuery upload'}")
    print()

    # Phase 1: Users and accounts
    users = generate_users(num_users)
    users = assign_journeys(users)
    accounts = generate_accounts(users)
    account_subs = simulate_subscriptions(users, accounts)
    print()

    # Phase 2: Events (streamed to disk/BQ to avoid OOM)
    event_batches = generate_all_events(users, account_subs)
    print()

    # Phase 3: Billing
    subs_df = build_subscriptions_df(account_subs, accounts)
    invoices_df = build_invoices_df(account_subs)
    print()

    # Phase 4: Marketing
    spend_df = build_marketing_spend_df()
    print()

    # Phase 5: Support
    tickets_df = build_support_tickets_df(users, accounts, account_subs)
    print()

    # Summary
    total_events = sum(len(b) for b in event_batches)
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    print(f"  Events:        {total_events:>10,} rows ({len(event_batches)} batches)")
    print(f"  Subscriptions: {len(subs_df):>10,} rows")
    print(f"  Invoices:      {len(invoices_df):>10,} rows")
    print(f"  Spend:         {len(spend_df):>10,} rows")
    print(f"  Tickets:       {len(tickets_df):>10,} rows")
    print()

    if args.dry_run:
        # Save to parquet — events in parts to avoid OOM
        out_dir = Path("scripts/synthetic_data")
        out_dir.mkdir(parents=True, exist_ok=True)
        print("Saving parquet files...")
        for i, batch in enumerate(event_batches):
            batch["experiment_flags"] = batch["experiment_flags"].apply(
                lambda x: json.dumps(x) if x else None
            )
            save_parquet(batch, out_dir / f"events_part{i:03d}.parquet")
        save_parquet(subs_df, out_dir / "subscriptions.parquet")
        save_parquet(invoices_df, out_dir / "invoices.parquet")
        save_parquet(spend_df, out_dir / "spend.parquet")
        save_parquet(tickets_df, out_dir / "tickets.parquet")
    else:
        # Upload to BigQuery
        if not args.project:
            # Try to get from gcloud config
            import subprocess
            result = subprocess.run(["gcloud", "config", "get-value", "project"],
                                   capture_output=True, text=True)
            args.project = result.stdout.strip()

        if not args.project:
            print("ERROR: No GCP project. Set --project or $GCP_PROJECT_ID")
            return 1

        print(f"Uploading to BigQuery (project: {args.project})...")
        client = bigquery.Client(project=args.project)

        print("Creating datasets...")
        create_datasets(client)
        print()

        print("Uploading tables...")
        # Events: upload in batches to avoid OOM
        for i, batch in enumerate(event_batches):
            batch["experiment_flags"] = batch["experiment_flags"].apply(
                lambda x: json.dumps(x) if x else None
            )
            disposition = "WRITE_TRUNCATE" if i == 0 else "WRITE_APPEND"
            upload_table(client, "raw_funnel", "events", batch,
                        EVENTS_SCHEMA, partition_field="event_date",
                        cluster_fields=["event_type", "platform"],
                        write_disposition=disposition)
        upload_table(client, "raw_billing", "subscriptions", subs_df,
                    SUBSCRIPTIONS_SCHEMA, partition_field="event_time",
                    cluster_fields=["account_id", "event_type"])
        upload_table(client, "raw_billing", "invoices", invoices_df,
                    INVOICES_SCHEMA, partition_field="issued_at",
                    cluster_fields=["account_id", "status"])
        upload_table(client, "raw_marketing", "spend", spend_df,
                    SPEND_SCHEMA, partition_field="date",
                    cluster_fields=["channel"])
        upload_table(client, "raw_support", "tickets", tickets_df,
                    TICKETS_SCHEMA, partition_field="created_at",
                    cluster_fields=["account_id", "category"])

    print()
    print("Done!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
