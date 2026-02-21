#!/bin/bash

# ~/.config/niri/auto-maximize.sh
# Daemon that listens to Niri window events and manages column widths dynamically

niri msg -j event-stream | jq --unbuffered -c 'select(has("WindowOpenedOrChanged") or has("WindowClosed"))' | while read -r event; do
    # Get active workspace directly
    WORKSPACE_ID=$(niri msg -j workspaces | jq '.[] | select(.is_focused) | .id' 2>/dev/null)
    if [ -z "$WORKSPACE_ID" ]; then
        continue
    fi

    # Read all windows
    WINDOWS=$(niri msg -j windows 2>/dev/null)
    
    # Check count in this workspace
    COUNT=$(echo "$WINDOWS" | jq "[.[] | select(.workspace_id == $WORKSPACE_ID)] | length")

    if [ "$COUNT" -eq 1 ]; then
        WINDOW_ID=$(echo "$WINDOWS" | jq '.[] | select(.workspace_id == '"$WORKSPACE_ID"') | .id')
        niri msg action focus-window --id "$WINDOW_ID"
        # Niri maximize column toggles, so we ensure it expands fully. 
        # Since it's the only window, 'expand-column-to-available-width' works well or 'set-column-width 100%'
        niri msg action set-column-width "100%"
    elif [ "$COUNT" -gt 1 ]; then
        # When there are multiple apps, Niri default is 50%. Let's ensure they are set to 50%.
        # We loop over windows in this workspace and set-column-width to 50%
        for WID in $(echo "$WINDOWS" | jq '.[] | select(.workspace_id == '"$WORKSPACE_ID"') | .id'); do
            niri msg action focus-window --id "$WID"
            niri msg action set-column-width "50%"
        done
    fi
done
