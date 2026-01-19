{{/*
Expand the name of the chart.
*/}}
{{- define "agenthero.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "agenthero.fullname" -}}
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
{{- define "agenthero.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "agenthero.labels" -}}
helm.sh/chart: {{ include "agenthero.chart" . }}
{{ include "agenthero.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "agenthero.selectorLabels" -}}
app.kubernetes.io/name: {{ include "agenthero.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Backend image
*/}}
{{- define "agenthero.backendImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}
{{- end }}

{{/*
Frontend image
*/}}
{{- define "agenthero.frontendImage" -}}
{{ .Values.global.imageRegistry }}/{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "agenthero.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "agenthero.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
