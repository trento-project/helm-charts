<!--
  ~ Copyright 2025 SUSE LLC
  ~ SPDX-License-Identifier: Apache-2.0
-->

# Helm package for trento-mcp-server

<!-- This readme has been created with this tool: https://github.com/bitnami/readme-generator-for-helm
    > node "../readme-generator-for-helm/bin/index.js" -v ./charts/trento-server/charts/trento-mcp-server/values.yaml -r ./charts/trento-server/charts/trento-mcp-server/README.md
-->

## Parameters

### Common parameters

| Name                    | Description                  | Value                                      |
| ----------------------- | ---------------------------- | ------------------------------------------ |
| `image.repository`      | Image repository             | `ghcr.io/trento-project/mcp-server-trento` |
| `image.tag`             | Image tag                    | `latest`                                   |
| `image.pullPolicy`      | Image pull policy            | `Always`                                   |
| `replicaCount`          | Number of replicas to deploy | `1`                                        |
| `containerPorts.http`   | Port for MCP HTTP traffic    | `5000`                                     |
| `containerPorts.health` | Port for health check        | `8080`                                     |

### MCP Server configuration

| Name                           | Description                                                                                                   | Value                                           |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `mcpServer.args`               | Array of arguments to pass to the MCP server container, overrides other settings                              | `[]`                                            |
| `mcpServer.autodiscoveryPaths` | Custom paths for API autodiscovery                                                                            | `["/api/all/openapi","/wanda/api/all/openapi"]` |
| `mcpServer.enableHealthCheck`  | Enable health check endpoint                                                                                  | `true`                                          |
| `mcpServer.headerName`         | Name of the header the MCP client should use to pass the Trento Personal Access Token                         | `Authorization`                                 |
| `mcpServer.healthApiPath`      | The API path used for health checks on target servers, like Trento Web or Wanda                               | `/api/healthz`                                  |
| `mcpServer.insecureTLS`        | Disable TLS certificate verification                                                                          | `false`                                         |
| `mcpServer.oasPath`            | List of paths to OpenAPI specification files. If empty, it defaults to Trento Web and Wanda internal services | `[]`                                            |
| `mcpServer.tagFilter`          | List of tags to filter                                                                                        | `["MCP"]`                                       |
| `mcpServer.transport`          | Transport protocol for the server                                                                             | `streamable`                                    |
| `mcpServer.trentoURL`          | URL of the Trento server. If empty, it defaults to Trento Web internal service                                | `""`                                            |
| `mcpServer.verbosity`          | Log level verbosity                                                                                           | `info`                                          |
| `env`                          | Environment variables to pass to the container                                                                | `{}`                                            |
| `service.type`                 | Service type                                                                                                  | `ClusterIP`                                     |
| `service.port`                 | Service port                                                                                                  | `5000`                                          |

### Ingress configuration

| Name                  | Description               | Value     |
| --------------------- | ------------------------- | --------- |
| `ingress.enabled`     | Enable ingress            | `true`    |
| `ingress.className`   | Ingress class name        | `traefik` |
| `ingress.annotations` | Ingress annotations       | `{}`      |
| `ingress.hosts`       | Ingress host rules        | `[]`      |
| `ingress.tls`         | Ingress TLS configuration | `[]`      |

### Global parameters

| Name                                 | Description                               | Value |
| ------------------------------------ | ----------------------------------------- | ----- |
| `global.clusterDomain`               | Kubernetes cluster domain                 | `nil` |
| `global.trentoMcpServer.servicePort` | Global service port for Trento MCP Server | `nil` |
| `global.trentoWanda.name`            | Global name for Trento Wanda service      | `nil` |
| `global.trentoWanda.servicePort`     | Global service port for Trento Wanda      | `nil` |
| `global.trentoWeb.name`              | Global name for Trento Web service        | `nil` |
| `global.trentoWeb.servicePort`       | Global service port for Trento Web        | `nil` |

### Resource configuration

| Name                                   | Description               | Value   |
| -------------------------------------- | ------------------------- | ------- |
| `resources.limits.cpu`                 | CPU limit                 | `500m`  |
| `resources.limits.memory`              | Memory limit              | `512Mi` |
| `resources.limits.ephemeral-storage`   | Ephemeral storage limit   | `512Mi` |
| `resources.requests.cpu`               | CPU request               | `100m`  |
| `resources.requests.memory`            | Memory request            | `128Mi` |
| `resources.requests.ephemeral-storage` | Ephemeral storage request | `128Mi` |

### Probes

