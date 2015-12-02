#!/bin/bash
## This script is to automate the preparation for a docker image

set -x -e

DOCKER_IMAGE_TAG=acs-docker-tag

## File name for docker image
docker_iamge_gz=acs-docker.gz

[ -n "$docker_iamge_gz" ] || {
    echo "Error: Invalid git revisions"
    exit 1
}

function cleanup {
    #sudo docker stop $DOCKER_IMAGE_TAG || true
    #sudo docker rm $DOCKER_IMAGE_TAG || true
    sudo docker rmi -f $DOCKER_IMAGE_TAG
}
trap cleanup exit

sudo docker build -t $DOCKER_IMAGE_TAG acs-docker
sudo docker save $DOCKER_IMAGE_TAG | gzip -c > $docker_iamge_gz

#gunzip -c $docker_iamge_gz | sudo docker load
#sudo docker run -it --name $DOCKER_IMAGE_TAG -v /home:/home $DOCKER_IMAGE_TAG /bin/bash
