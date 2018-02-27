#!/bin/bash -e

[[ ! -d _rel ]] && echo 'Cannot find _rel/ Is the release built?' && exit -1

echo "Checking release startup with node $rel..."

sup() {
    "$PWD"/_rel/kazoo/bin/sup $*
}

shutdown() {
    sup init stop
}

waitfor() {
TIMEOUT=${1:-"120"}
SEARCH_TERM=${2:-"nada"}
echo "waiting for '$SEARCH_TERM'"
(timeout --foreground $TIMEOUT tail -f _rel/kazoo/log/debug.log  2>&1 &) | grep -q "$SEARCH_TERM" && echo "found '$SEARCH_TERM'" && exit 0
echo "timeout waiting for '$SEARCH_TERM'"
}


script() {
    mkdir -p _rel/kazoo/log
    touch _rel/kazoo/log/debug.log
    waitfor 120 "finished system schemas update"
    sup crossbar_maintenance create_account 'compte_maitre' 'royaume' 'superduperuser' 'pwd!' || shutdown
    sleep 3
    sup kapps_maintenance migrate || shutdown
    sleep 3
    sup kapps_maintenance migrate_to_4_0 || shutdown
    sleep 9
    shutdown
}

script &
export KAZOO_CONFIG=$PWD/rel/ci.config.ini
#REL=$rel make release
$PWD/_rel/kazoo/bin/kazoo console
code=$?

if [[ -f erl_crash.dump ]]; then
    echo A crash dump was generated!
    code=3
fi

error_log="$PWD/_rel/kazoo/log/error.log"
if [[ -f $error_log ]]; then
    echo
    echo Error log:
    cat "$error_log"
    if [[ $(grep -c -v -F 'exit with reason shutdown' "$error_log") -gt 0 ]]; then
        echo
        echo "Found errors in $error_log"
        code=4
    fi
fi

exit $code
