ALGO=$1
SIZE=$2

test -d pki || mkdir -p pki

rm -rf *.csr
rm -rf *.pem
rm -rf *.json

cd pki
test -f "cfssljson" || wget -O cfssljson -q --show-progress --https-only --timestamping https://github.com/cloudflare/cfssl/releases/download/v1.6.0/cfssljson_1.6.0_linux_amd64
test -f "cfssl" || wget -O cfssl -q --show-progress --https-only --timestamping https://github.com/cloudflare/cfssl/releases/download/v1.6.0/cfssl_1.6.0_linux_amd64
chmod +x cfssljson cfssl

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
    "algo": "$ALGO",
    "size": $SIZE
  },
  "names": [
    {
      "C": "US",
      "L": "",
      "ST": "",
      "O": "SPIFFE",
      "OU": "",
      "CN": ""
    }
  ]
}
EOF

./cfssl gencert -initca ca-csr.json | cfssljson -bare ca


cat > server-csr.json <<EOF
{
  "CN": "server",
  "key": {
    "algo": "$ALGO",
    "size": $SIZE
  },
  "names": [
    {
      "C": "US",
      "L": "",
      "ST": "",
      "O": "SPIFFE",
      "OU": "",
      "CN": ""
    }
  ],
  "hosts": [ 
     "spiffe://local"
  ]
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  server-csr.json | cfssljson -bare server

cat > client-csr.json <<EOF
{
  "CN": "client",
  "key": {
    "algo": "$ALGO",
    "size": $SIZE
  },
  "names": [
    {
      "C": "US",
      "L": "",
      "ST": "",
      "O": "SPIFFE",
      "OU": "",
      "CN": ""
    }
  ],  
  "hosts": [ 
     "spiffe://local-client"
  ] 
}
EOF

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  client-csr.json | cfssljson -bare client

cd - 
