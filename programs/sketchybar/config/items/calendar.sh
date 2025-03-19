#!/bin/sh

sketchybar --add item calendar center \
           --set calendar update_freq=1 \
                          icon=󰃰  \
                          icon.color="$PEACH" \
                          label.width=130 \
                          script="$PLUGIN_DIR/calendar.sh" 
