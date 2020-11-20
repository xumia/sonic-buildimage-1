#!/bin/bash

BUILDINFO_PATH=/usr/local/share/buildinfo

LOG_PATH=$BUILDINFO_PATH/log
VERSION_PATH=$BUILDINFO_PATH/versions
PRE_VERSION_PATH=$BUILDINFO_PATH/pre-versions
DIFF_VERSION_PATH=$BUILDINFO_PATH/diff-versions
BUILD_VERSION_PATH=$BUILDINFO_PATH/build-versions
POST_VERSION_PATH=$BUILDINFO_PATH/post-versions
VERSION_DEB_PREFERENCE=$BUILDINFO_PATH/versions/01-versions-deb
WEB_VERSION_FILE=$VERSION_PATH/versions-web
BUILD_WEB_VERSION_FILE=$BUILD_VERSION_PATH/versions-web

. $BUILDINFO_PATH/config/buildinfo.config

URL_PREFIX=$(echo "${PACKAGE_URL_PREFIX}" | sed -E "s#(//[^/]*/).*#\1#")

log_err()
{
    echo "$1" >> $LOG_PATH/error.log
    echo "$1" 1>&2
}

check_version_control()
{
    if [[ ",$SONIC_VERSION_CONTROL_COMPONENTS," == *,all,* ]] || [[ ",$SONIC_VERSION_CONTROL_COMPONENTS," == *,$1,* ]]; then
        echo "y"
    else
        echo "n"
    fi
}

get_url_version()
{
    local package_url=$1
    /usr/bin/curl -ks $package_url | md5sum | cut -d' ' -f1
}

check_if_url_exist()
{
    local url=$1
    if /usr/bin/curl --output /dev/null --silent --head --fail "$1" > /dev/null 2>&1; then
        echo y
    else
        echo n
    fi
}

verify_and_set_proxy_url()
{
    local index=$1
    local url=$2
    local version=
    [ -f $WEB_VERSION_FILE ] && version=$(grep "^${url}=" $WEB_VERSION_FILE | awk -F"==" '{print $NF}')
    if [ "$ENABLE_VERSION_CONTROL_WEB" != y ]; then
        local real_version=$(get_url_version $url)
        mkdir -p $LOG_PATH > /dev/null 2>&1
        echo "$url==$real_version" >> ${BUILD_WEB_VERSION_FILE}
    else
        # When version control is enabled, check the version file, and set the proxy url
        # If the proxy is not ready, it will verify the version of the current url
        if [ -z "$version" ]; then
            echo "Failed to verify the package: $url, the version is not specified" 2>&1
            exit 1
        fi

        local filename=$(echo $url | awk -F"/" '{print $NF}' | cut -d? -f1 | cut -d# -f1)
        local version_filename="${filename}-${version}"
        local proxy_url="${PACKAGE_URL_PREFIX}/${version_filename}"
        local url_exist=$(check_if_url_exist $proxy_url)
        if [ "$url_exist" == y ]; then
            COMMAND_PARAMETERS[$index]=$proxy_url
        else
            local real_version=$(get_url_version $url)
            if [ "$real_version" != "$version" ]; then
                echo "Failed to verify url: $url, real hash value: $real_version, expected value: $version_filename" 1>&2
                exit 1
            fi
        fi
    fi
}

download_packages()
{
    COMMAND_PARAMETERS=("$@")
    for (( i=0; i<${#COMMAND_PARAMETERS[@]}; i++ ))
    do
        local para=${COMMAND_PARAMETERS[$i]}
        if [[ "$para" == *://* ]]; then
            verify_and_set_proxy_url $i "$para"
        fi
    done

    $REAL_COMMAND "${COMMAND_PARAMETERS[@]}"
}

run_pip_command()
{
    COMMAND_PARAMETERS=("$@")

    if [ ! -x "$REAL_COMMAND" ] && [ " $1" == "freeze" ]; then
        return 1
    fi

    if [ "$ENABLE_VERSION_CONTROL_PY" != "y" ]; then
        $REAL_COMMAND "$@"
        return $?
    fi

    local found=false
    local install=false
    local pip_version_file=$PIP_VERSION_FILE
    local tmp_version_file=$(mktemp)
    [ -f "$pip_version_file" ] && cp -f $pip_version_file $tmp_version_file
    for para in "${COMMAND_PARAMETERS[@]}"
    do
        ([ "$para" == "-c" ] || [ "$para" == "--constraint" ]) && found=true
        if [ "$para" == "install" ]; then
            install=true
        elif [[ "$para" == *.whl ]]; then
            package_name=$(echo $para | cut -d- -f1 | tr _ .)
            sed "/^${package_name}==/d" -i $tmp_version_file
        elif [[ "$para" != -* ]]; then
            package_name=$(echo $para | awk -F "[=><]" '{print $1}')
            if ! grep -q "${package_name}==" $tmp_version_file; then
                package_version=$(echo $para | awk -F "[=><]" '{for (i=1; i<NF; i++) {print $NF; break;}}')
                if [ -z "$package_version" ]; then
                    echo "Failed to install package: $package_name, the version is not specified." 1>&2
                    return 1
                fi
            fi
        fi
    done

    if [ "$found" == "false" ] && [ "$install" == "true" ]; then
        COMMAND_PARAMETERS+=("-c")
        COMMAND_PARAMETERS+=("${tmp_version_file}")
    fi

    $REAL_COMMAND "${COMMAND_PARAMETERS[@]}"
    local result=$?
    rm $tmp_version_file
    return $result
}

ENABLE_VERSION_CONTROL_DEB=$(check_version_control "deb")
ENABLE_VERSION_CONTROL_PY2=$(check_version_control "py2")
ENABLE_VERSION_CONTROL_PY3=$(check_version_control "py3")
ENABLE_VERSION_CONTROL_WEB=$(check_version_control "web")
ENABLE_VERSION_CONTROL_GIT=$(check_version_control "git")
ENABLE_VERSION_CONTROL_DOCKER=$(check_version_control "docker")
