sudo -iu steam bash -lc '
  set -e
  export WINEPREFIX=/opt/rs2/wine64
  mkdir -p /opt/rs2/winsteamcmd && cd /opt/rs2/winsteamcmd
  # grab Windows steamcmd
  curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip -o steamcmd.zip
  unzip -o steamcmd.zip
  # use xvfb-run so Wine has a display
  xvfb-run -a wine ./steamcmd.exe +login anonymous \
    +force_install_dir /opt/rs2/server \
    +app_update 418480 validate +quit
'
