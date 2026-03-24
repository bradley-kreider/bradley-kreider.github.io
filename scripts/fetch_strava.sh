#!/bin/bash
set -e

# Exchange refresh token for access token
TOKEN_RESPONSE=$(curl -s -X POST https://www.strava.com/oauth/token \
  -d "client_id=${STRAVA_CLIENT_ID}" \
  -d "client_secret=${STRAVA_CLIENT_SECRET}" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=${STRAVA_REFRESH_TOKEN}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "Failed to get access token"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

# Fetch latest activity
ACTIVITY=$(curl -s -X GET \
  "https://www.strava.com/api/v3/athlete/activities?page=1&per_page=1" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

# Extract photo URL if available
PHOTO_URL=$(echo "$ACTIVITY" | jq -r '.[0].photos.primary.urls["600"] // ""')

# Build strava.json
jq -n \
  --argjson a "$(echo "$ACTIVITY" | jq '.[0]')" \
  --arg photo "$PHOTO_URL" \
  '{
    activity: {
      id:                   ($a.id | tostring),
      name:                 $a.name,
      type:                 $a.type,
      sport_type:           ($a.sport_type // $a.type),
      distance:             $a.distance,
      moving_time:          $a.moving_time,
      elapsed_time:         $a.elapsed_time,
      total_elevation_gain: $a.total_elevation_gain,
      start_date_local:     $a.start_date_local,
      photo_url:            $photo,
      loaded:               true
    }
  }' > data/strava.json

echo "Wrote data/strava.json:"
cat data/strava.json
