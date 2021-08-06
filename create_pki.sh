mkdir pki

rm -rf *.csr
rm -rf *.pem
rm -rf *.json

cd pki

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "ProxySQL",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "BRA",
      "L": "Porto Alegre",
      "O": "ProxySQL",
      "OU": "CA",
      "ST": "Rio Grande Do Sul"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > server-csr.json <<EOF
{
  "CN": "server",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "BRA",
      "L": "Porto Alegre",
      "O": "proxysql",
      "OU": "proxysql ",
      "ST": "Rio Grande do Sul"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  server-csr.json | cfssljson -bare server

cat > client-csr.json <<EOF
{
  "CN": "client",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "BRA",
      "L": "Porto Alegre",
      "O": "proxysql",
      "OU": "proxysql ",
      "ST": "Rio Grande do Sul"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  client-csr.json | cfssljson -bare client

cd - 
