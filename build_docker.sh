#!/bin/bash
## This script is to automate the preparation for a docker image
## Usage:
##   sudo ./build_docker.sh DOCKER_IMAGE_GZ


set -x -e

DOCKER_IMAGE_TAG=acs-docker-tag

## File name for docker image
docker_image_gz=acs-docker.gz

[ -n "$docker_image_gz" ] || {
    echo "Error: Outut docker image filename is empty"
    exit 1
}

function cleanup {
    rm -rf acs-docker/deps
    #sudo docker stop $DOCKER_IMAGE_TAG || true
    #sudo docker rm $DOCKER_IMAGE_TAG || true
    sudo docker rmi -f $DOCKER_IMAGE_TAG || true
}
trap cleanup exit

## Note Dockerfile ADD doesn't support reference files outside the folder, so copy it locally
mkdir -p acs-docker/deps
cp deps/*.deb acs-docker/deps
sudo docker build -t $DOCKER_IMAGE_TAG acs-docker
sudo docker save $DOCKER_IMAGE_TAG | gzip -c > $docker_image_gz

## Delete all docker images
#sudo docker rmi `sudo docker images -aq`
## Delete all exited docker containers
#sudo docker rm `sudo docker ps -a | grep Exited | awk '{print $1 }'`
## Load docker iamge from file
#gunzip -c $docker_image_gz | sudo docker load
## Run the docker image in a container
#sudo docker run --privileged --net=host -it --name $DOCKER_IMAGE_TAG -v /home:/home $DOCKER_IMAGE_TAG /bin/bash
