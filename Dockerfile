# Wrapper image: takes the Mendix sample image baked into ACR and overlays a
# release banner so each commit produces a visibly-different deploy.
ARG BASE_IMAGE=acromnixl7yf2e.azurecr.io/omnix-mendix:mx-v3
FROM ${BASE_IMAGE}

ARG APP_VERSION=dev
ARG GIT_SHA=local
ARG BUILD_TIMESTAMP=unknown
ENV APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    BUILD_TIMESTAMP=${BUILD_TIMESTAMP}

# Copy the static release page into the document root the Mendix sample serves
COPY app/release.html /opt/mendix/build/web/release.html
COPY app/release.json /opt/mendix/build/web/release.json
COPY app/banner.html  /opt/mendix/build/web/banner.html

# Replace placeholders with build-time values
USER root
RUN sed -i "s|__APP_VERSION__|${APP_VERSION}|g; s|__GIT_SHA__|${GIT_SHA}|g; s|__BUILD_TIMESTAMP__|${BUILD_TIMESTAMP}|g" \
        /opt/mendix/build/web/release.html /opt/mendix/build/web/release.json /opt/mendix/build/web/banner.html
