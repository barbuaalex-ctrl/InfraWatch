FROM node:24-bookworm-slim

WORKDIR /app

COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev

COPY app/backend ./backend
COPY app/frontend ./frontend
COPY app/agent ./agent

RUN mkdir -p backend/data && chown -R node:node /app

ENV NODE_ENV=production
ENV PORT=3000

USER node

EXPOSE 3000

CMD ["npm", "start"]
