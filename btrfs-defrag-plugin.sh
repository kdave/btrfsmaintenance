#!/bin/bash
#
# This plugin defragments rpm files after update.
#
# If the filesystem is btrfs, run defrag command in /var/lib/rpm, set the
# desired extent size to 32MiB, but this may change in the result depending
# on the fragmentation of the free space
#
## Why 32MiB:
# - the worst fragmentation has been observed on /var/lib/rpm/Packages
# - this can grow up to several hundred of megabytes
# - the file gets updated at random places
# - although the file will be composed of many extents, it's faster to
#   merge only the extents that affect some portions of the file, instead
#   of the whole file; the difference is negligible
# - due to the free space fragmentation over time, it's hard to find
#   contiguous space, the bigger the extent is, the worse and the extent
#   size hint is not reached anyway

DEBUG="false"
EXTENT_SIZE="32M"

RPMDIR=$(rpm --eval "%_dbpath")
SCRIPTNAME="$(basename "$0")"

cleanup() {
    test -n "$tmpdir" -a -d "$tmpdir" && execute rm -rf "$tmpdir"
}

trap cleanup EXIT

tmpdir=$(mktemp -d /tmp/btrfs-defrag-plugin.XXXXXX)

log() {
    logger -p info -t $SCRIPTNAME --id=$$ "$@"
}

debug() {
    $DEBUG && log "$@"
}

respond() {
    debug "<< [$1]"
    echo -ne "$1\n\n\x00"
}

execute() {
    debug -- "Executing: $@"

    $@ 2> $tmpdir/cmd-output
    ret=$?

    if $DEBUG; then
        if test $ret -ne 0; then
            log -- "Command failed, output follows:"
            log -f $tmpdir/cmd-output
            log -- "End output"
        else
            log -- "Command succeeded"
        fi
    fi
    return $ret
}

btrfs_defrag() {
    # defrag options:
    # - verbose
    # - recursive
    # - flush each file before going to the next one
    # - set the extent target hint
    execute btrfs filesystem defragment -v -f -r -t "$EXTENT_SIZE" "$RPMDIR"
}

debug_fragmentation() {
    if $DEBUG; then
        log -- "Fragmentation $1"
        execute filefrag $RPMDIR/* > $tmpdir/filefrag-output
        if test $? -eq 0; then
            log -f $tmpdir/filefrag-output
	    log -- "End output"
        else
            log "Non-fatal error ignored."
        fi
    fi
}

ret=0

# The frames are terminated with NUL.  Use that as the delimeter and get
# the whole frame in one go.
while IFS= read -r -d $'\0' FRAME; do
    echo ">>" $FRAME | debug

    # We only want the command, which is the first word
    read COMMAND <<<$FRAME

    # libzypp will only close the plugin on errors, which may also be logged.
    # It will also log if the plugin exits unexpectedly.  We don't want
    # to create a noisy log when using another file system, so we just
    # wait until COMMITEND to do anything.  We also need to ACK _DISCONNECT
    # or libzypp will kill the script, which means we can't clean up.
    debug "COMMAND=[$COMMAND]"
    case "$COMMAND" in
    COMMITEND) ;;
    _DISCONNECT)
        respond "ACK"
        break
        ;;
    *)
        respond "_ENOMETHOD"
        continue
        ;;
    esac

    # We don't have anything to do if it's not btrfs.
    FSTYPE=$(execute stat -f --format=%T $RPMDIR)
    if test $? -ne 0; then
        respond "ERROR"
        ret=1
        break
    fi
    debug "Output follows:"
    debug "$FSTYPE"
    debug -- "End output"

    if test "$FSTYPE" != "btrfs"; then
	debug "Nothing to do: RPM Database is on $FSTYPE file system."
        respond "_ENOMETHOD"
	continue
    fi

    debug_fragmentation "before defrag run"

    btrfs_defrag > $tmpdir/defrag-output
    if test $? -ne 0; then
        respond "ERROR"
        ret=1
        break
    fi

    # Log the output if we're in debug mode
    debug "Output follows:"
    debug -f $tmpdir/defrag-output
    debug -- "End output"

    debug_fragmentation "after defrag run"

    respond "ACK"
done
debug "Terminating with exit code $ret"
exit $ret
