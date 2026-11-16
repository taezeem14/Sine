import urllib.request
import json
import sys
import os
import time

def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else 'v1.3.2'
    if not tag.startswith('v'):
        tag = 'v' + tag

    api_url = f'https://api.github.com/repos/taezeem14/Sine/releases/tags/{tag}'
    req = urllib.request.Request(api_url, headers={'User-Agent': 'Sine-Release-Fetcher'})

    print(f"Checking GitHub Actions Cloud CI/CD release for tag: {tag}...")
    
    max_retries = 50
    delay = 12
    for attempt in range(1, max_retries + 1):
        try:
            with urllib.request.urlopen(req) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                else:
                    continue
                release_name = data.get('name', tag)
                assets = data.get('assets', [])
                
                apk_url = None
                apk_name = None
                for a in assets:
                    name = a.get('name', '')
                    if name.endswith('.apk'):
                        apk_url = a.get('browser_download_url')
                        apk_name = name
                        break

                if apk_url:
                    dest = os.path.join(os.getcwd(), f"Sine-{tag}.apk")
                    print(f"Found Cloud Release APK: {apk_name}")
                    print(f"Downloading from {apk_url} to {dest}...")
                    urllib.request.urlretrieve(apk_url, dest)
                    size_mb = os.path.getsize(dest) / (1024 * 1024)
                    print(f"[SUCCESS] Downloaded {dest} ({size_mb:.2f} MB)")
                    
                    # Also keep standard app-release.apk if needed
                    alt_dest = os.path.join(os.getcwd(), 'build', 'app', 'outputs', 'flutter-apk', f"Sine-{tag}.apk")
                    os.makedirs(os.path.dirname(alt_dest), exist_ok=True)
                    try:
                        import shutil
                        shutil.copy2(dest, alt_dest)
                    except Exception:
                        pass
                    return 0
                else:
                    print(f"[{attempt}/{max_retries}] Release {tag} is draft/created, but APK asset not uploaded yet. Retrying in {delay}s...")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                print(f"[{attempt}/{max_retries}] Release {tag} not published yet (Cloud CI/CD is currently compiling). Retrying in {delay}s...")
            else:
                print(f"HTTP Error {e.code}: {e.reason}")
        except Exception as e:
            print(f"Error: {e}")
        
        time.sleep(delay)

    print("Timed out waiting for GitHub Actions cloud release APK.")
    return 1

if __name__ == '__main__':
    sys.exit(main())
