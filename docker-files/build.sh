cd docker-files
cp ../pki/ca.pem .
cp ../pki/ca-key.pem .
docker build -t proxysql:ssl -f Dockerfile-proxysql .
docker build -t spire:local -f Dockerfile-spire .
docker build -t mysql:local -f Dockerfile-mysql .
cd -
