#!/bin/bash

# Decide whether we're using web API
while getopts "r" arg; do
    case ${arg} in
        r)
            WEBAPI=1
            ;;
        *)
            ;;
    esac
done

# Process only non-opt paths
shift $(($OPTIND - 1))
if [[ ! `echo "$@" | wc -w` -eq 1 ]]; then
    exit
fi
if [[ ! -e "$@" ]]; then
    echo "$@ is not a valid path"
    exit
fi
TARGET=$(realpath $@)

# Since it's cheap to create symlinks, we can wipe the target dir of any symlinks each time we run
find "$TARGET" -maxdepth 1 -type l -delete

# Look in the default location for screenshots and the associated .vdf file
SSFILEPATH=$(find /home/deck/.local/share/Steam -name screenshots.vdf 2> /dev/null)
SSDIR=$(dirname $SSFILEPATH)

# Ask Steam for all Library Folder locations
LIBDIRS=$(grep -F "\"path\"" /home/deck/.local/share/Steam/config/libraryfolders.vdf | tr -s $'\t' | cut -f3)

# For each screenshot folder, attempt to locate the associated game
for GAME in $(ls "$SSDIR/remote/")
do
    TITLE=""

    # Look in our library folders for an associated .acf to pull the name from
    for LDIR in $LIBDIRS
    do
        if [[ -e ${LDIR:1:-1}/steamapps/appmanifest_$GAME.acf ]]; then
            TITLE="$(grep -F "name" "${LDIR:1:-1}/steamapps/appmanifest_$GAME.acf" | tr -s $'\t' | cut -f3 -d$'\t')"
            TITLE="${TITLE:1:-1}"
        fi
    done

    # Since we can't find it in our installed library, let's look in our list of Non-Steam games
    if [[ -z $TITLE ]]; then
        if [[ $(grep -F "$GAME" "$SSFILEPATH" > /dev/null) -eq 1 ]]; then
            TITLES="$(grep -F "$GAME" "$SSFILEPATH" )" # | tr -s $'\t' | cut -f3 -d$'\t')"
            TITLE="$(echo $TITLES | grep -v "$GAME")"
        fi
    fi

    # If we're allowed, let's ping the Steam API to see if they know
    if [[ -z $TITLE && $WEBAPI -eq 1 ]]; then
        SAPI=$(curl -s https://store.steampowered.com/api/appdetails?appids=$GAME | tr ' ' '\n')
        if grep -q '"success":false' <<< "$SAPI"; then
            TITLE="$GAME"
        else
            TITLE="$(echo $SAPI | sed 's/.*"type":".*","name":"\(.*\)","steam_appid".*/\1/')"
        fi
        unset SAPI
    fi

    # All else fails, fall back to hardcoded names or use the ID itself
    if [[ -z $TITLE ]]; then
        if [[ $GAME -eq 7 ]]; then
            TITLE="SteamOS"
        else
            TITLE="$GAME"
        fi
    fi

    # Append a number to avoid conflicting symlinks
    COPYNUM=0
    while [[ -e "$TARGET/$TITLE" ]]; do
        COPYNUM=$(expr $COPYNUM + 1)
        TITLE="$TITLE_$COPYNUM"
    done
	
    # Create the symlink
    ln -s "$SSDIR/remote/$GAME/screenshots" "$TARGET/$TITLE"
done
