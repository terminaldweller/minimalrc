#!/bin/bash

EVENT_DEV="/dev/input/event4"
KMONAD_UNIT="kmonad.service"

evtest ${EVENT_DEV} 2>/dev/null | while read -r line; do
case "$line" in
  *SW_TABLET_MODE*value*1*)
    systemctl --user stop ${KMONAD_UNIT}
    ;;
  *SW_TABLET_MODE*value*0*)
    systemctl --user start ${KMONAD_UNIT}
    ;;
esac
done
