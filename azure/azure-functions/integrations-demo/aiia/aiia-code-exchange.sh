#!/bin/bash
curl -D- -X POST https://api-sandbox.aiia.eu/v1/oauth/token \
  -u 'aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81:6e6c150ebcb36f90e8cd5c750c8c0ca42a8751b7d63f0110a465115dff4dec86' \
  -H 'Content-Type: application/json' \
  -d '{
        "grant_type" : "authorization_code",
        "code": "ygAAAAVDaXBoZXJ0ZXh0AJAAAAAAxCFlSoIyb38qOG1MDS4xh8NCTtCH7mDrQWTezoxAyvg2QDkIoyrCPfBnRPbKXNstMOSzbU+ff6kJIBvYNGzlz/qcnmPnLeGkzqPGJrYYeVQXKb8zSHj8sNXvbSsrFCH3vyJ/OjEgSkBbaob+sn88WH6KAleHRD01Av7dxxfRJXDwcU/WA4pyxBC1ymPG76yDBUl2ABAAAAAA9eXI4kqaKy9RXqDltMrrQBBLZXlJZAAAAAAAAA==",
        "redirect_uri" : "https://aiia-test-site.azurewebsites.net/"
      }'
