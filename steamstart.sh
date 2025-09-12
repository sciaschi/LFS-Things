sudo -iu steam bash -lc '
  mkdir -p /opt/rs2/wine64/drive_c/rs2server
  cd /opt/rs2/winsteamcmd
  WINEPREFIX=/opt/rs2/wine64 xvfb-run -a wine ./steamcmd.exe \
    +login YOUR_STEAM_USERNAME \
    +force_install_dir C:\rs2server \
    +app_update 418480 validate +quit
'
