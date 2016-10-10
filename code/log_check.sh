#!/bin/sh
SWHS_PREF="SWHS_"
TINY_PREF=""
SSP_PREF="SSP_"
GLASS_PREF="GlassBR_"
GAME_PREF="Chipmunk_"
PCM_PREF="PCM_"
log="log.log"

errors="no"

if [ -s $SWHS_PREF$log ]; then
  echo "-------------------------------------------"
  echo "- $SWHS_PREF$log IS NOT EMPTY -- DIFFERENCE"
  echo "- BETWEEN GENERATED AND STABLE OUTPUT FOUND"
  echo "-------------------------------------------"
  errors="yes"
fi

if [ -s $TINY_PREF$log ]; then
  echo "-------------------------------------------"
  echo "- $TINY_PREF$log IS NOT EMPTY -- DIFFERENCE"
  echo "- BETWEEN GENERATED AND STABLE OUTPUT FOUND"
  echo "-------------------------------------------"
  errors="yes"
fi

if [ -s $SSP_PREF$log ]; then
  echo "-------------------------------------------"
  echo "- $SSP_PREF$log IS NOT EMPTY -- DIFFERENCE"
  echo "- BETWEEN GENERATED AND STABLE OUTPUT FOUND"
  echo "-------------------------------------------"
  errors="yes"
fi

if [ -s $GLASS_PREF$log ]; then
  echo "-------------------------------------------"
  echo "- $GLASS_PREF$log IS NOT EMPTY -- DIFFERENCE"
  echo "- BETWEEN GENERATED AND STABLE OUTPUT FOUND"
  echo "-------------------------------------------"
  errors="yes"
fi

if [ -s $GAME_PREF$log ]; then
  echo "-------------------------------------------"
  echo "- $GAME_PREF$log IS NOT EMPTY -- DIFFERENCE"
  echo "- BETWEEN GENERATED AND STABLE OUTPUT FOUND"
  echo "-------------------------------------------"
  errors="yes"
fi

if [ -s $PCM_PREF$log ]; then
  echo "-------------------------------------------"
  echo "- $PCM_PREF$log IS NOT EMPTY -- DIFFERENCE"
  echo "- BETWEEN GENERATED AND STABLE OUTPUT FOUND"
  echo "-------------------------------------------"
  errors="yes"
fi

if [ "$errors" = "no" ]; then
  echo "-------------------------------------------"
  echo "- GENERATED OUTPUT MATCHES STABLE VERSION -"
  echo "-------------------------------------------"
else
  echo "-------------------------------------------"
  echo "- ERROR IN GENERATED OUTPUT SEE ABOVE FOR -"
  echo "-             MORE DETAILS                -"
  echo "-------------------------------------------"
fi
