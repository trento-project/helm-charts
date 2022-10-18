{{/*
Expand the name of the chart.
*/}}
{{- define "wanda.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "wanda.fullname" -}}
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
{{- define "wanda.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "wanda.labels" -}}
helm.sh/chart: {{ include "wanda.chart" . }}
{{ include "wanda.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wanda.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wanda.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "wanda.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "wanda.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return Trento Wanda service port
*/}}
{{- define "wanda.port" -}}
{{- if .Values.global.wanda.servicePort }}
    {{- .Values.global.wanda.servicePort -}}
{{- else -}}
    {{- .Values.service.port -}}
{{- end -}}
{{- end -}}

{{- define "wanda.secretKeyBase" -}}
  {{ $secretName := (print (include "wanda.fullname" .) "-secret") }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
  {{- if $secret -}}
    {{- index $secret "data" "SECRET_KEY_BASE" -}}
  {{- else -}}
    {{- (randAlphaNum 64) | b64enc -}}
  {{- end -}}
{{- end -}}