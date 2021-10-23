import os
# pip install sh
import sh

# Run this first before anything

os.chdir("/home/leonardo")

try:
    gphotoResult = (sh.pgrep(sh.ps('aux', _piped=True), 'gphoto2'))
    print(gphotoResult)
    sh.killall('gvfs-gphoto2-volume-monitor')
    print('gvfs-gphoto2-volume-monitor exists, killing')
except:
    print('gvfs-gphoto2-volume-monitor is already killed')

quit(1)
