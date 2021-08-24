all-ecdsa: create-pki-ecdsa build up spiffe copy configs reload
all-rsa: create-pki-rsa build up spiffe copy configs reload
all-tests: login-mysql login-proxysql login-proxysql-nossl login-proxysql-spiffe login-proxysql-spiffe-dns login-proxysql-old-pki

create-pki-ecdsa:
	./create_pki.sh ecdsa 256

create-pki-rsa:
	./create_pki.sh rsa 2048

build:
	docker-files/build.sh

up:
	docker-compose up -d;
	@while [ $$(docker logs server01 2>&1 | grep -c 'ready for connections') -lt 4 ]; do sleep 5s; echo "starting mysql"; done;

spiffe:
	TOKEN=$$(docker exec spire /spire/bin/spire-server token generate -spiffeID spiffe://example.org/host | awk '{print $$2}') && \
	echo "$$TOKEN" && \
	docker exec -d server01 /spire/bin/spire-agent run -joinToken $$TOKEN && \
    sleep 5s && \
	docker exec spire /spire/bin/spire-server entry create -parentID spiffe://example.org/host -spiffeID spiffe://example.org/workload -selector unix:user:mysql || \
	echo "already created spiffe://example.org/workload" && \
	docker exec spire /spire/bin/spire-server entry create -parentID spiffe://example.org/host -spiffeID spiffe://example.org/workload-proxysql -selector unix:user:mysql --dns proxysql.com || \
    echo "already created spiffe://example.org/workload-proxysql" && \
	sleep 10s && \
	docker exec server01 su mysql -c "/spire/bin/spire-agent api fetch x509 -write /tmp"
       
copy:
	docker cp server01:/tmp/svid.0.pem /tmp/svid.0.pem
	docker cp server01:/tmp/svid.0.key /tmp/svid.0.key
	docker cp server01:/tmp/bundle.0.pem /tmp/bundle.0.pem
	docker cp server01:/tmp/svid.1.pem /tmp/svid.1.pem
	docker cp server01:/tmp/svid.1.key /tmp/svid.1.key
	docker cp server01:/tmp/bundle.1.pem /tmp/bundle.1.pem
	csplit -s -z -f pki/individual- /tmp/svid.0.pem '/-----BEGIN CERTIFICATE-----/' '{*}';
	@if [ $$(grep "BEGIN CERTIFICATE" pki/ca.pem | wc -l ) -lt 2 ]; then cat pki/individual-01 pki/ca.pem >> pki/ca.pem.tmp && mv pki/ca.pem.tmp pki/ca.pem; fi;
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
	docker cp pki/client.pem proxysql01:/var/lib/proxysql/client-cert.pem
	docker cp pki/client-key.pem proxysql01:/var/lib/proxysql/client-key.pem
	docker exec proxysql01 chown proxysql:proxysql /var/lib/proxysql -R
	docker exec proxysql01 cat /var/lib/proxysql/proxysql-key.pem
	docker exec server01 cat /var/lib/mysql/ca-key.pem
	docker cp server01:/tmp/svid.0.pem /tmp/svid.0.pem
	docker cp server01:/tmp/svid.0.key /tmp/svid.0.key
	docker cp server01:/tmp/bundle.0.pem /tmp/bundle.0.pem
	docker cp server01:/tmp/svid.1.pem /tmp/svid.1.pem
	docker cp server01:/tmp/svid.1.key /tmp/svid.1.key
	docker cp server01:/tmp/bundle.1.pem /tmp/bundle.1.pem
	mkdir -p /tmp/old/
	test -f /tmp/old/svid.0.pem && echo "backup file /tmp/old/svid.0.pem already exists" || cp /tmp/svid.0.pem /tmp/old/svid.0.pem
	test -f /tmp/old/svid.0.key && echo "backup file /tmp/old/svid.0.key already exists" || cp /tmp/svid.0.key /tmp/old/svid.0.key

configs:
	#mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "set @@global.ssl_cipher=ECDHE_ECDSA_AES128_GCM_SHA256";
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists monitor identified with mysql_native_password by 'monitor'; grant replication client on *.* to monitor;"
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists test_mysql identified with mysql_native_password require x509; grant all on *.* to test_mysql;"
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists test_mysql_dns identified with mysql_native_password require x509; grant all on *.* to test_mysql_dns;"
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

login-proxysql-nossl:
	mysql -utest_proxysql -P6033 --protocol=TCP --verbose -ptest -e "\s" | grep Cipher

login-proxysql-spiffe:
	mysql -utest_mysql -P6033 --protocol=TCP --verbose --ssl-cert=/tmp/svid.0.pem --ssl-key=/tmp/svid.0.key --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -e "\s" | grep Cipher

login-proxysql-spiffe-dns:
	mysql -utest_mysql_dns -P6033 --protocol=TCP --verbose --ssl-cert=/tmp/svid.1.pem --ssl-key=/tmp/svid.1.key --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -e "\s" | grep Cipher

login-proxysql-old-pki:
	mysql -utest_mysql -P6033 --protocol=TCP --verbose --ssl-cert=/tmp/old/svid.0.pem --ssl-key=/tmp/old/svid.0.key -e "\s" | grep Cipher

clean:
	docker-compose stop;
	docker-compose rm -sf;
	rm -rf pki/;
	sudo rm -rf volumes/;
	rm /tmp/svid.[0-1]* || echo "ok"

logs-mysql:
	docker logs server01

logs-proxysql:
	docker logs proxysql01

logs-spire:
	docker logs spire

