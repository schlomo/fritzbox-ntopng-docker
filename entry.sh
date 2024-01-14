#!/bin/bash
redis-server </dev/null &
exec ntopng "$@"
