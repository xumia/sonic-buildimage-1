#!/bin/bash

TARGET_PATH=$1

[ -z $TARGET_PATH ] && TARGET_PATH=target

SLAVE_DOCKERS=$(ls -d sonic-slave-* )
for docker in $SLAVE_DOCKERS
do
    docker_tag=$(sha1sum $docker/Dockerfile | awk '{print substr($1,0,11);}')
    docker_image=$docker:$docker_tag
    scripts/collect_docker_version_files.sh $docker_image $TARGET_PATH
done


