# Stage 1: Build the Expo/React Native Web app
FROM node:23-alpine AS build-env

WORKDIR /app

# Copy dependency files first to leverage Docker caching layers
COPY package*.json ./

# Install dependencies (including devDependencies needed for build)
RUN npm install

# Copy the rest of the frontend application code
COPY . .

# Build the progressive web application assets for the web platform
# This outputs compiled assets into the "/app/dist" directory
RUN npx expo export --platform web

# Stage 2: Serve using Nginx
FROM nginx:alpine

# Copy your existing custom Nginx routing config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the Expo static build output from Stage 1 to Nginx default public directory
COPY --from=build-env /app/dist /usr/share/nginx/html

# Adjust permissions for security stability
RUN chmod -R 755 /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
