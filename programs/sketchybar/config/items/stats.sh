#!/bin/sh

sketchybar --add item stats_label right \
           --set stats_label label="CPU     RAM" \
                             label.font.size=6 \
                             label.padding_right=16 \
                             width=0 \
                             y_offset=6 \
           --add item stats_number right \
           --set stats_number update_freq=1 \
                              icon=  \
                              icon.color="$GREEN" \
                              label.width=50 \
                              label.align=right \
                              label.font.size=10 \
                              label.y_offset=-3 \
                              background.drawing=off \
                              script="$PLUGIN_DIR/stats.sh"\
           --add bracket stats stats_number stats_label
