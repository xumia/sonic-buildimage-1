#!/bin/bash
## This script is to automate the preparation for a docker image
## Usage:
##   sudo ./build_docker.sh DOCKER_IMAGE_GZ


set -x -e

DOCKER_IMAGE_TAG=docker-sswsyncd
DOCKER_BUILD_DIR=$DOCKER_IMAGE_TAG

## File name for docker image
docker_image_gz=$DOCKER_IMAGE_TAG.gz

[ -n "$docker_image_gz" ] || {
    echo "Error: Output docker image filename is empty"
    exit 1
}

function cleanup {
    rm -rf $DOCKER_BUILD_DIR/deps
    #sudo docker stop $DOCKER_IMAGE_TAG || true
    #sudo docker rm $DOCKER_IMAGE_TAG || true
    sudo docker rmi -f $DOCKER_IMAGE_TAG || true
}
trap cleanup exit

## Note Dockerfile ADD doesn't support reference files outside the folder, so copy it locally
mkdir -p $DOCKER_BUILD_DIR/deps
cp deps/*.deb $DOCKER_BUILD_DIR/deps
sudo docker build -t $DOCKER_IMAGE_TAG $DOCKER_BUILD_DIR
sudo docker save $DOCKER_IMAGE_TAG | gzip -c > $docker_image_gz
