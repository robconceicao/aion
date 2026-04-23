# Stage 1: Build Flutter Web
FROM debian:latest AS build-env

RUN apt-get update && apt-get install -y curl git wget unzip python3 libglu1-mesa

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run flutter doctor and pre-download binaries
RUN flutter doctor -v
RUN flutter config --enable-web

# Copy project files
WORKDIR /app
COPY . .

# Build for Web
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
