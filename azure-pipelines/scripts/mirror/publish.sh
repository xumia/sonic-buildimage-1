#!/bin/bash -e

CREATE_DB=$1
MIRROR_NAME=$2

IS_DIRTY_VERSION=n
DEBIAN_MIRRORS_CONFIG=azure-pipelines/config/debian-mirrors.config
DATABASE_VERSION_FILENAME=${MIRROR_NAME}-databse-version
DEBIAN_MIRROR_URL="https://deb.debian.org/debian"
DEBINA_SECURITY_MIRROR_URL="http://security.debian.org/debian-security"


if [ -z "$MIRROR_NAME" ]; then
    echo "DIST is empty" 1>&2
    exit 1
fi

if [ ! -f "$DEBIAN_MIRRORS_CONFIG" ]; then
    echo "The debian mirros config file $DEBIAN_MIRRORS_CONFIG does not exist" 1>&2
    exit 1
fi

MIRROR_CONFIG=$(grep -e "^$MIRROR_NAME\s" $DEBIAN_MIRRORS_CONFIG | tail -n 1)
MIRROR_FILESYSTEM=$(echo $MIRROR_CONFIG | awk '{print $2}')
MIRROR_URL=$(echo $MIRROR_CONFIG | awk '{print $3}')
MIRROR_DISTRIBUTIONS=$(echo $MIRROR_CONFIG | awk '{print $4}')
MIRROR_COMPONENTS=$(echo $MIRROR_CONFIG | awk '{print $5}')
MIRROR_ARICHTECTURES=$(echo $MIRROR_CONFIG | awk '{print $6}')
FILESYSTEM="filesystem:$MIRROR_FILESYSTEM:"

if [ -z "$GPG_KEY" ]; then
    echo "The encrypted gpg key is not set." 1>&2
    exit 1
fi

if [ -z "$MIRROR_VERSION" ]; then
    echo "The MIRROR_VERSION env is not set." 1>&2
    exit 1
fi

if [ -z "$PASSPHRASE" ]; then
    echo "The passphrase is not set." 1>&2
    exit 1
fi

WORK_DIR=work
cd $WORK_DIR
APTLY_CONFIG=aptly-debian.conf
SAVE_WORKSPACE=n

ENCRIPTED_KEY_GPG=./encrypted_private_key.gpg
VERSION_FILE=_aptly/version
echo "$GPG_KEY" > $ENCRIPTED_KEY_GPG
echo "$PASSPHRASE" > _passphrase


if ! readlink aptly > /dev/null; then
    echo "$WORK_DIR/aptly is not a symbol link" 1>&2
    exit 1
fi

BLOBFUSE_DB_DIR=aptly/dbs
BLOBFUSE_METTRIC_DIR=aptly/metric
mkdir -p $BLOBFUSE_DB_DIR $BLOBFUSE_METTRIC_DIR


