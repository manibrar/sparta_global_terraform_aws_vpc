#!/bin/bash

export LC_ALL=c
cd /home/ubuntu/app
npm install
export DB_HOST=${db_host}
pm2 start app.js
