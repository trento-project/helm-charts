{{/*
Expand the name of the chart.
*/}}
{{- define "trento-wanda.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "trento-wanda.fullname" -}}
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
{{- define "trento-wanda.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "trento-wanda.labels" -}}
helm.sh/chart: {{ include "trento-wanda.chart" . }}
{{ include "trento-wanda.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "trento-wanda.selectorLabels" -}}
app.kubernetes.io/name: {{ include "trento-wanda.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "trento-wanda.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "trento-wanda.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return Trento Wanda service port
*/}}
{{- define "trentoWanda.port" -}}
{{- if .Values.global.trentoWanda.servicePort }}
    {{- .Values.global.trentoWanda.servicePort -}}
{{- else -}}
    {{- .Values.service.port -}}
{{- end -}}
{{- end -}}

{{- define "trento-wanda.secretKeyBase" -}}
  {{ $secretName := (print (include "trento-wanda.fullname" .) "-secret") }}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace $secretName) -}}
  {{- if $secret -}}
    {{- index $secret "data" "SECRET_KEY_BASE" -}}
  {{- else -}}
    {{- (randAlphaNum 64) | b64enc -}}
  {{- end -}}
{{- end -}}

{{/*
Create CORS origin value
*/}}
{{- define "trentoWanda.cors_origin" -}}
{{- if .Values.cors.origin }}
    {{- .Values.cors.origin -}}
{{- else -}}
    {{- printf "http://%s-%s" .Release.Name .Values.global.trentoWanda.name -}}
{{- end -}}
{{- end -}}