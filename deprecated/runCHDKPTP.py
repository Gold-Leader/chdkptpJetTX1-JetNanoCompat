import os
import subprocess
import sh
import fcntl

# Operation:
# Controls a CHDK, Canon Hacker Development Kit, enabled camera over PTP application CHDKPTP
# Handles connection errors as result of host-device PTP interactions
# Saves image to specified directory, see startupCHDKPTP, line 4

# Notes:
# Removed Shotwell
# sudo dpkg -r sehotwell
# Removed Cheese Webcam Booth
# sudo apt-get purge cheese

# TODO Remove all print statements
# Setup environment so chdkptp will run properly
# And navigate to chdkptp application directory
# The .lua and .so files are part of the CHDKPTP install
os.chdir("/home/leonardo/Downloads/chdkptp-r921")
os.environ["LUA_PATH"] = "/home/leonardo/Downloads/chdkptp-r921/lua/?.lua;;"
os.environ["LUA_CPATH"] = "/home/leonardo/Downloads/chdkptp-r921/?.so;;"

# Based on code located at:
# https://gist.github.com/PaulFurtado/fce98aef890469f34d51
# usb_reset.py By Paul Furtado

USBDEVFS_RESET = ord('U') << (4*2) | 20

# Kill the gvfs-gphoto2-volume-monitor service
# Resolves PTP communication issues
def stopgphoto2():
    try:
        sh.killall('gvfs-gphoto2-volume-monitor')
        print('gvfs-gphoto2-volume-monitor exists, terminating')
    except:
        print('gvfs-gphoto2-volume-monitor is terminated')
    return

# Reboot the USB the camera is connected to
# Selectively chooses the specific port the Camera is connected to using grep
# Issues reset command via dev/bus/usb
def resetusb():
    try:
        lsusbResult = sh.grep(sh.lsusb(), "Canon")
        # print(lsusbResult)
        lsusbResult = str(lsusbResult).split()
        # print(resultSplit)
        usbPath = '/dev/bus/usb/%s/%s' % (lsusbResult[1], lsusbResult[3][:3])
        # print(usbPath)
        path = os.open(usbPath, os.O_WRONLY)
        try:
            fcntl.ioctl(path, USBDEVFS_RESET, 0)
        finally:
            os.close(path)
    except:
        print("Camera not found, check connections and power")
    return

# Call CHDKPTP application directly using a startup file containing CHDKPTP Commands
# startupCHDKPTP must be in the CHDKPTP directory
connectExit = subprocess.call(['/home/leonardo/Downloads/chdkptp-r921/chdkptp', '-r=startupCHDKPTP'])
# Handle outputs and errors, reset USB to resolve lingering PTP errors
if connectExit == 1:
    print("Connection failed, resetting USB port.")
    resetusb()
    # Try calling CHDKPTP again
    try:
        subprocess.call(['/home/leonardo/Downloads/chdkptp-r921/chdkptp', '-r=startupCHDKPTP'])
    except:
        print("Reset failed, no connection.")
elif connectExit == 0:
    print("Connection successful, taking image.")
else:
    print("An unhandleable error has occurred.")

# Reset back to the home directory
os.chdir("/home/leonardo/")

quit(1)
