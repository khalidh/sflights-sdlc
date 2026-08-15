FROM node:22-bookworm-slim AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json server.js ./
COPY db ./db
COPY srv ./srv
COPY app/travel/annotations.cds ./app/travel/annotations.cds
USER node
EXPOSE 4004
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD node -e "fetch('http://127.0.0.1:4004/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["npm", "start"]
