#!/bin/sh

source "$CONFIG_DIR/settings.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON="" COLOR="$GREEN"
  ;;
  [6-8][0-9]) ICON="" COLOR="$GREEN"
  ;;
  [3-5][0-9]) ICON="" COLOR="$YELLOW"
  ;;
  [1-2][0-9]) ICON="" COLOR="$RED"
  ;;
  *) ICON="" COLOR="$RED"
esac

if [[ "$CHARGING" != "" ]]; then
  ICON="" COLOR="$SKY"
fi

sketchybar --animate tanh 30 \
           --set "$NAME" icon="$ICON" \
                         icon.color="$COLOR" \
                         label="${PERCENTAGE}%"
