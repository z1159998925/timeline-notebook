#!/bin/bash

# SSL证书配置脚本
# 支持Let's Encrypt和自签名证书两种方式

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 创建SSL目录
create_ssl_dir() {
    log_info "创建SSL证书目录..."
    mkdir -p /etc/nginx/ssl
    chmod 700 /etc/nginx/ssl
}

# 安装certbot（Let's Encrypt）
install_certbot() {
    log_info "安装certbot..."
    
    # 检测操作系统
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y epel-release
        yum install -y certbot
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y certbot
    else
        log_error "不支持的操作系统"
        exit 1
    fi
}

# 生成Let's Encrypt证书
generate_letsencrypt_cert() {
    local domain=$1
    local email=$2
    
    log_info "为域名 $domain 生成Let's Encrypt证书..."
    
    # 停止nginx（如果正在运行）
    if systemctl is-active --quiet nginx; then
        log_info "停止nginx服务..."
        systemctl stop nginx
    fi
    
    # 生成证书
    certbot certonly --standalone \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        --domains "$domain"
    
    # 复制证书到nginx目录
    cp "/etc/letsencrypt/live/$domain/fullchain.pem" /etc/nginx/ssl/
    cp "/etc/letsencrypt/live/$domain/privkey.pem" /etc/nginx/ssl/
    
    # 设置权限
    chmod 644 /etc/nginx/ssl/fullchain.pem
    chmod 600 /etc/nginx/ssl/privkey.pem
    
    log_info "Let's Encrypt证书生成完成"
}

# 生成自签名证书
generate_selfsigned_cert() {
    local domain=$1
    
    log_info "为域名 $domain 生成自签名证书..."
    
    # 生成私钥
    openssl genrsa -out /etc/nginx/ssl/privkey.pem 2048
    
    # 生成证书
    openssl req -new -x509 -key /etc/nginx/ssl/privkey.pem \
        -out /etc/nginx/ssl/fullchain.pem -days 365 \
        -subj "/C=CN/ST=State/L=City/O=Organization/CN=$domain"
    
    # 设置权限
    chmod 644 /etc/nginx/ssl/fullchain.pem
    chmod 600 /etc/nginx/ssl/privkey.pem
    
    log_info "自签名证书生成完成"
    log_warn "注意：自签名证书会在浏览器中显示安全警告"
}

# 设置证书自动续期（仅适用于Let's Encrypt）
setup_auto_renewal() {
    log_info "设置证书自动续期..."
    
    # 创建续期脚本
    cat > /etc/cron.daily/certbot-renew << 'EOF'
#!/bin/bash
/usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
    
    chmod +x /etc/cron.daily/certbot-renew
    log_info "证书自动续期设置完成"
}

# 主函数
main() {
    echo "=== SSL证书配置脚本 ==="
    echo "1. Let's Encrypt证书（推荐，免费）"
    echo "2. 自签名证书（测试用）"
    echo
    
    read -p "请选择证书类型 (1/2): " cert_type
    
    case $cert_type in
        1)
            read -p "请输入域名: " domain
            read -p "请输入邮箱地址: " email
            
            if [[ -z "$domain" || -z "$email" ]]; then
                log_error "域名和邮箱地址不能为空"
                exit 1
            fi
            
            check_root
            create_ssl_dir
            install_certbot
            generate_letsencrypt_cert "$domain" "$email"
            setup_auto_renewal
            ;;
        2)
            read -p "请输入域名（或IP地址）: " domain
            
            if [[ -z "$domain" ]]; then
                log_error "域名不能为空"
                exit 1
            fi
            
            check_root
            create_ssl_dir
            generate_selfsigned_cert "$domain"
            ;;
        *)
            log_error "无效选择"
            exit 1
            ;;
    esac
    
    log_info "SSL证书配置完成！"
    log_info "请确保在docker-compose.yml中正确挂载SSL证书目录"
    log_info "证书路径：/etc/nginx/ssl/"
}

# 运行主函数
main "$@"