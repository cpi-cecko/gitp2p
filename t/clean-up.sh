#!/bin/bash

if [ -d test-users ]; then
    rm -r test-users
fi

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
