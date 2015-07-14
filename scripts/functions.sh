#!/bin/bash
##
#Syntax: getBaseDirs pathToscript
#sets FFBASE and checks if it ist a correct freifunk firmware checkout
#sets OWBASE and checks if it ist a correct openwrt checkout

getBaseDirs(){
    #directory of install script
    FFBASE=$(dirname "$0")
    #absolute path of firmware repository
    FFBASE=$(realpath "$FFBASE/..")
    echo "Using FreiFunk base: $FFBASE"
    echo
    if [[ -z $FFBASE || ! -d $FFBASE || ! -d $FFBASE/patches  || ! -d $FFBASE/packages  ]] ; then
        echo We need a working copy of the firmware repository as a single argument
        exit 1
    fi

    #use current working dir as openwrt base
    OWBASE=$(realpath ./)
    echo "Using OpenWRT base: $OWBASE"
    echo
    #this is a very weak check for openwrt base...
    if [[ ! -d $OWBASE &&  ! -f $OWBASE/feeds.config.default ]] ; then
        echo This script has to be called from a openWRT buildroot
        exit 1
    fi
}

patchDirToGit(){
    local PATCHDIR=$1
    local GITCO=$2
    if [[ -z $PATCHDIR || -z $GITCO ]] ; then
        echo PATCHDIR and GITCO needed!
        return 1
    fi
    local MYGIT="git -C $GITCO"
    shopt -s globstar nullglob
    for PATCH in  $PATCHDIR/* ; do
        echo "Test applying $PATCH to $GITCO"
        if  $MYGIT apply --check --whitespace=nowarn "$PATCH" ; then
            echo Actually applying patch
            if $MYGIT am --whitespace=nowarn "$PATCH" ; then
                echo Success!
            else
                echo this should never happen...
                exit 1
            fi
        else
            echo "Applying $PATCH failed!"
            FAILEDPATCHES="${FAILEDPATCHES}Failed applying\n$PATCH\nto\n$GITCO\n"
            FAILEDPATCHES="${FAILEDPATCHES} \nTry calling \"git -C $GITCO am $PATCH\" manually. git will tell you more!\n\n"
            echo Has it already been applied?
        fi
        echo
    done
    echo "Patching $GITCO done"
    echo
}

#
# Hard reeset git repo to given Revision
# resetGit $repo $revision

resetGit() {
    local GITCO=$1
    local REVISION=$2

    local MYGIT="git -C $GITCO"

    if $MYGIT rev-parse --quiet --verify "$REVISION"  >> /dev/null ; then
        echo "Resetting $GITCO to $REVISION"
        $MYGIT reset --hard "$REVISION"
        echo
    else
        echo "Revision $REVISION is not valid!"
        echo "Maybe you have to update Openwrt?"
    fi
}

resetRepos(){
    if [[ -n $OPENWRT_REV ]] ; then
        resetGit "$OWBASE" "$OPENWRT_REV"
    else
        resetGit "$OWBASE" "\@{upstream}"
    fi

    if [[ -n $ROUTING_REV ]] ; then
        resetGit "$OWBASE/feeds/routing" "$ROUTING_REV"
    else
        resetGit "$OWBASE/feeds/routing" "\@{upstream}"
    fi

    if [[ -n $PACKAGES_REV ]] ; then
        resetGit "$OWBASE/feeds/packages" "$PACKAGES_REV"
    else
        resetGit "$OWBASE/feeds/packages" "\@{upstream}"
    fi
}

patchRepos(){
    echo Patching openwrt
    echo
    patchDirToGit "$FFBASE/patches/openwrt/" "$OWBASE" "$OWBASE"

    echo Patching openwrt routing feed
    echo
    patchDirToGit "$FFBASE/patches/routing/" "$OWBASE/feeds/routing/"

    echo Patching openwrt packages feed
    echo
    patchDirToGit "$FFBASE/patches/packages/" "$OWBASE/feeds/packages/"

    if [[ -n $FAILEDPATCHES ]] ; then
        echo Unfortunatly applying these patches failed:
        echo -e "$FAILEDPATCHES"
        echo Please examine them and fix them.
        echo Thanks
    fi
}

#usage: installFeed feeddir feedname
installFeed(){
    local FFPACKAGEDIR=$1
    local FFFEEDNAME=$2
    if [[ -f  $OWBASE/feeds.conf ]] ; then
        if ! grep -q "$FFFEEDNAME" "$OWBASE/feeds.conf" ; then
            echo Adding FreiFunk packages to package feeds.conf
            echo "src-link $FFFEEDNAME $FFPACKAGEDIR" >> "$OWBASE/feeds.conf"
        else
            echo FreiFunk packages already installed
            echo
        fi
    else
        echo Using default feeds.config
        cp "$OWBASE/feeds.conf.default" "$OWBASE/feeds.conf"
        echo "src-link $FFFEEDNAME $FFPACKAGEDIR" >> "$OWBASE/feeds.conf"
    fi
}

boardConfig(){
    local BOARD=$1
    echo "$BOARD=y"
}
