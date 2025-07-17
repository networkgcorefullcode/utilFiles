import requests
import os

user = "networkgcorefullcode"  # Reemplaza con el nombre de usuario
url = f"https://api.github.com/users/{user}/repos?per_page=100"
repos = requests.get(url).json()

for repo in repos:
    os.system(f"git clone {repo['clone_url']}")