# Liten basimage med webbservern nginx färdiginstallerad
FROM nginx:1.27-alpine

# Lägg formuläret där nginx letar efter startsidan
COPY index.html /usr/share/nginx/html/index.html

# Konfigurationen som byter __FUNC_URL__ mot funktionens adress vid start
COPY default.conf.template /etc/nginx/templates/default.conf.template

# Containern lyssnar på port 80
EXPOSE 80

# Starta nginx i förgrunden, annars avslutas containern direkt
CMD ["nginx", "-g", "daemon off;"]
