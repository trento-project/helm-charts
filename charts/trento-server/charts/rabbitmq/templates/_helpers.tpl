{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper RabbitMQ image name
*/}}
{{- define "rabbitmq.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper volume permissions image name
*/}}
{{- define "rabbitmq.volumePermissions.image" -}}
{{- $registryName := .Values.volumePermissions.image.registry -}}
{{- $repositoryName := .Values.volumePermissions.image.repository -}}
{{- $tag := .Values.volumePermissions.image.tag | toString -}}
{{- if $registryName }}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else }}
    {{- printf "%s:%s" $repositoryName $tag -}}
{{- end }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "rabbitmq.imagePullSecrets" -}}
{{ include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.volumePermissions.image) "global" .Values.global) }}
{{- end -}}

{{/*
 Create the name of the service account to use
 */}}
{{- define "rabbitmq.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Get the password secret.
*/}}
{{- define "rabbitmq.secretPasswordName" -}}
    {{- if .Values.auth.existingPasswordSecret -}}
        {{- printf "%s" (tpl .Values.auth.existingPasswordSecret $) -}}
    {{- else -}}
        {{- printf "%s" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/*
Get the erlang secret.
*/}}
{{- define "rabbitmq.secretErlangName" -}}
    {{- if .Values.auth.existingErlangSecret -}}
        {{- printf "%s" (tpl .Values.auth.existingErlangSecret $) -}}
    {{- else -}}
        {{- printf "%s" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/*
Get the TLS secret.
*/}}
{{- define "rabbitmq.tlsSecretName" -}}
    {{- if .Values.auth.tls.existingSecret -}}
        {{- printf "%s" (tpl .Values.auth.tls.existingSecret $) -}}
    {{- else -}}
        {{- printf "%s-certs" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/*
Return true if a TLS credentials secret object should be created
*/}}
{{- define "rabbitmq.createTlsSecret" -}}
{{- if and .Values.auth.tls.enabled (not .Values.auth.tls.existingSecret) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper RabbitMQ plugin list
*/}}
{{- define "rabbitmq.plugins" -}}
{{- $plugins := .Values.plugins -}}
{{- if .Values.extraPlugins -}}
{{- $plugins = printf "%s %s" $plugins .Values.extraPlugins -}}
{{- end -}}
{{- if .Values.metrics.enabled -}}
{{- $plugins = printf "%s %s" $plugins .Values.metrics.plugins -}}
{{- end -}}
{{- printf "%s" $plugins | replace " " ", " -}}
{{- end -}}

{{/*
Return the number of bytes given a value
following a base 2 o base 10 number system.
Usage:
{{ include "rabbitmq.toBytes" .Values.path.to.the.Value }}
*/}}
{{- define "rabbitmq.toBytes" -}}
{{- $value := int (regexReplaceAll "([0-9]+).*" . "${1}") }}
{{- $unit := regexReplaceAll "[0-9]+(.*)" . "${1}" }}
{{- if eq $unit "Ki" }}
    {{- mul $value 1024 }}
{{- else if eq $unit "Mi" }}
    {{- mul $value 1024 1024 }}
{{- else if eq $unit "Gi" }}
    {{- mul $value 1024 1024 1024 }}
{{- else if eq $unit "Ti" }}
    {{- mul $value 1024 1024 1024 1024 }}
{{- else if eq $unit "Pi" }}
    {{- mul $value 1024 1024 1024 1024 1024 }}
{{- else if eq $unit "Ei" }}
    {{- mul $value 1024 1024 1024 1024 1024 1024 }}
{{- else if eq $unit "K" }}
    {{- mul $value 1000 }}
{{- else if eq $unit "M" }}
    {{- mul $value 1000 1000 }}
{{- else if eq $unit "G" }}
    {{- mul $value 1000 1000 1000 }}
{{- else if eq $unit "T" }}
    {{- mul $value 1000 1000 1000 1000 }}
{{- else if eq $unit "P" }}
    {{- mul $value 1000 1000 1000 1000 1000 }}
{{- else if eq $unit "E" }}
    {{- mul $value 1000 1000 1000 1000 1000 1000 }}
{{- end }}
{{- end -}}

