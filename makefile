up:
	docker-compose up -d;
	@while [ -z "$$(docker logs server01 2>&1 | grep -o 'ready for connections')" ]; do sleep 5s; echo "starting mysql"; done;

create-pki-ecdsa:
	./create_pki.sh ecdsa 256

create-pki-rsa:
	./create_pki.sh rsa 2048

copy:
	docker cp pki/ca.pem server01:/var/lib/mysql/ca.pem;
	docker cp pki/ca-key.pem server01:/var/lib/mysql/ca-key.pem;
	docker cp pki/client.pem server01:/var/lib/mysql/client-cert.pem;
	docker cp pki/client-key.pem server01:/var/lib/mysql/client-key.pem;
	docker cp pki/server.pem server01:/var/lib/mysql/server-cert.pem;
	docker cp pki/server-key.pem server01:/var/lib/mysql/server-key.pem;
	docker exec server01 chown mysql:mysql /var/lib/mysql -R
	docker cp pki/ca.pem proxysql01:/var/lib/proxysql/proxysql-ca.pem
	docker cp pki/server.pem proxysql01:/var/lib/proxysql/proxysql-cert.pem
	docker cp pki/server-key.pem proxysql01:/var/lib/proxysql/proxysql-key.pem
	docker exec proxysql01 chown proxysql:proxysql /var/lib/proxysql -R
	docker exec proxysql01 cat /var/lib/proxysql/proxysql-key.pem
	docker exec server01 cat /var/lib/mysql/ca-key.pem

configs:
	#mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "set @@global.ssl_cipher=ECDHE_ECDSA_AES128_GCM_SHA256";
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists monitor identified with mysql_native_password by 'monitor'; grant replication client on *.* to monitor;"
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists test_mysql identified with mysql_native_password require x509; grant all on *.* to test_mysql;"
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists test_proxysql identified with mysql_native_password by 'test'; grant all on *.* to test_proxysql;"
	mysql -uradmin -pradmin -P6032 --protocol=TCP --host=127.0.0.1 < config/proxysql/conf.sql

reload:
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "ALTER INSTANCE RELOAD TLS"
	mysql -uradmin -pradmin -P6032 --protocol=TCP --host=127.0.0.1 -e "PROXYSQL RELOAD TLS"
	
login-mysql:
	mysql -utest_mysql -P3301 --protocol=TCP --verbose --ssl-cert=pki/client.pem --ssl-key=pki/client-key.pem --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -e "\s" | grep Cipher
	mysql -s -utest_mysql -P3301 --protocol=TCP --verbose --ssl-cert=pki/client.pem --ssl-key=pki/client-key.pem --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -e "SELECT * FROM performance_schema.session_status        WHERE VARIABLE_NAME IN ('Ssl_version','Ssl_cipher')"

login-proxysql:
	mysql -utest_proxysql -P6033 --protocol=TCP --verbose --ssl-cert=pki/client.pem --ssl-key=pki/client-key.pem --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -ptest -e "\s" | grep Cipher
	mysql -s -utest_proxysql -P6033 --protocol=TCP --verbose --ssl-cert=pki/client.pem --ssl-key=pki/client-key.pem --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -ptest -e "SELECT * FROM performance_schema.session_status        WHERE VARIABLE_NAME IN ('Ssl_version','Ssl_cipher')"

login-proxysql-nossl:
	mysql -utest_proxysql -P6033 --protocol=TCP --verbose -ptest -e "\s" | grep Cipher
	mysql -s -utest_proxysql -P6033 --protocol=TCP --verbose -ptest -e "SELECT * FROM performance_schema.session_status        WHERE VARIABLE_NAME IN ('Ssl_version','Ssl_cipher')"


clean:
	docker-compose stop;
	docker-compose rm -sf;
	rm -rf pki/;
	sudo rm -rf volumes/

logs-mysql:
	docker logs server01

logs-proxysql:
	docker logs proxysql01
