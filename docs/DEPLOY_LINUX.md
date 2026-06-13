# Deploy on Linux

Este documento cobre os passos para colocar o backend do MetaWhats em produção usando um servidor Linux (Ubuntu) com Nginx e Docker Compose.

## 1. Preparação do Servidor

Conecte-se via SSH:
```bash
ssh root@seu_ip
```

Atualize o sistema e instale Docker:
```bash
apt update && apt upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
apt install docker-compose-plugin git nginx certbot python3-certbot-nginx -y
```

## 2. Clonando e Configurando o Projeto

```bash
git clone https://github.com/seu-usuario/metawhats.git /opt/metawhats
cd /opt/metawhats
```

Copie as variáveis e edite:
```bash
cp .env.example .env
nano .env
# Preencha JWT_SECRET forte, DOMINIO, etc.
```

## 3. Subindo os Containers

```bash
docker compose up -d --build
```
Isso fará o build do NestJS e subirá Postgres e Redis.

Rode as migrations e o seed:
```bash
docker compose exec backend npx prisma migrate deploy
docker compose exec backend npm run seed
```

## 4. Configuração do Nginx (Reverse Proxy)

Crie um arquivo de configuração para o domínio (ex: `api.metawhats.com`):

```bash
nano /etc/nginx/sites-available/metawhats
```

Conteúdo:
```nginx
server {
    listen 80;
    server_name api.metawhats.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Habilite e reinicie:
```bash
ln -s /etc/nginx/sites-available/metawhats /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

## 5. SSL / HTTPS com Certbot

```bash
certbot --nginx -d api.metawhats.com
```

Siga as instruções para forçar HTTPS. O WebSocket (`wss://`) utilizará automaticamente esta mesma rota.

## 6. Alternativa: Deploy com Coolify

Se estiver usando Coolify:
1. Adicione um novo recurso (Git Repository).
2. Selecione o Build Pack como `Docker Compose`.
3. Defina a porta exportada como `3000`.
4. Adicione as variáveis de ambiente necessárias no painel.
5. Adicione um volume persistente para `/app/uploads` e para os bancos.
6. Habilite o proxy reverso do Coolify, que gerencia os certificados SSL nativamente.
