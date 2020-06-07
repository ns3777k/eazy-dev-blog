#!/bin/bash

hugo

rsync -avz --delete public/ eazy-dev:/var/www/blog

rm -rf public