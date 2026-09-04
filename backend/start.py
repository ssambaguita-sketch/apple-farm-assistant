import app as base_app
import diagnosis  # registers /api/diagnosis/assess on main.app
import annual_today  # injects annual flow into today's recommendations
import threat_titles  # makes broad threat types explicit in recommendation titles
import specific_threats  # refines broad threats into concrete seasonal scouting candidates

app = base_app.app
app.version = "4.9.0"
