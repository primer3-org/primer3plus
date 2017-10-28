#!/bin/bash

chmod +x *.cgi

mkdir unafold_cache
mkdir statistics_files
mkdir error_files

chgrp www-data cached_data
chgrp www-data error_files
chgrp www-data statistics_files
chgrp www-data unafold_cache

chmod g+w cached_data
chmod g+w error_files
chmod g+w statistics_files
chmod g+w unafold_cache








