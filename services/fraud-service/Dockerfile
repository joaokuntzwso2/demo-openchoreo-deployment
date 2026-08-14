FROM node:22-alpine
WORKDIR /app
COPY services/lib ./lib
COPY services/fraud-service ./service
USER node
EXPOSE 8080
CMD ["node","service/server.js"]
