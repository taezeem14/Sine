import urllib.request
import json
import sys
import os

url = 'https://api.github.com/repos/taezeem14/Sine/releases/tags/v1.3.1'
req = urllib.request.Request(url, headers={'User-Agent': 'Sine-Release-Fetcher'})

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        name = data.get('name')
        assets = data.get('assets', [])
        print(f"Release: {name}")
        apk_url = None
        for a in assets:
            aname = a.get('name', '')
            asize = a.get('size', 0)
            adownload = a.get('browser_download_url', '')
            print(f"Asset: {aname} ({asize / 1024 / 1024:.2f} MB) -> {adownload}")
            if aname.endswith('.apk'):
                apk_url = adownload

        if apk_url:
            dest = os.path.join(os.getcwd(), 'Sine-v1.3.1.apk')
            print(f"Downloading {apk_url} to {dest}...")
            urllib.request.urlretrieve(apk_url, dest)
            print(f"Downloaded successfully! File size: {os.path.getsize(dest)} bytes")
        else:
            print("No APK asset found yet. Cloud CI might still be building...")
except urllib.error.HTTPError as e:
    if e.code == 404:
        print("Release v1.3.1 not published yet (GitHub Actions build may still be in progress).")
    else:
        print(f"HTTP Error {e.code}: {e.reason}")
except Exception as e:
    print(f"Error: {e}")
