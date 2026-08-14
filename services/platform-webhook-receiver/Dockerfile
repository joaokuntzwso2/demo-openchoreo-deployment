FROM node:22-alpine
WORKDIR /app
COPY services/platform-webhook-receiver/server.js ./server.js
USER node
EXPOSE 18081
CMD ["node","server.js"]
