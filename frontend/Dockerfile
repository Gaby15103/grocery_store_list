# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

ENV FORCE_ROOT=1

WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
