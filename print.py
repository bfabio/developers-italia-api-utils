#!/usr/bin/env python3

# import logging
import requests

# logging.basicConfig(level=logging.DEBUG)

API_BASEURL = 'https://api.developers.italia.it/v1'

software = []

page = True
page_after = ""

while page:
    res = requests.get(f"{API_BASEURL}/software{page_after}")
    res.raise_for_status()

    body = res.json()
    software += body['data']

    page_after = body['links']['next']
    page = bool(page_after)

for s in software:
    res = requests.get(f"{API_BASEURL}/software/{s['id']}/logs")
    res.raise_for_status()

    body = res.json()
    logs = body['data']

    if len(logs) > 0:
        print(f"{logs[0]['createdAt']}: {logs[0]['message']}")
    print()
