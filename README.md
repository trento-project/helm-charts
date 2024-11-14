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

Copyright 2022-2024 SUSE LLC

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

<https://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