{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "rabbitmq.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "rabbitmq.validateValues.ldap" .) -}}
{{- $messages := append $messages (include "rabbitmq.validateValues.memoryHighWatermark" .) -}}
{{- $messages := append $messages (include "rabbitmq.validateValues.ingress.tls" .) -}}
{{- $messages := append $messages (include "rabbitmq.validateValues.auth.tls" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/*
Validate values of rabbitmq - LDAP support
*/}}
{{- define "rabbitmq.validateValues.ldap" -}}
{{- if .Values.ldap.enabled }}
{{- $serversListLength := len .Values.ldap.servers }}
{{- $userDnPattern := coalesce .Values.ldap.user_dn_pattern .Values.ldap.userDnPattern }}
{{- if or (and (not (gt $serversListLength 0)) (empty .Values.ldap.uri)) (and (not $userDnPattern) (not .Values.ldap.basedn)) }}
rabbitmq: LDAP
    Invalid LDAP configuration. When enabling LDAP support, the parameters "ldap.servers" or "ldap.uri" are mandatory
    to configure the connection and "ldap.userDnPattern" or "ldap.basedn" are necessary to lookup the users. Please provide them:
    $ helm install {{ .Release.Name }} rabbitmq \
      --set ldap.enabled=true \
      --set ldap.servers[0]=my-ldap-server" \
      --set ldap.port="389" \
      --set ldap.userDnPattern="cn=${username},dc=example,dc=org"
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate values of rabbitmq - Memory high watermark
*/}}
{{- define "rabbitmq.validateValues.memoryHighWatermark" -}}
{{- if and (not (eq .Values.memoryHighWatermark.type "absolute")) (not (eq .Values.memoryHighWatermark.type "relative")) }}
rabbitmq: memoryHighWatermark.type
    Invalid Memory high watermark type. Valid values are "absolute" and
    "relative". Please set a valid mode (--set memoryHighWatermark.type="xxxx")
{{- else if and .Values.memoryHighWatermark.enabled (not .Values.resources.limits.memory) (eq .Values.memoryHighWatermark.type "relative") }}
rabbitmq: memoryHighWatermark
    You enabled configuring memory high watermark using a relative limit. However,
    no memory limits were defined at POD level. Define your POD limits as shown below:

    $ helm install {{ .Release.Name }} rabbitmq \
      --set memoryHighWatermark.enabled=true \
      --set memoryHighWatermark.type="relative" \
      --set memoryHighWatermark.value="0.4" \
      --set resources.limits.memory="2Gi"

    Alternatively, use an absolute value for the memory high watermark:

    $ helm install {{ .Release.Name }} rabbitmq \
      --set memoryHighWatermark.enabled=true \
      --set memoryHighWatermark.type="absolute" \
      --set memoryHighWatermark.value="512MB"
{{- end -}}
{{- end -}}

{{/*
Validate values of rabbitmq - TLS configuration for Ingress
*/}}
{{- define "rabbitmq.validateValues.ingress.tls" -}}
{{- if and .Values.ingress.enabled .Values.ingress.tls (not .Values.ingress.selfSigned) (empty .Values.ingress.extraTls) }}
rabbitmq: ingress.tls
    You enabled the TLS configuration for the default ingress hostname but
    you did not enable any of the available mechanisms to create the TLS secret
    to be used by the Ingress Controller.
    Please use any of these alternatives:
      - Use the `ingress.extraTls` and `ingress.secrets` parameters to provide your custom TLS certificates.
      - Rely on cert-manager to create it by setting the corresponding annotations
      - Rely on Helm to create self-signed certificates by setting `ingress.selfSigned=true`
{{- end -}}
{{- end -}}

{{/*
Validate values of RabbitMQ - Auth TLS enabled
*/}}
{{- define "rabbitmq.validateValues.auth.tls" -}}
{{- if and .Values.auth.tls.enabled (not .Values.auth.tls.autoGenerated) (not .Values.auth.tls.existingSecret) (not .Values.auth.tls.caCertificate) (not .Values.auth.tls.serverCertificate) (not .Values.auth.tls.serverKey) }}
rabbitmq: auth.tls
    You enabled TLS for RabbitMQ but you did not enable any of the available mechanisms to create the TLS secret.
    Please use any of these alternatives:
      - Provide an existing secret containing the TLS certificates using `auth.tls.existingSecret`
      - Provide the plain text certificates using `auth.tls.caCertificate`, `auth.tls.serverCertificate` and `auth.tls.serverKey`.
      - Enable auto-generated certificates using `auth.tls.autoGenerated`.
{{- end -}}
{{- end -}}

