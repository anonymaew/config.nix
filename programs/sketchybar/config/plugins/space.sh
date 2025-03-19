#!/bin/bash

source "$CONFIG_DIR/settings.sh" # Loads all defined colors

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --animate tanh 15 \
             --set $NAME background.drawing=on \
                         background.color=$TEXT \
                         label.color=$BACKGROUND \
                         label.padding_left=0 \
                         icon.color=$BACKGROUND
else
  sketchybar --animate tanh 15 \
             --set $NAME background.drawing=off \
                         label.color=$TEXT \
                         label.padding_left=-10 \
                         icon.color=$TEXT
fi
