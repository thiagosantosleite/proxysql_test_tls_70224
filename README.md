**1) Create pki infrastrucuture**

You have 2 options, use RSA or EC keys (doesnt matter, proxysql and mysql supports both):

```
make create-pki-ecdsa

or

make create-pki-rsa
```


**2) Build Images**

- Mysql 8.0.26 with spire agent
- Proxysql with branch v2.x-ssl_no-rsa (tls rotation and ecdsa keys support)
- Spire server

```
make build
```


**3) Starts containers**

```
make up
```


**4) Configure spiffe**

Join spire agent in mysql node and create spiffe id spiffe://example.org/workload

```
make spiffe
```

**5) Copy certificates**

* copy ca, server and client certificates created in step 1 to mysql and proxysql 
* spire agent/server is using the same ca certificate to sign the new certificates, so using the same pki chain and both proxysql and mysql are able to verify it


```
make copy
```


**6) config MySQL and ProxySQL**

* Create the monitor user 
* create a test_mysql user with x509 authentication (this is the same user linked with spiffe id)
* create a test_proxysql user with authentication by password
* configure proxysql (with spiffe attribute for test_mysql user)

```
make configs
```

**7) reload certificates**

reload mysql and proxysql certificates

```
make reload
```

**8) Run tests**

* login-mysql - authenticate direct in mysql using test_mysql user, so not using spiffe only using the client certificates signed by same CA
* login-proxysql - authenticate in proxysql using the client certificates, but using a standard user with ssl enabled and password, using user test_proxysql
* login-proxysql-nossl - authenticate in proxysql not using any certificate, using user test_proxysql (still use ssl ???? looks like it fetches the server certificate, encrypt the connection, but I'm not sure if I'm connecting the trusted server, because the certficate is no verified)
* login-proxysql-spiffe - authenticate in proxysql using certificates and spiffe id with use test_mysql
* login-proxysql-spiffe-dns - authenticate in proxysql using certificates and spiffe id with user test_mysql, but this certificate have spiffe id and a DNS

```
make login-mysql
or
make login-proxysql
or
make login-proxysql-nossl
or
make login-proxysql-spiffe
or 
make login-proxysql-spiffe-dns
```


**View logs**

```
make logs-mysql
or
make logs-proxysql
or
make logs-spire
```


**Cleanup the environment**

```
make clean
```





**If you want simulate the issue with different chains:**
1) you can provision the environment following this guide
2) before cleanup make a copy of leaf certificates with spiffe:
/tmp/svid.0.key -> /tmp/old/svid.0.key
/tmp/svid.0.key -> /tmp/old/svid.0.key
3) cleanup the environment (make clean)
4) you can provision the environment following this guide again, so now the new env has a different pki infra from file in /tmp/old/
5) try to connect to proxysql using the old certificates

```
mysql -utest_mysql -P6033 --protocol=TCP --verbose --ssl-cert=/tmp/old/svid.0.pem --ssl-key=/tmp/old/svid.0.key -e "\s" | grep Cipher
```

