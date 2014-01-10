#!/bin/sh

echo "Shutting down redis..."
launchctl stop homebrew.mxcl.redis

echo "Removing dump.db"
rm /usr/local/var/db/redis/dump.rdb

echo "This is what is left, should be blank"
ls -l /usr/local/var/db/redis

echo "Restarting redis"
launchctl start homebrew.mxcl.redis
