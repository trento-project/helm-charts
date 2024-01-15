{{/*
Expand the name of the chart.
*/}}
{{- define "trento-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "trento-web.fullname" -}}
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
{{- define "trento-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "trento-web.labels" -}}
helm.sh/chart: {{ include "trento-web.chart" . }}
{{ include "trento-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "trento-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trento-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "trento-web.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "trento-web.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return Trento Web service port
*/}}
{{- define "trentoWeb.port" -}}
{{- if .Values.global.trentoWeb.servicePort }}
    {{- .Values.global.trentoWeb.servicePort -}}
{{- else -}}
    {{- .Values.service.port -}}
{{- end -}}
{{- end -}}

{{- define "trento-web.accessTokenSecret" -}}
  {{- $secretName := (print .Release.Name "-auth-tokens-secret") -}}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
  {{- if $secret -}}
    {{- index $secret "data" "ACCESS_TOKEN_ENC_SECRET" -}}
  {{- else -}}
    {{- (randAlphaNum 64) | b64enc -}}
  {{- end -}}
{{- end -}}

{{- define "trento-web.refreshTokenSecret" -}}
  {{- $secretName := (print .Release.Name "-auth-tokens-secret") -}}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
  {{- if $secret -}}
    {{- index $secret "data" "REFRESH_TOKEN_ENC_SECRET" -}}
  {{- else -}}
    {{- (randAlphaNum 64) | b64enc -}}
  {{- end -}}
{{- end -}}

{{- define "trento.web.secretKeyBase" -}}
  {{ $secretName := (print (include "trento-web.fullname" .) "-secret") }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
  {{- if $secret -}}
    {{- index $secret "data" "SECRET_KEY_BASE" -}}
  {{- else -}}
    {{- (randAlphaNum 64) | b64enc -}}
  {{- end -}}
{{- end -}}


{{- define "trento.web.adminPassword" -}}
  {{ $secretName := (print (include "trento-web.fullname" .) "-secret") }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
  {{- if $secret -}}
    {{- index $secret "data" "ADMIN_PASSWORD" -}}
  {{- else -}}
    {{- (randAlphaNum 8) | b64enc -}}
  {{- end -}}
{{- end -}}


