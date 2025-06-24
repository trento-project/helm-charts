# Trento Helm Charts

Helm charts to deploy Trento components in a Kubernetes cluster.

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

After that, refer to each individual chart documentation to find more information:

- [trento-server](docs/trento-server.md): Chart to deploy a fully functional Trento server, including the Web and Wanda components, plus other auxiliary services.

### Optional: SSL with cert-manager

[cert-manager](https://cert-manager.io/) is a Kubernetes add-on that automates the management and issuance of TLS certificates. It can be optionally enabled in this Helm chart to provide SSL support for secure communication. While it simplifies certificate management and renewal, it introduces additional cluster-wide resources. For detailed setup instructions and considerations, refer to the [`hack/cert-manager/`](/hack/cert-manager/README.md) cookbook.

## Support

Please only report bugs via [GitHub issues](https://github.com/trento-project/trento/issues);
for any other inquiry or topic use [GitHub discussion](https://github.com/trento-project/trento/discussions).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

See the [LICENSE](LICENSE) notice.
