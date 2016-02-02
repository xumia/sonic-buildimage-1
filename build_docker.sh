#!/bin/bash
## This script is to automate the preparation for docker images for ACS.
## If registry server and port provided, the images will be pushed there.
## Usage:
##   sudo ./build_docker.sh DOCKER_BUILD_DIR [REGISTRY_SERVER REGISTRY_PORT]

set -x -e

## Dockerfile directory
DOCKER_BUILD_DIR=$1
REGISTRY_SERVER=$2
REGISTRY_PORT=$3
REGISTRY_PASSWD=$4

[ -d "$DOCKER_BUILD_DIR" ] || {
    echo "Invalid DOCKER_BUILD_DIR directory" >&2
    exit 1
}

## Docker image tag
docker_image_tag=$DOCKER_BUILD_DIR

## File name for docker image
docker_image_gz=$docker_image_tag.gz

[ -n "$docker_image_gz" ] || {
    echo "Error: Output docker image filename is empty"
    exit 1
}

function cleanup {
    rm -rf $DOCKER_BUILD_DIR/deps
    docker rmi -f $docker_image_tag || true
}
trap cleanup exit

## Note Dockerfile ADD doesn't support reference files outside the folder, so copy it locally
mkdir -p $DOCKER_BUILD_DIR/deps
cp deps/*.deb $DOCKER_BUILD_DIR/deps
docker build -t $docker_image_tag $DOCKER_BUILD_DIR

if [ -n "$REGISTRY_SERVER" ] && [ -n "$REGISTRY_PORT" ]; then
    docker tag -f $docker_image_tag $REGISTRY_SERVER:$REGISTRY_PORT/$docker_image_tag
    ## Note: user name and password are passed from command line, use fake email address to bypass login check
    docker login -u acsadmin -p "$REGISTRY_PASSWD" -e "@" $REGISTRY_SERVER:$REGISTRY_PORT
    docker push $REGISTRY_SERVER:$REGISTRY_PORT/$docker_image_tag
fi

docker save $docker_image_tag | gzip -c > $docker_image_gz
