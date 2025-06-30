# Generate TLS certificates for RabbitMQ

Generates certificates for RabbitMQ TLS using the official generator tool. Certificates are meant to be used for development and QA.
Please refere to the [official documentation](https://www.rabbitmq.com/docs/ssl#automated-certificate-generation-transcript).

## Usage

```sh
docker build -f ./hack/rabbitmq-tls/generator.Dockerfile -t generator
docker run --rm -it -v "$PWD":/output generator
tree certs
```
