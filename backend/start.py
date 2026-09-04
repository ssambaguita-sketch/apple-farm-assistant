import app as base_app
import diagnosis  # registers /api/diagnosis/assess on main.app

app = base_app.app
app.version = "4.6.0"
