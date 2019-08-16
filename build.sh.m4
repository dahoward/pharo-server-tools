#!/bin/bash

script_home=$(dirname $0)
script_home=$(cd $script_home && pwd)
echo "Running from $script_home"

vm=$script_home/../bin/pharo

builddir=$script_home/_SERVICE_NAME_-$(date +%Y%d%m%H%M)
mkdir -p $builddir

image=$script_home/_IMAGE_NAME_.image
$vm $script_home/Pharo.image save $builddir/_IMAGE_NAME_

# Start SSH agent and add private key(s) for git authentication
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(/usr/bin/ssh-agent)
fi
/usr/bin/ssh-add

cat << EOF > $builddir/run-build.st
Metacello new
    repository: 'github://objectguild/NeoConsole:master';
    baseline: 'NeoConsole';
    load.
Metacello new
    repository: '_CONFIG_REPO_';
    baseline: '_CONFIG_BASELINE_';
    onWarningLog;
    onConflictUseLoaded;
    load: '_CONFIG_GROUP_'.
EOF

cp Pharo*.sources $builddir/

cd $builddir
$vm $image st --save --quit $builddir/run-build.st > $builddir/build.log 2>&1
cd $script_home

# Kill SSH agent started earlier
eval $(/usr/bin/ssh-agent -k)

cat << EOF > $builddir/deploy.sh
read -r -p "You are about to deploy this build to ~/pharo/_SERVICE_NAME_?\n This will overwrite the .image and .changes files, and the pharo-local/ directory.\n Continue? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo Removing ~/pharo/_SERVICE_NAME_/pharo-local/ directory
    rm -rf ~/pharo/_SERVICE_NAME_/pharo-local
    echo Copying pharo-local/ directory
    cp -r pharo-local ~/pharo/_SERVICE_NAME_/
    echo Copying .image and .changes files
    cp -v _IMAGE_NAME_.* ~/pharo/_SERVICE_NAME_/
    echo Done.
else
    echo Cancelled.
fi
EOF