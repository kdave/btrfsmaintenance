#!/usr/bin/python3

# This plugin defragments rpm files after update.
#
# If the filesystem is btrfs, run defrag command in the RPM database
# folder, set the desired extent size to 32MiB, but this may change in the
# result depending on the fragmentation of the free space.
#
# Why 32MiB:
# - the worst fragmentation has been observed on Packages
# - this can grow up to several hundred of megabytes
# - the file gets updated at random places
# - although the file will be composed of many extents, it's faster to
#   merge only the extents that affect some portions of the file, instead
#   of the whole file; the difference is negligible
# - due to the free space fragmentation over time, it's hard to find
#   contiguous space, the bigger the extent is, the worse and the extent
#   size hint is not reached anyway

import sys
if sys.version_info[0] >= 3:
    from builtins import str
    popen_kwargs = { 'encoding': 'ascii' }
else:
    popen_kwargs = { }
from zypp_plugin import Plugin
import subprocess

DEBUG=False
EXTENT_SIZE=32*1024*1024
LOGFILE='/tmp/btrfs-defrag-plugin.log'
PATH=subprocess.check_output(["rpm", "--eval", "%_dbpath"], **popen_kwargs).strip()

def dbg(args):
    if not DEBUG: return
    f=open(LOGFILE, "a+")
    f.write(args)
    f.write("\n")
    f.close()

def qx(args):
    out=subprocess.Popen(args, shell=True, stdout=subprocess.PIPE, **popen_kwargs).stdout
    outstr="".join(out.readlines())
    out.close()
    return outstr

def fstype(path):
    ret=qx('stat -f --format=%T "'+path+'"')
    return ret.rstrip()

class BtrfsDefragPlugin(Plugin):
  def PLUGINBEGIN(self, headers, body):
    self.actions = []
    self.commit_hook_supported = False
    dbg('--- Btrfs defrag plugin begin')
    self.ack()

  def PLUGINEND(self, headers, body):
    dbg('--- Btrfs defrag plugin end: %s %s\n' % (str(headers), str(body)))
    dbg('--- fstype(%s) = |%s|' % (PATH, fstype(PATH)))
    if fstype(PATH) != 'btrfs':
        self.ack()
        return
    if DEBUG:
        dbg('--- Fragmentation before')
        dbg(qx('filefrag %s/*' % (PATH)))
    # defrag options:
    # - verbose
    # - recursive
    # - flush each file before going to the next one
    # - set the extent target hint
    ret = qx('btrfs filesystem defragment -v -f -r -t %s "%s"' % \
            (str(EXTENT_SIZE), PATH))
    if DEBUG:
        dbg(ret)
        dbg('--- Fragmentation after')
        dbg(qx('filefrag %s/*' % (PATH)))
    self.ack()

plugin = BtrfsDefragPlugin()
plugin.main()
