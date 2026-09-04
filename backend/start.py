import app as base_app
import diagnosis  # registers /api/diagnosis/assess on main.app
import annual_today  # injects annual flow into today's recommendations
import threat_titles  # makes broad threat types explicit in recommendation titles
import specific_threats  # refines broad threats into concrete seasonal scouting candidates with variety timing
import orchard_zones  # per-variety orchard zones and tree counts
import recommendation_zones  # targets recommendations to concrete orchard zones
import recommendation_diagnosis  # runs diagnosis pre-checks for recommendation candidates
import behavior_coach  # non-diagnostic behavioral screening and coaching
import orchard_management  # multi-orchard and multi-variety management
import weed_intelligence  # camera-assisted weed timing and history analysis

app = base_app.app
app.version = "5.5.0"
