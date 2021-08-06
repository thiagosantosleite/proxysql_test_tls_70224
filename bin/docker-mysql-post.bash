#!/bin/bash

MYSQL_ROOT_PASSWORD='root'

## wait for mysql start
until mysqladmin ping -h127.0.0.1 -P3301 -uroot -p$MYSQL_ROOT_PASSWORD --protocol=TCP ; do
   echo "servers starting, sleeping 5 seconds..."
   sleep 5s
done;

## setup replication
mysql  --protocol=TCP --host=127.0.0.1 --port=3301 -uroot -p$MYSQL_ROOT_PASSWORD -e "create user if not exists repl@'%' identified with mysql_native_password by 'repl'; grant replication slave on *.* to repl@'%'; show grants for repl@'%';";
mysql  --protocol=TCP --host=127.0.0.1 --port=3301 -uroot -p$MYSQL_ROOT_PASSWORD -e "create user john identified with mysql_native_password by 'john'; grant all on *.* to john;";
mysql  --protocol=TCP --host=127.0.0.1 --port=3301 -uroot -p$MYSQL_ROOT_PASSWORD -e "create user mary identified with mysql_native_password by 'mary'; grant all on *.* to mary;";

## setup monitor user
mysql  --protocol=TCP --host=127.0.0.1 --port=3301 -uroot -p$MYSQL_ROOT_PASSWORD -e "create user if not exists monitor@'%' identified by 'monitor'; GRANT REPLICATION CLIENT ON *.* TO monitor@'%';";

