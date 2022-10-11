FROM node:16
RUN mkdir /opt/app
WORKDIR /opt/app
COPY app/index.js app/package.json app/package-lock.json ./
RUN npm install
ENTRYPOINT ["node", "index.js"]
