from fastapi import FastAPI, Query
from pydantic import BaseModel
import os, json, requests

app = FastAPI(title="SignalFind API")

OS_ENDPOINT = os.getenv("OS_ENDPOINT", "")
OS_INDEX    = os.getenv("OS_INDEX", "people")

class SearchResult(BaseModel):
    took: int
    hits: list

@app.get("/healthz")
def health():
    return {"ok": True}

@app.get("/search", response_model=SearchResult)
def search(q: str = Query(...), size: int = 10):
    # Minimal unauthenticated example; in prod use SigV4 + FGAC
    url = f"https://{OS_ENDPOINT}/{OS_INDEX}/_search"
    body = {
        "query": {"multi_match": {"query": q, "fields": ["name^2","title","company","skills","location"]}},
        "size": size
    }
    r = requests.get(url, headers={"Content-Type":"application/json"}, data=json.dumps(body), timeout=5)
    data = r.json()
    hits = [{"_id": h["_id"], **h["_source"]} for h in data.get("hits", {}).get("hits", [])]
    return {"took": data.get("took", 0), "hits": hits}
