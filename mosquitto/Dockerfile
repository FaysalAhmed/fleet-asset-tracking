FROM eclipse-mosquitto:2

COPY config/mosquitto.conf /mosquitto/config/mosquitto.conf
COPY config/acl.conf /mosquitto/config/acl.conf

RUN touch /mosquitto/config/passwords.txt && \
    mosquitto_passwd -b /mosquitto/config/passwords.txt bridge bridge123 && \
    mosquitto_passwd -b /mosquitto/config/passwords.txt gateway gateway123 && \
    mosquitto_passwd -b /mosquitto/config/passwords.txt admin admin123