{{/*
Get the initialization scripts volume name.
*/}}
{{- define "rabbitmq.initScripts" -}}
{{- printf "%s-init-scripts" (include "common.names.fullname" .) -}}
{{- end -}}

{{/*
Create the enabled_plugins file content for official RabbitMQ image
Format: [plugin1,plugin2,plugin3].
*/}}
{{- define "rabbitmq.enabledPlugins" -}}
{{- $plugins := list -}}

{{- /* Add plugins from values.plugins */ -}}
{{- if .Values.plugins -}}
{{- range .Values.plugins -}}
{{- $plugins = append $plugins . -}}
{{- end -}}
{{- end -}}

{{- /* Add metrics plugin if metrics are enabled */ -}}
{{- if and .Values.metrics.enabled (not (has "rabbitmq_prometheus" $plugins)) -}}
{{- $plugins = append $plugins "rabbitmq_prometheus" -}}
{{- end -}}

{{- /* Format as Erlang list */ -}}
[{{ join "," $plugins }}].
{{- end -}}

{{/*
Render the RabbitMQ configuration content
*/}}
{{- define "rabbitmq.configuration" -}}
{{- tpl .Values.configuration . -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts.
*/}}
{{- define "common.names.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Merge a list of values that contains template after rendering them.
Merge precedence is consistent with http://masterminds.github.io/sprig/dicts.html#merge-mustmerge
Usage:
{{ include "common.tplvalues.merge" ( dict "values" (list .Values.path.to.the.Value1 .Values.path.to.the.Value2) "context" $ ) }}
*/}}
{{- define "common.tplvalues.merge" -}}
{{- $dst := dict -}}
{{- range .values -}}
{{- $dst = include "common.tplvalues.render" (dict "value" . "context" $.context "scope" $.scope) | fromYaml | merge $dst -}}
{{- end -}}
{{ $dst | toYaml }}
{{- end -}}

