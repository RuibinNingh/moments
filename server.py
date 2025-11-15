import os, json, time
from flask import Flask, request, jsonify, send_from_directory, render_template
from markdown import markdown
import yaml
app = Flask(__name__)

# ----------------------读取配置----------------------
with open("config.json", "r", encoding="utf-8") as f:
    config = json.load(f)
API_KEY = config.get("api_key", "")
VIEW_LIMIT = config.get("view_time_limit_days", 9999)
nickname = config.get("nickname", "")
avatar = config.get("avatar", "")


@app.route("/")
def index():
    return render_template("index.html",
                           nickname=nickname,
                           avatar=avatar
                           )


