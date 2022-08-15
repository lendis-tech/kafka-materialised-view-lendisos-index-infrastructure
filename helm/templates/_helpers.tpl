{{- define "chart.prefixName" -}}
{{- printf "%s" (.Release.Name | trunc 64) -}}
{{- end -}}