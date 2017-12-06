#!/bin/bash

crond -l 8 -L /root/cron.log
cd /root/kago.site
jekyll serve -H 0.0.0.0 -P 80 -w
