from fastapi import APIRouter, Depends
from app.routers.auth import get_current_admin
from app.database import get_database
from datetime import datetime, timedelta

router = APIRouter()

@router.get("/dashboard")
async def get_dashboard_summary(admin: dict = Depends(get_current_admin)):
    db = await get_database()
    total_users = await db.users.count_documents({})
    total_dreams = await db.dreams.count_documents({})
    
    return {
        "status": "online",
        "total_users": total_users,
        "total_dreams": total_dreams,
        "uptime": "active"
    }

@router.get("/stats/geo")
async def get_geo_stats(admin: dict = Depends(get_current_admin)):
    db = await get_database()
    pipeline = [
        {"$group": {"_id": "$location.country", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}}
    ]
    cursor = db.analytics_events.aggregate(pipeline)
    stats = await cursor.to_list(length=100)
    return stats

@router.get("/stats/daily")
async def get_daily_stats(admin: dict = Depends(get_current_admin)):
    db = await get_database()
    # Simplified daily dreams count
    pipeline = [
        {"$match": {"event_type": "dream_created"}},
        {"$group": {
            "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
            "count": {"$sum": 1}
        }},
        {"$sort": {"_id": -1}}
    ]
    cursor = db.analytics_events.aggregate(pipeline)
    return await cursor.to_list(length=30)
