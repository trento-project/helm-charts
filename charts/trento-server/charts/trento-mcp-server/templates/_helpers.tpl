{{- /*
Copyright 2025 SUSE LLC
SPDX-License-Identifier: Apache-2.0
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "trento-mcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "trento-mcp-server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "trento-mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}

{{- define "trento-mcp-server.labels" -}}
helm.sh/chart: {{ include "trento-mcp-server.chart" . }}
{{ include "trento-mcp-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "trento-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trento-mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "trento-mcp-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "trento-mcp-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return Trento MCP Server service port
*/}}
{{- define "trento-mcp-server.port" -}}
{{- if .Values.global.trentoMcpServer.servicePort }}
    {{- .Values.global.trentoMcpServer.servicePort -}}
{{- else -}}
    {{- .Values.service.port -}}
{{- end -}}
{{- end -}}
