#!/bin/bash
set -x

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MOUNT_PATH=$(echo ${SCRIPT_DIR%/*})

docker run --rm -v ${MOUNT_PATH}:/home/appuser/scripts/workdir/apps/app-httpreply bdspro