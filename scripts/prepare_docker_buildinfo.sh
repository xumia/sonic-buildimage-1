#!/bin/bash


AUTO_GENERATE_CODE_TEXT="Begin Auto-Generated Code"
DOCKERFILE=$1
DOCKERFILE_TARGE=$2
SET_ENV_PATH=y
[ ! -z $BUILD_SLAVE ] && SET_ENV_PATH=n

[ -z "$DOCKERFILE_TARGE" ] && DOCKERFILE_TARGE=$DOCKERFILE

if [ ! -f $DOCKERFILE_TARGE ] || ! grep -q "$AUTO_GENERATE_CODE_TEXT" $DOCKERFILE_TARGE; then
    # Insert the docker build script before the RUN command
    LINE_NUMBER=$(grep -Fn -m 1 'RUN' $DOCKERFILE | cut -d: -f1)
    DOCKERFILE_BEFORE_RUN_SCRIPT=$(generate_code="before_run" j2 files/build/templates/dockerfile_auto_generate.j2)
    TEMP_FILE=$(mktemp)
    awk -v text="${DOCKERFILE_BEFORE_RUN_SCRIPT}" -v linenumber=$LINE_NUMBER 'NR==linenumber{print text}1' $DOCKERFILE > $TEMP_FILE

    # Append the docker build script at the end of the docker file
    generate_code="after_run" set_env_path=$SET_ENV_PATH j2 files/build/templates/dockerfile_auto_generate.j2 >> $TEMP_FILE
    cat $TEMP_FILE > $DOCKERFILE_TARGE
    rm -f $TEMP_FILE
fi


DOCKERFILE_PATH=$(dirname "$DOCKERFILE_TARGE")
PACKAGE_URL_PREFIX=${PACKAGE_URL_PREFIX} scripts/copy_buildinfo.sh $DOCKERFILE_PATH
