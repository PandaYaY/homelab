# The `upstream` directives ensure that you have a http/1.1 connection
# This enables the keepalive option and better performance
#
# Define the server IP and ports here.
upstream vaultwarden-default {
  zone vaultwarden-default 64k;
  server 127.0.0.1:8080;
  keepalive 2;
}

# Needed to support websocket connections
# See: https://nginx.org/en/docs/http/websocket.html
# Instead of "close" as stated in the above link we send an empty value.
# Else all keepalive connections will not work.
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      "";
}

server {
    # For older versions of nginx appended http2 to the listen line after ssl and remove `http2 on`
    http2 on;
    server_name vaultwarden.nyaners.ru;

    client_max_body_size 525M;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    location / {
      proxy_pass http://vaultwarden-default;
    }

    # Optionally add extra authentication besides the ADMIN_TOKEN
    # Remove the comments below `#` and create the htpasswd_file to have it active

    location /admin {
      # See: https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/
      satisfy any;

      allow 127.0.0.1;
      allow 192.168.1.0/24;
      deny all;

      auth_basic "Private";
      auth_basic_user_file /etc/nginx/.htpasswd;

      proxy_pass http://vaultwarden-default;
    }

    listen [::]:443 ssl;
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/vaultwarden.nyaners.ru/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/vaultwarden.nyaners.ru/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}


server {
    if ($host = vaultwarden.nyaners.ru) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    server_name vaultwarden.nyaners.ru;
    listen 80;
    return 404; # managed by Certbot
}
