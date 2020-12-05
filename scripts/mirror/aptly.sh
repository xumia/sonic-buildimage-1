#!/bin/bash


STORAGE_ACCOUNT=$1
DISTRIBUTE=$2
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

prepare_workspace()
{
    local remote_aptly_dir="/blobfuse-${STORAGE_ACCOUNT}-aptly"
    local remote_dist_dir="$remote_work_dir/$DISTRIBUTE"
    local remote_db_dir="$remote_dist_dir/db"
    local remote_pool_dir="$remote_dist_dir/pool"
    local latest_db=$(ls -Ar $BLOBFUSE_DB_DIR/db-*.gz | head -n 1)

    mkdir -p $BLOBFUSE_POOL_DIR
    mkdir -p $PUBLISH_DIR
    echo "pwd=$(pwd)"
    cp ../config/aptly-debian.conf $APTLY_CONFIG
    ln -s "$remote_pool_dir" pool
    ln -s $PUBLISH_DIR publish
    if [ -z "$latest_db" ]; then
        return
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
    local mirror_url=$2
    local mirror_dist=$3
    local mirror_components=$4

    # Create the aptly mirrors if it does not exist
    
}

prepare_workspace
#save_workspace


