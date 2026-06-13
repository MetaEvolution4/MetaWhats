FROM node:18-alpine

# Install openssl for Prisma
RUN apk add --no-cache openssl

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npx prisma generate
RUN npm run build

EXPOSE 3000

CMD ["npm", "run", "start:prod"]
