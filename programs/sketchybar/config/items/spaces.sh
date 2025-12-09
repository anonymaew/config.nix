#!/bin/sh

sketchybar --add event aerospace_workspace_change

for SID in $(aerospace list-workspaces --all)
do
  sketchybar --add item space.$SID left \
             --subscribe space.$SID aerospace_workspace_change \
             --set space.$SID icon=$SID \
                              icon.font="SF Compact:Medium:13.0" \
                              label.font="sketchybar-app-font:Regular:13.0" \
                              label.y_offset=-1 \
                              background.height=20 \
                              background.corner_radius=4 \
                              padding_left=2 \
                              padding_right=2 \
                              script="$PLUGIN_DIR/space.sh $SID"              
done
sketchybar --add bracket spaces '/space\..*/' left \
           # --set spaces padding_left=2 \
           #              padding_right=2 \

sketchybar --add item space_separator left \
           --set space_separator width=0 \
                                 script="$PLUGIN_DIR/space_window.sh" \
           --subscribe space_separator space_windows_change                           
