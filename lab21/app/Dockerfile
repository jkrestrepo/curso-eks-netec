# Use the official NGINX base image
FROM nginx:alpine

# Remove the default index.html
RUN rm /usr/share/nginx/html/index.html

# Copy your custom index.html into the container
COPY index.html /usr/share/nginx/html/

# Expose port 80
EXPOSE 80