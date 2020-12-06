#!/bin/bash -e


STORAGE_ACCOUNT=$1
DISTRIBUTE=$2
CREATE_DB=$3
APTLY_DIR="/blobfuse-${STORAGE_ACCOUNT}-aptly"
WEB_DIR="/blobfuse-${STORAGE_ACCOUNT}-web"
PUBLISH_DIR=$WEB_DIR/debian

DEBIAN_MIRROR_URL="http://deb.debian.org/debian"
DEBINA_SECURITY_MIRROR_URL="http://security.debian.org/debian-security"

if [ -z "$DISTRIBUTE" ]; then
   echo "DIST is empty" 1>&2
   exit 1
fi

BLOBFUSE_METTRIC_DIR=$APTLY_DIR/metric
BLOBFUSE_WORK_DIR=$APTLY_DIR/$DISTRIBUTE
BLOBFUSE_POOL_DIR=$BLOBFUSE_WORK_DIR/pool
BLOBFUSE_DB_DIR=$BLOBFUSE_WORK_DIR/db

WORK_DIR=work
mkdir -p $WORK_DIR
cd $WORK_DIR
APTLY_CONFIG=aptly-debian.conf

create_or_update_database()
{

}

prepare_workspace()
{
    local remote_aptly_dir="/blobfuse-${STORAGE_ACCOUNT}-aptly"
    local remote_dist_dir="$remote_aptly_dir/$DISTRIBUTE"
    local remote_db_dir="$remote_dist_dir/db"
    local remote_pool_dir="$remote_dist_dir/pool"

    mkdir -p $BLOBFUSE_POOL_DIR
    mkdir -p $PUBLISH_DIR
    cp ../config/aptly-debian.conf $APTLY_CONFIG
    ln -s "$remote_pool_dir" pool
    ln -s $PUBLISH_DIR publish

    if [ "$CREATE_DB" == "y" ]; then
        return
    fi
    local latest_db=$(ls -Ar $BLOBFUSE_DB_DIR/db-*.gz 2>/dev/null | head -n 1)
    if [ -z "$latest_db" ]; then
        echo "Please create the aptly database and try again." 1>&2
        exit 1
    fi

    tar -xzvf "$latest_db" -C "$WORK_DIR"
}

save_workspace()
{
    local remote_aptly_dir="/blobfuse-${STORAGE_ACCOUNT}-aptly"
    local remote_dist_dir="$remote_work_dir/$DISTRIBUTE"
    local remote_db_dir="$remote_dist_dir/db"
    local package="$remote_db_dir/db-$(date +%Y%m%d%H%M%S).tar.gz"

    tar -czvf "$package" db
}

update_repo()
{
    local name=$1
    local url=$2
    local dist=$3
    local archs=$4
    local components=$5
    local distname=$(echo $dist | tr '/' '_')

    # Create the aptly mirrors if it does not exist
    local repos=
    local need_to_publish=n
    for component in $(echo $components | tr ',' ' '); do
        local mirror="mirror-${name}-${distname}-${component}"
        local repo="repo-${name}-${distname}-${component}"
        local logfile="${mirror}.log"
        if ! aptly -config $APTLY_CONFIG mirror show $mirror > /dev/null 2>&1; then
            aptly -config $APTLY_CONFIG -architectures="$archs" mirror create -with-sources $mirror http://deb.debian.org/debian $dist $component
        fi
        aptly -config $APTLY_CONFIG mirror update | tee $logfile
        if grep -q "Download queue: 0 items" $logfile; then
            continue
        fi
        need_to_publish=y
        if ! aptly -config $APTLY_CONFIG repo show $repo > /dev/null 2>&1; then
            aptly -config $APTLY_CONFIG repo create $repo
        fi
        aptly -config $APTLY_CONFIG repo import $mirror $repo 'Name (~ .*)'
        repos="$repos $repo"
    done

    if [ "$need_to_publish" != "y" ];then
        return
    fi

    if ! aptly -config $APTLY_CONFIG publish show $dist filesystem:debian:; then
        aptly -config $APTLY_CONFIG publish repo -distribution=$dist -architectures=$archs -component=$componets $repos filesystem:debian:
    fi
    aptly -config $APTLY_CONFIG publish update -skip-cleanup $dist filesystem:debian:
}

prepare_workspace
aptly -config $APTLY_CONFIG mirror
update_repo debian "$DEBIAN_MIRROR_URL" buster-updates "amd64,arm64,armhf" "contrib,non-free"
#save_workspace
