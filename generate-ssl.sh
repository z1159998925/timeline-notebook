#!/bin/bash

# 生成自签名SSL证书脚本
# 用于开发和测试环境

echo "🔐 生成自签名SSL证书..."

# 创建SSL目录
mkdir -p ssl nginx/ssl

# 生成私钥
echo "🔑 生成私钥..."
openssl genrsa -out ssl/key.pem 2048
openssl genrsa -out nginx/ssl/key.pem 2048

# 生成证书签名请求配置
cat > ssl/cert.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=CN
ST=Beijing
L=Beijing
O=Timeline Notebook
OU=Development
CN=localhost

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# 生成自签名证书
echo "📜 生成自签名证书..."
openssl req -new -x509 -key ssl/key.pem -out ssl/cert.pem -days 365 -config ssl/cert.conf -extensions v3_req
openssl req -new -x509 -key nginx/ssl/key.pem -out nginx/ssl/cert.pem -days 365 -config ssl/cert.conf -extensions v3_req

# 设置权限
chmod 600 ssl/key.pem nginx/ssl/key.pem
chmod 644 ssl/cert.pem nginx/ssl/cert.pem

echo "✅ SSL证书生成完成！"
echo "📁 证书位置:"
echo "  - ssl/cert.pem"
echo "  - ssl/key.pem"
echo "  - nginx/ssl/cert.pem"
echo "  - nginx/ssl/key.pem"

echo "⚠️ 注意: 这是自签名证书，仅用于开发测试"
echo "💡 生产环境请使用正式的SSL证书"