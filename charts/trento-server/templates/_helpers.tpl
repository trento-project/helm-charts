{{/*
Expand the name of the chart.
*/}}
{{- define "trento-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the full name of the chart.
*/}}
{{- define "trento-server.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- $fullname := printf "%s-%s" .Release.Name $name -}}
{{- $fullname | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart and append the suffix.
*/}}
{{- define "trento-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version -}}
{{- end -}}
