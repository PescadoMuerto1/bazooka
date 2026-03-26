FROM node:22-slim AS base

WORKDIR /app

RUN npm install -g npm@11.11.0


FROM base AS builder

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build


FROM base AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

EXPOSE 3000

CMD ["node", "dist/index.js"]
