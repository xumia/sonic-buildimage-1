#!/bin/bash

IMAGENAME=$1
DOCKERFILE=$2
ARCH=$3
DOCKERFILE_TARGE=$4
DISTRO=$5

[ -z "$DOCKERFILE_TARGE" ] && DOCKERFILE_TARGE=$DOCKERFILE
DOCKERFILE_PATH=$(dirname "$DOCKERFILE_TARGE")
BUILDINFO_PATH="${DOCKERFILE_PATH}/buildinfo"
BUILDINFO_VERSION_PATH="${BUILDINFO_PATH}/versions"

[ -d $BUILDINFO_PATH ] && rm -rf $BUILDINFO_PATH
mkdir -p $BUILDINFO_VERSION_PATH

# Get the debian distribution from the docker base image
if [ -z "$DISTRO" ]; then
    DOCKER_BASE_IMAGE=$(grep "^FROM" $DOCKERFILE | head -n 1 | awk '{print $2}')
    DISTRO=$(docker run --rm --entrypoint "" $DOCKER_BASE_IMAGE cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2)
    [ -z "$DISTRO" ] && DISTRO=jessie
fi

DOCKERFILE_PRE_SCRIPT='# Auto-Generated for buildinfo 
COPY ["buildinfo", "/usr/local/share/buildinfo"]
ENV OLDPATH=$PATH
ENV PATH="/usr/local/share/buildinfo/scripts:$PATH"
RUN pre_run_buildinfo'

DOCKERFILE_POST_SCRIPT="RUN post_run_buildinfo"
[ "$BUILD_SLAVE" != "y" ] && DOCKERFILE_POST_SCRIPT="$DOCKERFILE_POST_SCRIPT
ENV PATH=\$OLDPATH"


# Add the auto-generate code if it is not added in the target Dockerfile
if [ ! -f $DOCKERFILE_TARGE ] || ! grep -q "Auto-Generated for buildinfo" $DOCKERFILE_TARGE; then
    # Insert the docker build script before the RUN command
    LINE_NUMBER=$(grep -Fn -m 1 'RUN' $DOCKERFILE | cut -d: -f1)
    TEMP_FILE=$(mktemp)
    awk -v text="${DOCKERFILE_PRE_SCRIPT}" -v linenumber=$LINE_NUMBER 'NR==linenumber{print text}1' $DOCKERFILE > $TEMP_FILE

    # Append the docker build script at the end of the docker file
    echo "RUN post_run_buildinfo" >> $TEMP_FILE
    [ "$BUILD_SLAVE" != "y" ] && echo "ENV PATH=\$OLDPATH" >> $TEMP_FILE

    cat $TEMP_FILE > $DOCKERFILE_TARGE
    rm -f $TEMP_FILE
fi

# Copy the build info config
cp -rf files/build/buildinfo/* $BUILDINFO_PATH

# Copy the docker build info scirpts
cp -rf files/build/scripts "${BUILDINFO_PATH}/"

# Build the slave running config
if [ "$BUILD_SLAVE" == "y" ]; then
    scripts/versions_manager.py generate -t "${BUILDINFO_PATH}/build/versions" -n "build-${IMAGENAME}" -d "$DISTRO" -a "$ARCH"
    touch ${BUILDINFO_PATH}/build/versions/versions-deb
fi

# Generate the version lock files
scripts/versions_manager.py generate -t "$BUILDINFO_VERSION_PATH" -n "$IMAGENAME" -d "$DISTRO" -a "$ARCH"

touch $BUILDINFO_VERSION_PATH/versions-deb