{{/*
Kubernetes standard labels
{{ include "common.labels.standard" (dict "customLabels" .Values.commonLabels "context" $) -}}
*/}}
{{- define "common.labels.standard" -}}
{{- if and (hasKey . "customLabels") (hasKey . "context") -}}
{{- $default := dict "app.kubernetes.io/name" (include "common.names.name" .context) "helm.sh/chart" (include "common.names.chart" .context) "app.kubernetes.io/instance" .context.Release.Name "app.kubernetes.io/managed-by" .context.Release.Service -}}
{{- with .context.Chart.AppVersion -}}
{{- $_ := set $default "app.kubernetes.io/version" . -}}
{{- end -}}
{{ template "common.tplvalues.merge" (dict "values" (list .customLabels $default) "context" .context) }}
{{- else -}}
app.kubernetes.io/name: {{ include "common.names.name" . }}
helm.sh/chart: {{ include "common.names.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | replace "+" "-" | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Labels used on immutable fields such as deploy.spec.selector.matchLabels or svc.spec.selector
{{ include "common.labels.matchLabels" (dict "customLabels" .Values.podLabels "context" $) -}}

We don't want to loop over custom labels appending them to the selector
since it's very likely that it will break deployments, services, etc.
However, it's important to overwrite the standard labels if the user
overwrote them on metadata.labels fields.
*/}}
{{- define "common.labels.matchLabels" -}}
{{- if and (hasKey . "customLabels") (hasKey . "context") -}}
{{ merge (pick (include "common.tplvalues.render" (dict "value" .customLabels "context" .context) | fromYaml) "app.kubernetes.io/name" "app.kubernetes.io/instance") (dict "app.kubernetes.io/name" (include "common.names.name" .context) "app.kubernetes.io/instance" .context.Release.Name ) | toYaml }}
{{- else -}}
app.kubernetes.io/name: {{ include "common.names.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names evaluating values as templates
{{ include "common.images.renderPullSecrets" ( dict "images" (list .Values.path.to.the.image1, .Values.path.to.the.image2) "context" $) }}
*/}}
{{- define "common.images.renderPullSecrets" -}}
  {{- $pullSecrets := list }}
  {{- $context := .context }}

  {{- range (($context.Values.global).imagePullSecrets) -}}
    {{- if kindIs "map" . -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" .name "context" $context)) -}}
    {{- else -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
    {{- end -}}
  {{- end -}}

  {{- range .images -}}
    {{- range .pullSecrets -}}
      {{- if kindIs "map" . -}}
        {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" .name "context" $context)) -}}
      {{- else -}}
        {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) -}}
imagePullSecrets:
    {{- range $pullSecrets | uniq }}
  - name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Render a compatible securityContext depending on the platform. By default it is maintained as it is. In other platforms like Openshift we remove default user/group values that do not work out of the box with the restricted-v1 SCC
Usage:
{{- include "common.compatibility.renderSecurityContext" (dict "secContext" .Values.containerSecurityContext "context" $) -}}
*/}}
{{- define "common.compatibility.renderSecurityContext" -}}
{{- $adaptedContext := .secContext -}}
{{/* Remove empty seLinuxOptions object if global.compatibility.omitEmptySeLinuxOptions is set to true */}}
{{- if and (((.context.Values.global).compatibility).omitEmptySeLinuxOptions) (not .secContext.seLinuxOptions) -}}
  {{- $adaptedContext = omit $adaptedContext "seLinuxOptions" -}}
{{- end -}}
{{/* Remove fields that are disregarded when running the container in privileged mode */}}
{{- if $adaptedContext.privileged -}}
  {{- $adaptedContext = omit $adaptedContext "capabilities" -}}
{{- end -}}
{{- omit $adaptedContext "enabled" | toYaml -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for poddisruptionbudget.
*/}}
{{- define "common.capabilities.policy.apiVersion" -}}
{{- print "policy/v1" -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for networkpolicy.
*/}}
{{- define "common.capabilities.networkPolicy.apiVersion" -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}

{{/*
Returns true if cert-manager annotations are set
*/}}
{{- define "common.ingress.certManagerRequest" -}}
{{ if or (hasKey .annotations "cert-manager.io/cluster-issuer") (hasKey .annotations "cert-manager.io/issuer") }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Warning about not setting the resource object in all deployments.
Usage:
{{ include "common.warnings.resources" (dict "sections" (list "path1" "path2") context $) }}
Example:
{{- include "common.warnings.resources" (dict "sections" (list "csiProvider.provider" "server" "volumePermissions" "") "context" $) }}
The list in the example assumes that the following values exist:
  - csiProvider.provider.resources
  - server.resources
  - volumePermissions.resources
  - resources
*/}}
{{- define "common.warnings.resources" -}}
{{- $values := .context.Values -}}
{{- $printMessage := false -}}
{{ $affectedSections := list -}}
{{- range .sections -}}
  {{- if eq . "" -}}
    {{/* Case where the resources section is at the root (one main deployment in the chart) */}}
    {{- if not (index $values "resources") -}}
    {{- $affectedSections = append $affectedSections "resources" -}}
    {{- $printMessage = true -}}
    {{- end -}}
  {{- else -}}
    {{/* Case where the are multiple resources sections (more than one main deployment in the chart) */}}
    {{- $keys := split "." . -}}
    {{/* We iterate through the different levels until arriving to the resource section. Example: a.b.c.resources */}}
    {{- $section := $values -}}
    {{- range $keys -}}
      {{- $section = index $section . -}}
    {{- end -}}
    {{- if not (index $section "resources") -}}
      {{/* Determine if this section should be included based on enabled/replicaCount */}}
      {{- $includeSection := false -}}
      {{- if hasKey $section "enabled" -}}
        {{- if index $section "enabled" -}}
          {{- $includeSection = true -}}
        {{- end -}}
      {{- else if hasKey $section "replicaCount" -}}
        {{- if gt (index $section "replicaCount" | int) 0 -}}
          {{- $includeSection = true -}}
        {{- end -}}
      {{- else -}}
        {{- $includeSection = true -}}
      {{- end -}}
      {{- if $includeSection -}}
        {{- $affectedSections = append $affectedSections (printf "%s.resources" .) -}}
        {{- $printMessage = true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $printMessage }}
WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
{{- range $affectedSections }}
  - {{ . }}
{{- end }}
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
{{- end -}}
{{- end -}}