| Name                                 | Description                              | Value     |
| ------------------------------------ | ---------------------------------------- | --------- |
| `startupProbe.enabled`               | Enable startup probe                     | `true`    |
| `startupProbe.path`                  | Path to access on the HTTP server        | `/livez`  |
| `startupProbe.port`                  | Port for startupProbe                    | `health`  |
| `startupProbe.initialDelaySeconds`   | Initial delay seconds for startupProbe   | `5`       |
| `startupProbe.periodSeconds`         | Period seconds for startupProbe          | `20`      |
| `startupProbe.timeoutSeconds`        | Timeout seconds for startupProbe         | `5`       |
| `startupProbe.failureThreshold`      | Failure threshold for startupProbe       | `6`       |
| `startupProbe.successThreshold`      | Success threshold for startupProbe       | `1`       |
| `livenessProbe.enabled`              | Enable liveness probe                    | `true`    |
| `livenessProbe.path`                 | Path to access on the HTTP server        | `/livez`  |
| `livenessProbe.port`                 | Port for livenessProbe                   | `health`  |
| `livenessProbe.initialDelaySeconds`  | Initial delay seconds for livenessProbe  | `10`      |
| `livenessProbe.periodSeconds`        | Period seconds for livenessProbe         | `10`      |
| `livenessProbe.timeoutSeconds`       | Timeout seconds for livenessProbe        | `5`       |
| `livenessProbe.failureThreshold`     | Failure threshold for livenessProbe      | `6`       |
| `livenessProbe.successThreshold`     | Success threshold for livenessProbe      | `1`       |
| `readinessProbe.enabled`             | Enable readiness probe                   | `true`    |
| `readinessProbe.path`                | Path to access on the HTTP server        | `/readyz` |
| `readinessProbe.port`                | Port for readinessProbe                  | `health`  |
| `readinessProbe.initialDelaySeconds` | Initial delay seconds for readinessProbe | `10`      |
| `readinessProbe.periodSeconds`       | Period seconds for readinessProbe        | `30`      |
| `readinessProbe.timeoutSeconds`      | Timeout seconds for readinessProbe       | `5`       |
| `readinessProbe.failureThreshold`    | Failure threshold for readinessProbe     | `6`       |
| `readinessProbe.successThreshold`    | Success threshold for readinessProbe     | `1`       |

### Common pod template settings

| Name                         | Description                                           | Value  |
| ---------------------------- | ----------------------------------------------------- | ------ |
| `imagePullSecrets`           | Image pull secrets for private registries             | `[]`   |
| `nameOverride`               | Partially override the chart name                     | `""`   |
| `fullnameOverride`           | Fully override the release name                       | `""`   |
| `serviceAccount.create`      | Specifies whether a service account should be created | `true` |
| `serviceAccount.annotations` | Annotations to add to the service account             | `{}`   |
| `serviceAccount.name`        | The name of the service account to use                | `""`   |
| `podAnnotations`             | Additional annotations for the pod metadata           | `{}`   |
| `nodeSelector`               | Node selector for pod assignment                      | `{}`   |
| `tolerations`                | Tolerations for pod assignment                        | `[]`   |
| `affinity`                   | Affinity rules for pod assignment                     | `{}`   |

### Network Policies

| Name                                    | Description                                                     | Value  |
| --------------------------------------- | --------------------------------------------------------------- | ------ |
| `networkPolicy.enabled`                 | Specifies whether a NetworkPolicy should be created             | `true` |
| `networkPolicy.allowExternal`           | Don't require server label for connections                      | `true` |
| `networkPolicy.allowExternalEgress`     | Allow the pod to access any range of port and all destinations. | `true` |
| `networkPolicy.ingressNSMatchLabels`    | Labels to match to allow traffic from other namespaces          | `{}`   |
| `networkPolicy.ingressNSPodMatchLabels` | Pod labels to match to allow traffic from other namespaces      | `{}`   |

### Security Context

| Name                                                | Description                                                       | Value            |
| --------------------------------------------------- | ----------------------------------------------------------------- | ---------------- |
| `podSecurityContext.fsGroupChangePolicy`            | Set filesystem group change policy                                | `Always`         |
| `podSecurityContext.sysctls`                        | Set kernel settings using the sysctl interface                    | `[]`             |
| `podSecurityContext.supplementalGroups`             | Set filesystem extra groups                                       | `[]`             |
| `podSecurityContext.fsGroup`                        | Set server pod's Security Context fsGroup                         | `1001`           |
| `containerSecurityContext.seLinuxOptions`           | Set SELinux options in container                                  | `{}`             |
| `containerSecurityContext.runAsUser`                | Set server containers' Security Context runAsUser                 | `10001`          |
| `containerSecurityContext.runAsGroup`               | Set server containers' Security Context runAsGroup                | `10001`          |
| `containerSecurityContext.runAsNonRoot`             | Set Controller container's Security Context runAsNonRoot          | `true`           |
| `containerSecurityContext.privileged`               | Set primary container's Security Context privileged               | `false`          |
| `containerSecurityContext.allowPrivilegeEscalation` | Set primary container's Security Context allowPrivilegeEscalation | `false`          |
| `containerSecurityContext.readOnlyRootFilesystem`   | Set primary container's Security Context readOnlyRootFilesystem   | `true`           |
| `containerSecurityContext.capabilities.drop`        | List of capabilities to be dropped                                | `["ALL"]`        |
| `containerSecurityContext.seccompProfile.type`      | Set container's Security Context seccomp profile                  | `RuntimeDefault` |
