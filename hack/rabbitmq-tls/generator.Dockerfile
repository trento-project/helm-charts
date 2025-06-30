FROM opensuse/tumbleweed

RUN zypper --non-interactive install curl tar make python3 python3-pip hostname

RUN curl -L https://github.com/rabbitmq/tls-gen/archive/efb3766277d99c6b8512f226351c7a62f492ef3f.tar.gz -o /tmp/tls-gen.tar.gz \
    && tar -xzf /tmp/tls-gen.tar.gz -C / \
    && mv /tls-gen-efb3766277d99c6b8512f226351c7a62f492ef3f /tls-gen \
    && rm /tmp/tls-gen.tar.gz

RUN mkdir /app 
WORKDIR /app
COPY generator /app/generator

RUN mkdir /output

ENV RELEASE_NAME=trento-server
CMD [ "sh", "-c",  "/app/generator /tls-gen/basic $RELEASE_NAME" ]
 