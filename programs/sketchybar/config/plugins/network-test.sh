#!/bin/sh

# source "$CONFIG_DIR/settings.sh"

# From Gruvbox Dark
FG1="$SKY" # or whatever you use for active icons
FG2="$SUBTEXT0" # or whatever you use for dim icons

# From SF Symbols
NET_WIFI=􀙇         # Wi-Fi connected
NET_HOTSPOT=􀉤      # iPhone Wi-Fi hotspot connected
NET_USB=􀟜          # iPhone USB hotspot connected
NET_THUNDERBOLT=􀒗  # Thunderbolt bridge connected
NET_DISCONNECTED=􀙇 # Network disconnected, but Wi-Fi turned on
NET_OFF=􀙈          # Network disconnected, Wi-Fi turned off
# When switching between devices, it's possible to get hit with multiple
# concurrent events, some of which may occur before `scutil` picks up the
# changes, resulting in race conditions.
sleep 1

services=$(networksetup -listnetworkserviceorder)
device=$(scutil --nwi | sed -n "s/.*Network interfaces: \([^,]*\).*/\1/p")

test -n "$device" && service=$(echo "$services" \
  | sed -n "s/.*Hardware Port: \([^,]*\), Device: $device.*/\1/p")

SERVICE="on"
case $service in
  "iPhone USB")         icon=$NET_USB;;
  "Thunderbolt Bridge") icon=$NET_THUNDERBOLT;;

  Wi-Fi)
    ssid=$(networksetup -getairportnetwork "$device" \
      | sed -n "s/Current Wi-Fi Network: \(.*\)/\1/p")
    case $ssid in
      *iPhone*) icon=$NET_HOTSPOT;;
      "")       icon=$NET_DISCONNECTED; SERVICE="off";;
      *)        icon=$NET_WIFI;;
    esac;;

  *)
    wifi_device=$(echo "$services" \
      | sed -n "s/.*Hardware Port: Wi-Fi, Device: \([^\)]*\).*/\1/p")
    test -n "$wifi_device" && status=$( \
      networksetup -getairportpower "$wifi_device" | awk '{print $NF}')
    icon=$(test "$status" = On && echo "$NET_DISCONNECTED" || echo "$NET_OFF")
    SERVICE="off";;
esac

UPDOWN=$(ifstat-legacy -i "$device" -b 1 1 | tail -n1)
DOWN=$(echo $UPDOWN | awk "{ print \$1 }" | cut -f1 -d ".")
UP=$(echo $UPDOWN | awk "{ print \$2 }" | cut -f1 -d ".")

kbtoformat() {
  local num=$(( $1 / 8 ))
  local unit="KB"
  if [ $num -gt 999 ]; then
    num=$(echo "scale=2; $num / 1024" | bc)
    unit="MB"
  fi
  if [ $num -gt 999 ]; then
    num=$(echo "scale=2; $num / 1024" | bc)
    unit="GB"
  fi
  num=$(printf "%.2f" $num | cut -c1-4)
  [ "${num: -1}" = "." ] && num=${num%?}
  echo "$num $unit/s"
}
color=$([ "$SERVICE" = "on" ] && echo "$FG1" || echo "$FG2")
width=$([ "$SERVICE" = "on" ] && echo 54 || echo 0)

echo "$SERVICE"

# UPS=$([ "$SERVICE" = "on" ] && echo "$(kbtoformat $UP)" || echo "")
# DOWNS=$([ "$SERVICE" = "on" ] && echo "$(kbtoformat $DOWN)" || echo "")
#
# sketchybar --animate tanh 30 \
#            --set net_down icon="$icon" \
#                           icon.color="$color" \
#                           label="$DOWNS" \
#                           label.width="$width" \
#            --animate tanh 30 \
#            --set net_up label="$UPS" \
