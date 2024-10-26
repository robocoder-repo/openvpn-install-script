#!/bin/bash

# Kiểm tra và cài đặt OpenVPN và Easy-RSA nếu chưa có
if ! command -v openvpn &> /dev/null || ! command -v easyrsa &> /dev/null; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install openvpn easy-rsa curl zip nginx -y
else
    echo "OpenVPN và Easy-RSA đã được cài đặt."
fi

# Tạo và cấu hình thư mục Easy-RSA
EASYRSA_DIR="/etc/openvpn/easy-rsa"
if [ ! -d "$EASYRSA_DIR" ]; then
    sudo mkdir -p "$EASYRSA_DIR"
    sudo cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR"
    sudo chown -R $USER:$USER "$EASYRSA_DIR"
fi

cd "$EASYRSA_DIR"

# Khởi tạo PKI và tạo chứng chỉ
sudo rm -rf pki
./easyrsa init-pki
echo "yes" | ./easyrsa build-ca nopass
./easyrsa gen-dh
echo "yes" | ./easyrsa build-server-full server nopass
openvpn --genkey --secret pki/ta.key

# Cấu hình máy chủ OpenVPN
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
sudo gunzip -f /etc/openvpn/server.conf.gz
sudo sed -i 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|' /etc/openvpn/server.conf
sudo sed -i 's|;user nobody|user nobody|' /etc/openvpn/server.conf
sudo sed -i 's|;group nogroup|group nogroup|' /etc/openvpn/server.conf
sudo sed -i "s|dh dh2048.pem|dh $EASYRSA_DIR/pki/dh.pem|" /etc/openvpn/server.conf
sudo sed -i "s|ca ca.crt|ca $EASYRSA_DIR/pki/ca.crt|" /etc/openvpn/server.conf
sudo sed -i "s|cert server.crt|cert $EASYRSA_DIR/pki/issued/server.crt|" /etc/openvpn/server.conf
sudo sed -i "s|key server.key|key $EASYRSA_DIR/pki/private/server.key|" /etc/openvpn/server.conf
sudo sed -i "s|tls-auth ta.key 0|tls-auth $EASYRSA_DIR/pki/ta.key 0|" /etc/openvpn/server.conf

# Khởi động dịch vụ OpenVPN
sudo systemctl start openvpn@server
if ! sudo systemctl is-active --quiet openvpn@server; then
    echo "Không thể khởi động dịch vụ OpenVPN. Kiểm tra log để biết thêm chi tiết:"
    sudo journalctl -xe --no-pager | tail -n 50
    echo "Trạng thái dịch vụ OpenVPN:"
    sudo systemctl status openvpn@server
else
    echo "Dịch vụ OpenVPN đã được khởi động thành công."
fi
sudo systemctl enable openvpn@server

# Tạo khóa cho khách hàng
echo "yes" | ./easyrsa build-client-full client1 nopass

# Xuất tệp client.ovpn với mật khẩu mặc định
SERVER_IP=$(curl -s ifconfig.me)
cat <<EOF > /root/client.ovpn
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-256-CBC
verb 3
auth-user-pass
key-direction 1

<ca>
$(cat pki/ca.crt)
</ca>
<cert>
$(cat pki/issued/client1.crt)
</cert>
<key>
$(cat pki/private/client1.key)
</key>
<tls-auth>
$(cat pki/ta.key)
</tls-auth>
EOF

# Tạo file auth.txt riêng biệt
cat <<EOF > /root/auth.txt
honglee
honglee@vpn
EOF

# Nén file client.ovpn và auth.txt
zip -P honglee@vpn /root/client.zip /root/client.ovpn /root/auth.txt

# Tạo thư mục cho OpenVPN files
sudo mkdir -p /var/www/html/openvpn

# Di chuyển file client.zip
sudo mv /root/client.zip /var/www/html/openvpn/

# Cấu hình Nginx để phục vụ file
sudo tee /etc/nginx/sites-available/openvpn <<EOF
server {
    listen 80;
    server_name _;
    
    location /openvpn/ {
        root /var/www/html;
        autoindex off;
    }
}
EOF

# Kích hoạt cấu hình Nginx
sudo ln -sf /etc/nginx/sites-available/openvpn /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# Tạo link tải HTTP
DOWNLOAD_LINK="http://$SERVER_IP/openvpn/client.zip"

echo "OpenVPN đã được cài đặt và cấu hình thành công."
echo "File client.ovpn và auth.txt đã được tạo và nén trong client.zip"
echo "Link tải file client.zip: $DOWNLOAD_LINK"
echo "Mật khẩu để giải nén file: honglee@vpn"
echo "Lưu ý: Sau khi giải nén, hãy đặt file auth.txt cùng thư mục với client.ovpn"

# Tải file client.zip về máy local
echo "Để tải file client.zip về máy local, sử dụng lệnh sau trên máy của bạn:"
echo "scp ubuntu@$SERVER_IP:/var/www/html/openvpn/client.zip ."
