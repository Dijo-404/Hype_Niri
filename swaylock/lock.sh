#!/bin/bash
# Lock screen script — renders time on wallpaper, launches swaylock with centered password indicator

WALLPAPER="$HOME/Pictures/Wallpapers/min_forest.jpg"
LOCK_IMG="/tmp/lockscreen.png"
FONT="/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Bold.ttf"

# Get current time and date
TIME=$(date +"%H:%M")
DATE=$(date +"%A, %B %e")

# Compose the lock image: wallpaper + blur + vignette + time text at top
magick "$WALLPAPER" \
    -resize 2560x1440^ -gravity center -extent 2560x1440 \
    -blur 0x8 \
    \( -size 2560x1440 xc:none \
       -fill "rgba(30,35,38,0.5)" \
       -draw "roundrectangle 980,60 1580,200 16,16" \
    \) -composite \
    -gravity north \
    -font "$FONT" \
    -fill "#d3c6aa" \
    -pointsize 72 -annotate +0+90 "$TIME" \
    -pointsize 22 -annotate +0+160 "$DATE" \
    "$LOCK_IMG"

# Launch swaylock with the composed image.
# It will load its standard colors/indicator settings from ~/.config/swaylock/config
swaylock -f --image "$LOCK_IMG" --scaling fill
