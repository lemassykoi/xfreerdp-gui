# About 

The front-end `xfreerdp-gui.sh` is a GUI for ![xfreerdp](https://github.com/FreeRDP/FreeRDP) software,
development by [Prof. Wyllian Bezerra da Silva](http://wyllian.prof.ufsc.br/) at [Federal University of Santa Catarina (UFSC)](http://www.ufsc.br/).


# Requirements/Dependencies

- Linux Packages:
  - `freerdp-x11`
  - `gawk`
  - `x11-utils`
  - `yad`
  - `zenity`


# Usage Instructions

![xfreerdp3 overview](https://github.com/user-attachments/assets/e6e591c2-827e-40b9-9bf1-d015bd2ac37e)


1. Run the script in console, e.g., `bash xfreerdp3-gui.sh` or change the permission (`chmod u+x xfreerdp3-gui.sh`) and run by command line `./xfreerdp3-gui.sh` or double-click on shortcut icon to launch.

2. QuickConnect: Fill the form ->
  - Server address or IP address.
  - Port number.
  - Domain (optional).
  - User name.
  - Password.
  - Name of shared directory at the remote desktop.
  - Path of shared directory at the local host.
  - Any other options that you think should be included and supported by ![xfreerdp](https://github.com/awakecoding/FreeRDP-Manuals/blob/master/User/FreeRDP-User-Manual.markdown).
  - Select: 
    - Resolution of your screen or fill this field (last item in the list).
    - BPP (Bits per Pixel) or fill this field (last item in the list).
    - Full screen (optional).
    - Show log events (optional).
  
3. Click in `<Connect>` to establish the connection or press `<Cancel>` to exit.
