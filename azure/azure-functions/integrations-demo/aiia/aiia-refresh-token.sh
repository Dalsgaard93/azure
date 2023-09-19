#!/bin/bash
curl -D- -X POST https://api-sandbox.aiia.eu/v1/oauth/token \
  -u 'aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81:6e6c150ebcb36f90e8cd5c750c8c0ca42a8751b7d63f0110a465115dff4dec86' \
  -H 'Content-Type: application/json'  \
  -d '{ 
        "grant_type" : "refresh_token", 
        "refresh_token" : "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIyMjZlOTY4OC01ZTgwLTRmMjEtYjY1NS02YWNhYTMxZjE4ZjEiLCJjbGllbnRJZCI6ImFpaWFwb2MtOTJjZDdjMjYtM2NhNi00MDRkLTliMWMtM2RlZTExYTE1YzgxIiwiY29uc2VudElkcyI6IjQyMGMwZGI2LWYxYWItNGFmNi04MGMyLTdlZmUzZTU0Njc0NiIsInJvbGUiOiJSZWZyZXNoVG9rZW4iLCJzZXNzaW9uSWQiOiJjZmNjMTAyZi03ODY4LTRkODEtODk3NS0wMGM4ZjUxNGY1MmYiLCJzY29wZXMiOiJhY2NvdW50cyBvZmZsaW5lX2FjY2VzcyIsIm5iZiI6MTY5MTE0NTY1MiwiZXhwIjoxNjkyMzU1MjUyLCJpYXQiOjE2OTExNDU2NTJ9.IP0bLxJ1ZpupidRqvsbqS-SJ0dnfJlTXxDvDfPQOgDU"
    }' 