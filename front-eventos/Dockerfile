# Etapa 1: compilar el front de React (Vite deja los archivos en dist/)
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# Ruta relativa: el front le pega a /api del mismo lugar que lo sirvió (el balanceador de la PC 1, o el nginx de este contenedor)
ENV VITE_API_URL=/api
RUN npm run build

# Etapa 2: solo los archivos compilados, servidos con nginx (sin node_modules ni el código fuente).
# nginx además pasa /api/ a la api de esta PC: así se puede entrar a cada PC por su IP
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
