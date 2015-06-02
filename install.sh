#!/bin/sh

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -e

echo "Symlink git-remote-gitp2p"
ln -s "$DIR/git-remote-gitp2p" "/usr/local/bin/git-remote-gitp2p"
echo "Symlink lib"
ln -s "$DIR/lib" "/usr/local/bin/lib"
