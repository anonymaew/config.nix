#!/bin/sh

sketchybar --add item net_up right \
           --set net_up width=0 \
                        background.drawing=off \
                        label.font.size=9 \
                        label.y_offset=6 \
                        label.align=right \
           --add item net_down right \
           --set net_down update_freq=1 \
                          background.drawing=off \
                          label.font.size=9 \
                          label.y_offset=-4 \
                          label.align=right \
                          script="$PLUGIN_DIR/network.sh" \
           --add bracket network net_down net_up \
           --set network background.color="$BACKGROUND"
