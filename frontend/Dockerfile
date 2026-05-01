# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

ENV FORCE_ROOT=1

WORKDIR /app
COPY . .
RUN find lib -name "*.dart" -exec sed -i 's/api-grocery/apigrocery/g' {} +
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve
FROM nginx:alpine

# Copy the custom config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the build output
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Set permissions
RUN chmod -R 755 /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
