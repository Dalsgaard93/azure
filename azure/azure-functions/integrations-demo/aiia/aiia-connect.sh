#!/bin/bash
curl -D- -G \
  https://api-sandbox.aiia.eu/v1/oauth/connect \
  -d client_id='aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81' \
  -d redirect_uri='' \
  -d scope="accounts%20offline_access" \
  -d response_type=code 
