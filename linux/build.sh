#!/bin/bash

clang -c -O3 ../c/sokol.c -o sokol.a
clang -c -O3 ../c/dr_flac.c -o dr_flac.a