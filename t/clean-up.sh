#!/bin/bash

dirs_to_clean=("11-test-clone"
               "12-test-clone-many-peers"
              )

for dir in ${dirs_to_clean[@]}
do
    if [ -d $dir ]
    then
        rm -r $dir
    fi
done

if [ -d log ]; then
    [ "$(ls -A log 2> /dev/null)" != "" ] &&\
        rm log/*
fi

if [ -f *.log ]; then
    rm *.log
fi

if [ -f peers.sqlite ]; then
    rm peers.sqlite
fi
