# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

ENV FORCE_ROOT=1

WORKDIR /app
COPY . .
RUN find lib -name "*.dart" -exec sed -i 's/api-grocery/apigrocery/g' {} +
RUN flutter pub get
RUN flutter build web --release

RUN VERSION=$(date +%s) && \
    # 1. Main JS Entry points
    sed -i "s/flutter_bootstrap.js/flutter_bootstrap.js?v=$VERSION/g" build/web/index.html && \
    sed -i "s/main.dart.js/main.dart.js?v=$VERSION/g" build/web/flutter_bootstrap.js && \
    # 2. Manifests & Versioning (Crucial for assets/fonts)
    sed -i "s/AssetManifest.bin.json/AssetManifest.bin.json?v=$VERSION/g" build/web/flutter_bootstrap.js && \
    sed -i "s/FontManifest.json/FontManifest.json?v=$VERSION/g" build/web/flutter_bootstrap.js && \
    # 3. Visuals in index.html
    sed -i "s/favicon.png/favicon.png?v=$VERSION/g" build/web/index.html && \
    sed -i "s/manifest.json/manifest.json?v=$VERSION/g" build/web/index.html && \
    # 4. PWA Icons inside the manifest itself
    sed -i "s/\.png\"/.png?v=$VERSION\"/g" build/web/manifest.json

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
