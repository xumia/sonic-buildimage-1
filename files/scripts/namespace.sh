#!/bin/bash

NS=$1
shift

sudo ip netns exec namespace$NS $@
