
up:
	docker-compose up -d;
	@while [ -z "$$(docker logs server01 2>&1 | grep -o 'ready for connections')" ]; do sleep 5s; echo "starting mysql"; done;

configure:
	./create_pki.sh;
	docker cp pki/ca.pem server01:/var/lib/mysql/ca.pem;
	docker cp pki/ca-key.pem server01:/var/lib/mysql/ca-key.pem;
	docker cp pki/client.pem server01:/var/lib/mysql/client-cert.pem;
	docker cp pki/client-key.pem server01:/var/lib/mysql/client-key.pem;
	docker cp pki/server.pem server01:/var/lib/mysql/server-cert.pem;
	docker cp pki/server-key.pem server01:/var/lib/mysql/server-key.pem;
	docker exec server01 chown mysql:mysql /var/lib/mysql -R;
	#mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "set @@global.ssl_cipher=ECDHE_ECDSA_AES128_GCM_SHA256";
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "create user if not exists test identified with mysql_native_password require x509; grant all on *.* to test;"
	mysql -uroot -proot -P3301 --protocol=TCP --host=127.0.0.1 -e "ALTER INSTANCE RELOAD TLS"

test:
	mysql -utest -P3301 --protocol=TCP --verbose --ssl-cert=pki/client.pem --ssl-key=pki/client-key.pem --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -e "\s" | grep Cipher
	mysql -s -utest -P3301 --protocol=TCP --verbose --ssl-cert=pki/client.pem --ssl-key=pki/client-key.pem --ssl-ca=pki/ca.pem --ssl-cipher=ECDHE-ECDSA-AES128-GCM-SHA256 -e "SELECT * FROM performance_schema.session_status        WHERE VARIABLE_NAME IN ('Ssl_version','Ssl_cipher')"

clean:
	docker stop server01;
	docker rm server01;
	rm -rf pki/
	sudo rm -rf volumes/mysql/server01

logs:
	docker logs server01
