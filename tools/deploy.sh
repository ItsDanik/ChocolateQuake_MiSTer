#!/bin/sh
# Package the build and copy it to a MiSTer over ssh, in the layout of the
# hybrid ports. The core is not (re)loaded: load a game of ChocolateQuake from the
# Other menu afterwards. Run Scripts/danik_hybrid_ports.sh on the MiSTer
# once to set up the launcher. A MiSTer that has ChocolateQuake in the old layout
# (games/ChocolateQuake/) gets it moved by the launcher (version 3) once this is
# there.
# usage: MISTER=root@<address> tools/deploy.sh
set -e
cd "$(dirname "$0")/.."
HOST=${MISTER:?set MISTER=root@<address of the MiSTer>}
./package.sh > /dev/null
OUT=dist/ChocolateQuake_$(date +%Y%m%d)
G=/media/fat/games/dnk/ChocolateQuake
ssh "$HOST" "mkdir -p $G /media/fat/_Other/dnk /media/fat/Scripts/.danik_hybrid_ports && rm -f /media/fat/_Other/dnk/dnk-ChocolateQuake_*.rbf"
# a running game keeps its binary busy: copy next to it, then swap
# (scp would copy into a folder of that name, if something left one behind)
ssh "$HOST" "rm -rf $G/ChocolateQuake.new"
scp -q "$OUT/games/dnk/ChocolateQuake/ChocolateQuake" "$HOST:$G/ChocolateQuake.new"
ssh "$HOST" "mv -f $G/ChocolateQuake.new $G/ChocolateQuake"
# everything else of the package (user files on the MiSTer are left alone)
(cd "$OUT/games/dnk/ChocolateQuake" && tar cf - --exclude=./ChocolateQuake .) | ssh "$HOST" "tar xf - --no-same-owner -C $G"
(cd "$OUT/Scripts" && tar cf - .) | ssh "$HOST" "tar xf - --no-same-owner -C /media/fat/Scripts"
(cd "$OUT/_Other" && tar cf - .) | ssh "$HOST" "tar xf - --no-same-owner -C /media/fat/_Other"
ssh "$HOST" "chmod +x $G/ChocolateQuake $G/*.sh /media/fat/Scripts/danik_hybrid_ports.sh; ls -la $G /media/fat/_Other/dnk/dnk-ChocolateQuake_*.rbf /media/fat/_Other/dnk-*.mgl"
