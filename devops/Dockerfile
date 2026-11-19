FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev

COPY app/backend ./backend
COPY app/frontend ./frontend
COPY app/agent ./agent
COPY devops/healthcheck.py ./healthcheck.py

RUN mkdir -p backend/data && chown -R node:node /app

ENV NODE_ENV=production
ENV PORT=3000

USER node

EXPOSE 3000

CMD ["npm", "start"]