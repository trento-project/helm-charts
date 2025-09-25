<!--
  ~ Copyright 2025 SUSE LLC
  ~ SPDX-License-Identifier: Apache-2.0
-->

# Helm package for trento-mcp-server

<!-- This readme has been created with this tool: https://github.com/bitnami/readme-generator-for-helm
    > node "../readme-generator-for-helm/bin/index.js" -v ./charts/trento-server/charts/trento-mcp-server/values.yaml -r ./charts/trento-server/charts/trento-mcp-server/README.md -s ./charts/trento-server/charts/trento-mcp-server/values.schema.json
-->

## Parameters

### Common parameters

| Name                      | Description                                                        | Value           |
| ------------------------- | ------------------------------------------------------------------ | --------------- |
| `kubernetesClusterDomain` | The Kubernetes cluster domain used for internal service DNS names. | `cluster.local` |

### MCPO component

| Name                             | Description                                                          | Value                                                  |
| -------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------ |
| `mcpo.enabled`                   | Enable the MCPO component.                                           | `false`                                                |
| `mcpo.args`                      | Command-line arguments for the MCPO container.                       | `["--port=8000","--config","/app/config/config.json"]` |
| `mcpo.image.repository`          | The container image repository for the MCPO component.               | `ghcr.io/open-webui/mcpo`                              |
| `mcpo.image.tag`                 | The container image tag for the MCPO component.                      | `main`                                                 |
| `mcpo.resources.limits.cpu`      | The CPU limit for the MCPO pod.                                      | `1`                                                    |
| `mcpo.resources.limits.memory`   | The memory limit for the MCPO pod.                                   | `1Gi`                                                  |
| `mcpo.resources.requests.cpu`    | The CPU request for the MCPO pod.                                    | `200m`                                                 |
| `mcpo.resources.requests.memory` | The memory request for the MCPO pod.                                 | `256Mi`                                                |
| `mcpo.ports`                     | Port configuration for the MCPO service.                             | `[]`                                                   |
| `mcpo.replicas`                  | The number of pod replicas for the MCPO deployment.                  | `1`                                                    |
| `mcpo.type`                      | The type of Kubernetes service for MCPO (e.g., ClusterIP, NodePort). | `ClusterIP`                                            |

### Trento MCP Server component

| Name                                  | Description                                                                                                                                 | Value                                                  |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `mcpServer.ingress.enabled`           | Enable ingress for the mcpServer service.                                                                                                   | `true`                                                 |
| `mcpServer.ingress.ingressClassName`  | The class of the ingress controller to use.                                                                                                 | `traefik`                                              |
| `mcpServer.ingress.tls`               | Enable TLS for the ingress.                                                                                                                 | `true`                                                 |
| `mcpServer.ingress.hosts`             | Ingress hosts configuration for the mcpServer service.                                                                                      | `[]`                                                   |
| `mcpServer.args`                      | Custom command-line arguments for the MCP Server container. If specified, this overrides the individual parameters below.                   | `[]`                                                   |
| `mcpServer.port`                      | The port on which the MCP Server listens for incoming connections.                                                                          | `8080`                                                 |
| `mcpServer.transport`                 | The transport protocol to use for MCP communication. Options: 'streamable' (default) or 'sse'.                                              | `streamable`                                           |
| `mcpServer.oasPath`                   | Path to the OpenAPI specification file within the container. This file defines the available API operations.                                | `https://demo.trento-project.io/api/v1/openapi`        |
| `mcpServer.trentoURL`                 | URL of the target Trento server to connect to for API operations and data retrieval.                                                        | `https://demo.trento-project.io`                       |
| `mcpServer.headerName`                | The HTTP header name used to pass the Trento API key for authentication with the Trento server.                                             | `X-TRENTO-MCP-APIKEY`                                  |
| `mcpServer.tagFilter`                 | List of OpenAPI tags to filter which operations are exposed as MCP tools. Only operations with at least one matching tag will be available. | `[]`                                                   |
| `mcpServer.verbosity`                 | The logging verbosity level. Options: 'debug', 'info', 'warning', 'error'.                                                                  | `info`                                                 |
| `mcpServer.insecureTLS`               | Skip TLS certificate verification when connecting to HTTPS URLs. Use only in development or trusted environments.                           | `false`                                                |
| `mcpServer.image.repository`          | The container image repository for the MCP Server component.                                                                                | `ghcr.io/trento-project/trento-mcp-server`             |
| `mcpServer.image.tag`                 | The container image tag for the MCP Server component.                                                                                       | `latest`                                               |
| `mcpServer.resources.limits.cpu`      | The CPU limit for the MCP Server pod.                                                                                                       | `500m`                                                 |
| `mcpServer.resources.limits.memory`   | The memory limit for the MCP Server pod.                                                                                                    | `512Mi`                                                |
| `mcpServer.resources.requests.cpu`    | The CPU request for the MCP Server pod.                                                                                                     | `100m`                                                 |
| `mcpServer.resources.requests.memory` | The memory request for the MCP Server pod.                                                                                                  | `128Mi`                                                |
| `mcpServer.ports`                     | Port configuration for the mcpServer service.                                                                                               | `[]`                                                   |
| `mcpServer.replicas`                  | The number of pod replicas for the MCP Server deployment.                                                                                   | `1`                                                    |
| `mcpServer.type`                      | The type of Kubernetes service for MCP Server (e.g., ClusterIP, NodePort).                                                                  | `ClusterIP`                                            |
| `mcpServer.env`                       | Additional environment variables to set in the MCP Server container.                                                                        | `{}`                                                   |
| `mcpServer.config.enabled`            | Enable mounting a configuration file for the MCP Server.                                                                                    | `false`                                                |
| `mcpServer.config.fileName`           | Name of the configuration file inside the config map.                                                                                       | `trento-mcp-server.config.yaml`                        |
| `mcpServer.config.mountPath`          | Path where the configuration file will be mounted.                                                                                          | `/etc/trento`                                          |
| `mcpServer.config.content`            | YAML content of the configuration file.                                                                                                     | `# Example configuration file (disabled by default)`   |
