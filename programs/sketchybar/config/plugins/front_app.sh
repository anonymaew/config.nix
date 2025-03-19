#!/bin/sh

if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar \
    --animate tanh 15 \
    --set "$NAME" label="$INFO" \
                  label.padding_left=20 \
                  background.image.drawing=on \
                  background.image.string="app.$INFO" \
                  background.image.scale=0.7 \
                  background.image.padding_left=10 
fi
