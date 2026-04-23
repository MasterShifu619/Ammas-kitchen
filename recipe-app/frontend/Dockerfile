FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install --silent

COPY . .

# REACT_APP_API_URL is baked in at build time by create-react-app.
# Pass it as a build arg so docker build / CI can inject the correct value.
ARG REACT_APP_API_URL=""
ENV REACT_APP_API_URL=$REACT_APP_API_URL

RUN npm run build

FROM nginx:1.27-alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
