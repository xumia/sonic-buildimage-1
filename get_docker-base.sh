#!/bin/bash
## This script is to retrieve and import the docker-base image from
## local folder where the image is built on the local machine
##
## USAGE:
##   ./get_deps.sh

set -x -e

. ./functions.sh

BASE_URL="https://acsbe.blob.core.windows.net/vmimages/docker-base.ea507753d98b0769e2a15be13003331f8ad38d1c15b40a683e05fc53b1463b10.gz?sv=2014-02-14&sr=c&sig=5LDHYs3TU4%2FiHcM7RzqQiksyy7Jv7zQu440RtNOTU80%3D&se=2116-02-06T22%3A19%3A22Z&sp=rwdl"

base_image_name=docker-base
docker_try_rmi $base_image_name
curl "$BASE_URL" | docker load
