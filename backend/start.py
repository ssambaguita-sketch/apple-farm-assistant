import app as base_app
import diagnosis  # registers /api/diagnosis/assess on main.app
import annual_today  # injects annual flow into today's recommendations

app = base_app.app
app.version = "4.7.0"
