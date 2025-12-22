import logging
import os

import requests
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


BACKEND_URL = os.getenv("BACKEND_URL", "http://backend:3000")
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN", "REPLACE_ME")


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "Send /price <make> <model> <year> <mileage> to get an estimate."
    )


async def price(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Very minimal parsing for MVP: /price BMW 320 2017 90000
    """
    try:
        _, make, model, year, mileage = update.message.text.split()
        telegram_user_id = str(update.effective_user.id)
    except ValueError:
        await update.message.reply_text(
            "Usage: /price <make> <model> <year> <mileage>"
        )
        return

    payload = {
        "telegram_user_id": telegram_user_id,
        "filters": {
            "make": make,
            "model": model,
            "model_year": int(year),
            "mileage_min": int(mileage),
            "mileage_max": int(mileage),
        },
    }

    resp = requests.post(f"{BACKEND_URL}/api/v1/price_estimates", json=payload, timeout=5)
    if resp.status_code >= 400:
        await update.message.reply_text("Failed to create price estimate request.")
        return

    data = resp.json()
    await update.message.reply_text(
        f"Request created with id {data['id']}. Use /status {data['id']} to check the result."
    )


async def status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    try:
        _, query_id = update.message.text.split()
        telegram_user_id = str(update.effective_user.id)
    except ValueError:
        await update.message.reply_text("Usage: /status <query_id>")
        return

    resp = requests.get(
        f"{BACKEND_URL}/api/v1/price_estimates/{query_id}",
        params={"telegram_user_id": telegram_user_id},
        timeout=5,
    )
    if resp.status_code >= 400:
        await update.message.reply_text("Query not found.")
        return

    data = resp.json()
    status_val = data.get("status")

    if status_val != "completed":
        await update.message.reply_text(f"Status: {status_val or 'pending'}")
        return

    pe = data.get("price_estimate") or {}
    avg = pe.get("avg_price")
    median = pe.get("median_price")
    currency = pe.get("currency", "USD")
    sample_size = pe.get("sample_size", 0)
    conf = pe.get("confidence_score", 0.0)

    lines = [
        f"Average price: {avg} {currency}",
        f"Median price: {median} {currency}",
        f"Sample size: {sample_size}, confidence: {conf:.2f}",
        "",
        "Similar vehicles:",
    ]

    for v in data.get("similar_vehicles", [])[:15]:
        lines.append(
            f"{v.get('provider')} | {v.get('mileage')} mi | {v.get('damage_type')} | "
            f"{v.get('location')} | est: {v.get('estimated_price')} | {v.get('auction_url')}"
        )

    await update.message.reply_text("\n".join(lines))


def main() -> None:
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("price", price))
    app.add_handler(CommandHandler("status", status))
    app.run_polling()


if __name__ == "__main__":
    main()






