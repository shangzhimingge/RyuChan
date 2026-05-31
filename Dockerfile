# Stage 1: Build
FROM node:22-alpine AS builder

RUN apk add --no-cache python3 g++ make

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV COREPACK_ENABLE_STRICT=0
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml .npmrc ./

COPY .npmrc ./
RUN pnpm approve-builds --global esbuild sharp swup unrs-resolver workerd sass-embedded && pnpm install --frozen-lockfile

COPY . .

ARG PUBLIC_GITHUB_OWNER
ARG PUBLIC_GITHUB_REPO
ARG PUBLIC_GITHUB_BRANCH
ARG PUBLIC_GITHUB_APP_ID
ARG PUBLIC_GITHUB_ENCRYPT_KEY

ENV PUBLIC_GITHUB_OWNER=${PUBLIC_GITHUB_OWNER}
ENV PUBLIC_GITHUB_REPO=${PUBLIC_GITHUB_REPO}
ENV PUBLIC_GITHUB_BRANCH=${PUBLIC_GITHUB_BRANCH}
ENV PUBLIC_GITHUB_APP_ID=${PUBLIC_GITHUB_APP_ID}
ENV PUBLIC_GITHUB_ENCRYPT_KEY=${PUBLIC_GITHUB_ENCRYPT_KEY}

RUN pnpm build

# Stage 2: Serve
FROM nginx:alpine AS runtime

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/dist /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
