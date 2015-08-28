#!/bin/bash

if [ -d "11-test-clone" ]; then
    rm -r "11-test-clone"
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