export GNUPGHOME=gnupg
rm -rf $GNUPGHOME
GPG_FILE=$GNUPGHOME/mykey.gpg
mkdir $GNUPGHOME
echo "pinentry-mode loopback" > $GNUPGHOME/gpg.conf
chmod 600 $GNUPGHOME/*
chmod 700 $GNUPGHOME

create_or_update_database()
{
    echo y
}

check_dirty_version()
{
    local database_version=none
    local publish_version=
    local database_version_file=db/$DATABASE_VERSION_FILENAME
    local publish_version_file=publish/versions/$DATABASE_VERSION_FILENAME
    [ -f $database_version_file ] && database_version=$(cat $database_version_file)
    [ -f $publish_version_file ] && publish_version=$(cat $publish_version_file)
    local is_dirty_version=n
    if [ "$database_version" != "$publish_version" ]; then
        is_dirty_version=y
    fi
    echo $is_dirty_version
}

prepare_workspace()
{
    echo "pwd=$(pwd)"
    cp ../azure-pipelines/config/aptly-debian.conf $APTLY_CONFIG

    # Import gpg key
    gpg --no-default-keyring --passphrase="$PASSPHRASE" --keyring=$GPG_FILE --import "$ENCRIPTED_KEY_GPG"

    if [ -e db ]; then
        rm -rf db
    fi

    if [ "$CREATE_DB" == "y" ]; then
        return
    fi
    local latest_db=$(ls -Ar $BLOBFUSE_DB_DIR/db-*.gz 2>/dev/null | head -n 1)
    if [ -z "$latest_db" ]; then
        echo "Please create the aptly database and try again." 1>&2
        exit 1
    fi

    echo "The latest db file is $latest_db."
    tar -xzvf "$latest_db" -C .
    IS_DIRTY_VERSION=$(check_dirty_version)
    echo "IS_DIRTY_VERSION=$IS_DIRTY_VERSION"
}

save_workspace()
{
    local package="$BLOBFUSE_DB_DIR/db-$(date +%Y%m%d%H%M%S).tar.gz"
    local database_version_file=db/$DATABASE_VERSION_FILENAME
    local publish_version_file=publish/versions/$DATABASE_VERSION_FILENAME
    local public_key_file_asc=publish/public_key.asc
    local public_key_file_gpg=publish/public_key.gpg

    mkdir -p publish/versions
    if [ "$IS_DIRTY_VERSION" == "y" ] && [ -f "$database_version_file" ]; then
        cp "$database_version_file" "$publish_version_file"
        gpg --no-default-keyring --keyring=$GPG_FILE --export -a > "$public_key_file_asc"
        gpg --no-default-keyring --keyring=$GPG_FILE --export > "$public_key_file_gpg"
    fi

    if [ "$SAVE_WORKSPACE" == "n" ]; then
        return
    fi

    #local version=$(date +%Y%m%d%H%M%S-%N)
    local version=$MIRROR_VERSION
    echo "Saving the db version $version"
    echo $version > $database_version_file
    cp "$database_version_file" "$publish_version_file"
    gpg --no-default-keyring --keyring=$GPG_FILE --export -a > "$public_key_file_asc"
    gpg --no-default-keyring --keyring=$GPG_FILE --export > "$public_key_file_gpg"
    tar -czvf "$package" db
    echo $version > $VERSION_FILE
    echo "Saving workspace to $package is complete"
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
    [ "$CREATE_DB" == "y" ] && need_to_publish=y
    for component in $(echo $components | tr ',' ' '); do
        local mirror="mirror-${name}-${distname}-${component}"
        local repo="repo-${name}-${distname}-${component}"
        local logfile="${mirror}.log"
        local current_url=$url
        if ! aptly -config $APTLY_CONFIG mirror show $mirror > /dev/null 2>&1; then
            if [ "$UPDATE_MIRROR" != "y" ]; then
                echo "The mirror does not exit $mirror, not to create it, since UPDATE_MIRROR=$UPDATE_MIRROR" 1>&2
                exit 1
            fi
            WITH_SOURCES="-with-sources"
            [ "$dist" == "jessie" ] && WITH_SOURCES=""
            if [ "$component" != "amd64" ]; then
                current_url=$DEBIAN_MIRROR_URL
                [[ "$current_url" == *security* ]] && current_url=$DEBINA_SECURITY_MIRROR_URL
            fi
            aptly -config $APTLY_CONFIG -ignore-signatures -architectures="$archs" mirror create $WITH_SOURCES $mirror $url $dist $component
            SAVE_WORKSPACE=y
        fi
        repos="$repos $repo"
        if [ "$UPDATE_MIRROR" != "y" ]; then
            echo "Skip to update the mirror $mirror, UPDATE_MIRROR=$UPDATE_MIRROR"
            continue
        fi
        
        local success=n
        local has_error=n
        local retry=5
        for ((i=1;i<=$retry;i++)); do
            echo "Try to update the mirror, retry step $i of $retry"
            aptly -config $APTLY_CONFIG -ignore-signatures mirror update -max-tries=5 $mirror | tee $logfile
            if [ "$?" -eq "0" ]; then
                echo "Successfully update the mirror $mirror"
                success=y
                break
            else
                echo "Failed to update the mirror $mirror, sleep 10 seconds"
                sleep 10
                has_error=y
            fi
        done
        if [ "$success" != "y" ]; then
            echo "Failed to update the mirror $mirror" 1>&2
            exit 1
        fi
        if ! aptly -config $APTLY_CONFIG repo show $repo > /dev/null 2>&1; then
            aptly -config $APTLY_CONFIG repo create $repo
        elif [ "$has_error" == "n" ] && grep -q "Download queue: 0 items" $logfile; then
            continue
        fi
        need_to_publish=y
        aptly -config $APTLY_CONFIG repo import $mirror $repo 'Name (~ .*)'
    done

    echo "Start publish repos $dist need_to_publish=$need_to_publish IS_DIRTY_VERSION=$IS_DIRTY_VERSION"
    [ "$need_to_publish" == "y" ] && SAVE_WORKSPACE=y
    if [ "$need_to_publish" != "y" ] && [ "$IS_DIRTY_VERSION" == "n" ]; then
        echo "Skip publish repos $dist"
        return
    fi

    local options=
    [[ "$dist" == *-backports ]] && options="-notautomatic=yes -butautomaticupgrades=yes"

    echo "Publish repos: $repos"
    local publish_dist=$(echo $dist | tr / -)
    if ! aptly -config $APTLY_CONFIG publish show $dist $FILESYSTEM: > /dev/null 2>&1; then
        echo "aptly -config $APTLY_CONFIG publish repo $options -passphrase=*** -keyring=$GPG_FILE -distribution=$publish_dist -architectures=$archs -component=$components $repos $FILESYSTEM"
        aptly -config $APTLY_CONFIG publish repo $options -passphrase="$PASSPHRASE" -keyring=$GPG_FILE -distribution=$publish_dist -architectures=$archs -component=$components $repos $FILESYSTEM
    fi

    echo "Publish Repos=$repos publish_dist=$publish_dist"
    aptly -config $APTLY_CONFIG publish update -passphrase="$PASSPHRASE" -keyring=$GPG_FILE -skip-cleanup $publish_dist $FILESYSTEM
    if [ ! -z "$PUBLIS_FLAG" ]; then
      touch "$PUBLIS_FLAG"
    fi
}

prepare_workspace
for distribution in $(echo $MIRROR_DISTRIBUTIONS | tr ',' ' '); do
    echo "update repo for url=$MIRROR_URL name=$MIRROR_NAME distribution=$distribution architectures=$MIRROR_ARICHTECTURES components=$MIRROR_COMPONENTS"
    update_repo $MIRROR_NAME "$MIRROR_URL" $distribution "$MIRROR_ARICHTECTURES" "$MIRROR_COMPONENTS"
done
save_workspace
