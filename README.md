# About 

The front-end `xfreerdp-gui.sh` is a GUI for [xfreerdp](https://github.com/FreeRDP/FreeRDP) software,
development by [Prof. Wyllian Bezerra da Silva](http://wyllian.prof.ufsc.br/) at [Federal University of Santa Catarina (UFSC)](http://www.ufsc.br/).


# Requirements/Dependencies

- Linux Packages:
  - `freerdp-x11`
  - `gawk`
  - `x11-utils`
  - `yad`
  - `zenity` (only needed for zen version)


# Usage Instructions

![xfreerdp3 overview](https://github.com/user-attachments/assets/e6e591c2-827e-40b9-9bf1-d015bd2ac37e)
![YAD version](https://github.com/user-attachments/assets/cf4ca029-587f-4307-9b5b-22377b02c80b)


1. Run the script in console, e.g., `bash xfreerdp3-gui.sh` or change the permission (`chmod u+x xfreerdp3-gui.sh`) and run by command line `./xfreerdp3-gui.sh` or double-click on shortcut icon to launch.

2. QuickConnect: Fill the form ->
  - Server address or IP address.
  - User name.
  - Password.
  - Domain (optional).
  - Resolution (default: FullHD)
  - Full screen (default: No)
  - Enable Sound (default: Yes)
  - Name of shared directory at the remote desktop. (saved session)
  - Path of shared directory at the local host. (saved session)

![Quick Connect](https://github.com/user-attachments/assets/96c06429-029d-42dd-8db7-cd7351a0b084)
![Add new RDP Connection](https://github.com/user-attachments/assets/0af89051-43e8-49e9-9256-648c49dd4fe9)

3. Click in `<Connect>` to establish the connection or press `<Cancel>` to exit.
