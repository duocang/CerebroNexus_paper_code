"""Stop the Task 3 runner and everything it started (psutil; matches only python processes running scripts/run/task3/run.py)."""
import psutil, os
me = os.getpid()
for p in psutil.process_iter(["pid", "name", "cmdline"]):
    try:
        cl = " ".join(p.info["cmdline"] or [])
        if p.info["pid"] != me and "task3" in cl and "run.py" in cl and "stop.py" not in cl and p.info["name"].lower().startswith("python"):
            kids = p.children(recursive=True)
            for c in kids + [p]:
                try: c.kill()
                except Exception: pass
            print("killed", p.info["pid"], "and", len(kids), "children")
    except Exception:
        pass
