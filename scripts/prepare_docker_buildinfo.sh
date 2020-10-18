#!/bin/bash

DOCKERFILE=$1
ARCH=$2
DOCKERFILE_TARGE=$3
DISTRO=$4

[ -z "$DOCKERFILE_TARGE" ] && DOCKERFILE_TARGE=$DOCKERFILE
DOCKERFILE_PATH=$(dirname "$DOCKERFILE_TARGE")
BUILDINFO_PATH="${DOCKERFILE_PATH}/buildinfo"
BUILDINFO_VERSION_PATH="${BUILDINFO_PATH}/versions"
BUILDINFO_CONFIG=$BUILDINFO_PATH/scripts/buildinfo.config

AUTO_GENERATE_CODE_TEXT="Begin Auto-Generated Code"
DOCKERFILE_TEMPLATE="files/build/templates/dockerfile_auto_generate.j2"
[ -d $BUILDINFO_PATH ] && rm -rf $BUILDINFO_PATH
mkdir -p $BUILDINFO_VERSION_PATH

# Get the debian distribution from the docker base image
if [ -z "$DISTRO" ]; then
    DOCKER_BASE_IMAGE=$(grep "^FROM" $DOCKERFILE | head -n 1 | awk '{print $2}')
    DISTRO=$(docker run --rm --entrypoint "" $DOCKER_BASE_IMAGE cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2)
    [ -z "$DISTRO" ] && DISTRO=jessie
fi

# Add the auto-generate code if it is not added in the target Dockerfile
if [ ! -f $DOCKERFILE_TARGE ] || ! grep -q "$AUTO_GENERATE_CODE_TEXT" $DOCKERFILE_TARGE; then
    # Insert the docker build script before the RUN command
    LINE_NUMBER=$(grep -Fn -m 1 'RUN' $DOCKERFILE | cut -d: -f1)
    DOCKERFILE_BEFORE_RUN_SCRIPT=$(generate_code="before_run" j2 $DOCKERFILE_TEMPLATE)
    TEMP_FILE=$(mktemp)
    awk -v text="${DOCKERFILE_BEFORE_RUN_SCRIPT}" -v linenumber=$LINE_NUMBER 'NR==linenumber{print text}1' $DOCKERFILE > $TEMP_FILE

    # Append the docker build script at the end of the docker file
    SET_ENV_PATH=y
    [ ! -z $BUILD_SLAVE ] && SET_ENV_PATH=n
    generate_code="after_run" set_env_path=$SET_ENV_PATH j2 $DOCKERFILE_TEMPLATE >> $TEMP_FILE

    cat $TEMP_FILE > $DOCKERFILE_TARGE
    rm -f $TEMP_FILE
fi

# Copy the build info config
cp -rf files/build/buildinfo/* $BUILDINFO_PATH

# Copy the docker build info scirpts
cp -rf files/build/scripts "${BUILDINFO_PATH}/"

# Generate the version lock files
scripts/versions_manager.py generate -t "$BUILDINFO_VERSION_PATH" -m "$DOCKERFILE_PATH" -d "$DISTRO" -a "$ARCH"
