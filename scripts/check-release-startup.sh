#!/bin/bash -e
PATH=$PATH:$(dirname $0):/opt/kazoo/_rel/kazoo/bin
export PATH

[[ ! -d _rel ]] && echo 'Cannot find _rel/ Is the release built?' && exit -1

echo "Checking release startup with node $rel..."

shutdown() {
    sup init stop
    exit 0
}

waitfor() {
TIMEOUT=${1:-"120"}
SEARCH_TERM=${2:-"nada"}
echo "waiting for '$SEARCH_TERM'"
(timeout --foreground $TIMEOUT tail -f _rel/kazoo/log/debug.log  2>&1 &) | grep -q "$SEARCH_TERM" && echo "found '$SEARCH_TERM'" && return 0
echo "timeout waiting for '$SEARCH_TERM'"
return 1
}


script() {
    mkdir -p _rel/kazoo/log
    touch _rel/kazoo/log/debug.log
    waitfor 180 "auto-started kapps" || shutdown
    echo "creating account"
    sup crossbar_maintenance create_account 'compte_maitre' 'royaume' 'superduperuser' 'pwd!' || shutdown
    echo "running account created"
    sleep 3
    echo "running migrate"
    sup kapps_maintenance migrate || shutdown
    sleep 3
    echo "running migrate to 4"
    sup kapps_maintenance migrate_to_4_0 || shutdown
    sleep 9
    shutdown
}

export KAZOO_NODE=apps
export KAZOO_COOKIE=change_me

script > _rel/kazoo/log/sup.log 2>&1 &

export KAZOO_CONFIG=$PWD/rel/ci.config.ini
kazoo console

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
