#!/bin/sh

CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
CPU_INFO=$(ps -eo pcpu,user)
CPU_SYS=$(echo "$CPU_INFO" | grep -v $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_USER=$(echo "$CPU_INFO" | grep $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_INFO="$(echo "$CPU_SYS $CPU_USER" | awk '{ printf("%.0f", ($1 + $2)*100) }')"
RAM_INFO="$(memory_pressure | grep "System-wide memory free percentage:" | awk '{ printf("%.0f", 100-$5) }')"
STRING=$(echo "$CPU_INFO% $RAM_INFO%" | awk '{ printf("%s%4s", $1, $2) }')

sketchybar --set "$NAME" label="$STRING"
