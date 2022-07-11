# Base image
FROM node:16-alpine as base

# Install all dependencies
FROM base as deps

WORKDIR /app

ADD ./package.json ./package-lock.json ./

RUN npm install

# Build with dev dependencies
FROM base as build

ENV NODE_ENV=production

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

ADD . .

RUN npm run build

# Serve static site
FROM pierrezemb/gostatic

COPY --from=build /app/dist/ /srv/http/

ENTRYPOINT ["/goStatic", "-port", "8080"]
