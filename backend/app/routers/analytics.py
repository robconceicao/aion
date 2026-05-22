from fastapi import APIRouter, Depends
from app.routers.auth import get_current_admin
from app.database import get_supabase

router = APIRouter()

@router.get("/dashboard")
async def get_dashboard_summary(admin: dict = Depends(get_current_admin)):
    supabase = get_supabase()
    total_users = 0
    total_dreams = 0
    
    try:
        res_users = supabase.table("users").select("*", count="exact").limit(1).execute()
        total_users = res_users.count or 0
    except Exception as e:
        print(f"Error counting users: {e}")
        
    try:
        res_dreams = supabase.table("dreams").select("*", count="exact").limit(1).execute()
        total_dreams = res_dreams.count or 0
    except Exception as e:
        print(f"Error counting dreams: {e}")
        
    return {
        "status": "online",
        "total_users": total_users,
        "total_dreams": total_dreams,
        "uptime": "active"
    }

@router.get("/stats/geo")
async def get_geo_stats(admin: dict = Depends(get_current_admin)):
    # Return empty list since analytics_events is a MongoDB collection not migrated to SQL
    return []

@router.get("/stats/daily")
async def get_daily_stats(admin: dict = Depends(get_current_admin)):
    # Return empty list since analytics_events is a MongoDB collection not migrated to SQL
    return []
