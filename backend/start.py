import app as base_app
import diagnosis  # registers /api/diagnosis/assess on main.app
import annual_today  # injects annual flow into today's recommendations
import threat_titles  # makes threat types explicit in recommendation titles

app = base_app.app
app.version = "4.8.0"
