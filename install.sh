#!/bin/bash
## archive="vs_archive_$(wget 'http://version.vintagestory.at/version.txt' -q -O -).tar.gz"; wget "https://account.vintagestory.at/files/stable/${archive}" -q
## check installation prequisite
[ -n "${NO_SUPPORT_MODE}" ] && echo "Warning! You are running in 'NO_SUPPORT_MODE', disabling some requirements checks. Have fun but please avoid to ask for support!"
hash mono-xmltool 2>/dev/null || [ -n "${NO_SUPPORT_MODE}" ] || { echo "Please install mono-complete > v5.11 before installing Vintage Story."; exit 1; }
[ $(mono --version | grep JIT | tr -dc '[:digit:]' | cut -c-3) -gt 511 ] || [ -n "${NO_SUPPORT_MODE}" ] || { echo "Please upgrade to mono compiler version > 5.11."; exit 1; } 

## current location of this script
PHYS_PATH="$(readlink -f -- "$0")"
THIS_FILE="$(basename -- "$PHYS_PATH")"
DATA_PATH="$(csharp -e 'print(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData));' 2>/dev/null)/VintagestoryData"
## switch to working directory (logical - maybe a link)
cd "${0%/$THIS_FILE}"

## comment this line out to ignore version during install
export VERSION=$(mono "Vintagestory.exe" -v --dataPath "${DATA_PATH}" | tr -dc '[:digit:][:punct:]'); [ -n "${VERSION}" ] || { echo; echo "Fatal! ${THIS_FILE} abort."; exit 1; }

## define installation targets
export APPDATA="$HOME/ApplicationData"
export INST_DIR="$(basename -- "${PWD%%.*}")" && { echo; echo "Install game into ${APPDATA}/${INST_DIR} (data into ${DATA_PATH})"; }
export MENUSTARTER="$HOME/.local/share/applications/$INST_DIR.desktop"
export DESKSTARTER="$(xdg-user-dir DESKTOP)/$INST_DIR.desktop"
export USERFONTS="$HOME/.local/share/fonts"
## create needed directories
applications_dir=$HOME/.local/share/applications
if [ ! -d "$applications_dir" ]; then
        mkdir -p "$applications_dir"
fi

for i in $DATA_PATH/Logs $APPDATA $USERFONTS ./backup ; do [ -d "$i" ] || { echo "Create NewDir $i"; mkdir -p "$i"; }; done

## set list separator to enable iteration over filenames with spaces
IFS=$(echo -en "\n\b")
## relocate installation if not already in the right place
if [ "$(readlink -f -- "$APPDATA/$INST_DIR")" != "$(readlink -f -- "$PWD")" ]; then
    ## copy existing game directories that are not packaged
    for i in $(find $(ls -d $APPDATA/${INST_DIR%%.*}.* | sort -d | tail -n 1) -mindepth 1 -maxdepth 1 -type d) 
		do [ -d "./${i##*/}" ] || { echo "Keep OldDir ${i##*/}"; cp -pfr "$i" "./${i##*/}"; }; done
    ## check/cleanup old installation
    [ -d "$APPDATA/$INST_DIR" ] && { echo "Cleanup"; rm -f "$MENUSTARTER"; rm -f "$DESKSTARTER"; mv -f "$APPDATA/$INST_DIR" "$APPDATA/$INST_DIR.bak.$(date '+%Y%m%d%H%M%S')"; }
    ## move / merge directories
    if [ -d ./VintagestoryData -a "${DATA_PATH}" != "$APPDATA/$INST_DIR/VintagestoryData" ]; then
      { echo "Move Data"; cp -pfrl ./VintagestoryData "${DATA_PATH%/*}" && rm -fr ./VintagestoryData; }; fi
    { echo "Move AppDir"; mkdir -p "$APPDATA"; mv -f "${PHYS_PATH%/$THIS_FILE}" "$APPDATA/$INST_DIR" && cd "$APPDATA/$INST_DIR"; }
fi

## check/install desktop starters if possible
if [ -d "${MENUSTARTER%/*}" -a -d "${DESKSTARTER%/*}" -a "${1}" != "--minimal" ]; then
 { echo "Create MenuStarter & DesktopStarter"; envsubst < "./Vintagestory.desktop" | tee "$MENUSTARTER" "$DESKSTARTER" > /dev/null; chmod ugo+x "$MENUSTARTER" "$DESKSTARTER"; }
fi
## check/install fonts
for i in $(find "./assets/game/fonts" -name *.ttf -type f); do [ -f "$USERFONTS/${i##*/}" ] || { echo "Install GameFont ${i##*/}"; cp -p "${i}" "$USERFONTS"; }; done
for i in $(find "./assets/game/fonts" -name *.otf -type f); do [ -f "$USERFONTS/${i##*/}" ] || { echo "Install GameFont ${i##*/}"; cp -p "${i}" "$USERFONTS"; }; done
## apply fixes for known issues
for i in $(find "./assets"); do f="$(basename -- "$i")"; [ "$f" = "${f,,}" ] || { echo "Create LowercaseAlias for $f"; ln -sf "$f" "${i%/*}/${f,,}"; }; done

## Fix out of ram issues
sudo sysctl -w vm.max_map_count=262144


## Check if the user wants to enable mesa_glthread
# if the user has a Intel or AMD Graphics we enable mesa_glthread which should give a performance boost
# we assume when having AMD that they are using the newer mesa driver (not AMD Catalyst driver) since that should be the default and recommended by AMD anyways
# intel has always been mesa
# note: we advise against using the Nouveau on NVIDIA (mesa) since it is no where near the proprietary drivers performance

if lspci -vnn | grep VGA | grep -q "AMD\|Intel"; then
  echo "Do you want to enable 'mesa_glthread'?"
  echo "Enabling this feature can provide a performance boost. However, if you experience a freezing window, you can navigate to your installation directory and remove it from the run.sh file."
  read -p "Enable 'mesa_glthread'? (y/n): " response
  
  if [[ $response =~ ^[Yy]$ ]]; then
      echo "Enabling mesa_glthread=true in run.sh"
      echo "#!/bin/bash" > run.sh
      echo "# This shell script launches the game client on linux" >> run.sh
      echo "mesa_glthread=true mono Vintagestory.exe" >> run.sh
  else
      echo "'mesa_glthread' disabled"
  fi
fi

echo "Install complete. If the desktop icon does not work, you can still run the game by executing 'mono VintageStory.exe'. If the game has problems connecting to the auth server, please run 'sudo cert-sync /etc/pki/tls/certs/ca-bundle.crt'"
