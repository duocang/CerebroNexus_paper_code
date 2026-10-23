import sys, time
from playwright.sync_api import sync_playwright
url, out = sys.argv[1], sys.argv[2]
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome", headless=True)
    pg = b.new_context(viewport={"width":1600,"height":1000}).new_page()
    msgs=[]; pg.on("console", lambda m: msgs.append(m.type+": "+m.text[:200])); pg.on("requestfailed", lambda r: msgs.append("REQFAIL "+r.url[:120]))
    pg.goto(url); time.sleep(float(sys.argv[3]) if len(sys.argv)>3 else 15)
    pg.screenshot(path=out)
    print("\n".join(msgs[:15]))
    b.close()
