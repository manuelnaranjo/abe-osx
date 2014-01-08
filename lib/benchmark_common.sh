
SRC_PATH=~/Downloads
PASSWORD_FILE=~/password

MACHINE=`uname -m`
TOP=`pwd`
NPROCESSORS=`getconf _NPROCESSORS_ONLN`
PARALLEL="-j$NPROCESSORS"
CHECK_PARALLEL=$PARALLEL
CCAT="ccrypt -k $PASSWORD_FILE -c"

# Cross compiler prefix such as arm-linux-gnueabi-
CROSS_COMPILE=
