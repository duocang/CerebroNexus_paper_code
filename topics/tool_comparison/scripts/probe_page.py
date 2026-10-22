import sys, time
from playwright.sync_api import sync_playwright
url, out = sys.argv[1], sys.argv[2]
wait = float(sys.argv[3]) if len(sys.argv) > 3 else 8
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome", headless=True)
    c = b.new_context(viewport={"width": 1600, "height": 1000}, device_scale_factor=1)
    pg = c.new_page(); pg.goto(url); time.sleep(wait)
    pg.screenshot(path=out)
    print(pg.evaluate("""() => [...document.querySelectorAll('canvas,svg,[id]')].filter(e=>{const r=e.getBoundingClientRect();return r.width>200&&r.height>200}).slice(0,25).map(e=>e.tagName+'#'+e.id+'.'+(e.className.baseVal??e.className)+' '+Math.round(e.getBoundingClientRect().width)+'x'+Math.round(e.getBoundingClientRect().height))"""))
    b.close()
