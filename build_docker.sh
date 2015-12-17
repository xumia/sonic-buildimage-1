#!/bin/bash
## This script is to automate the preparation for a docker image
## Usage:
##   sudo ./build_docker.sh DOCKER_BUILD_DIR


set -x -e

## Dockerfile directory
DOCKER_BUILD_DIR=$1

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
docker save $docker_image_tag | gzip -c > $docker_image_gz
