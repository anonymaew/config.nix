#!/bin/bash

if [ "$SENDER" = "space_windows_change" ]; then
  SPACE="$(echo "$INFO" | jq -r '.space')"
  APPS="$(echo "$INFO" | jq -r '.apps | keys[]')"

  ICON_STRIP=""
  LABEL_DRAWING="off"
  if [ "$APPS" != "" ]; then
    while read -r APP
    do
      ICON_STRIP+="$($CONFIG_DIR/plugins/icon_map.sh "$APP")"
    done <<< "$APPS"
    LABEL_DRAWING="on"
  fi

  sketchybar --set space.$SPACE label.drawing="$LABEL_DRAWING" label=" $ICON_STRIP"
fi
