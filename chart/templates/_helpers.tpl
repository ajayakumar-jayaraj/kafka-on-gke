{{- define "zookeeper-servers" -}}
{{- $nodeCount := . | int }}
  {{- range $index0 := until $nodeCount -}}
    {{- $index1 := $index0 | add1 -}}
cp-zookeeper-{{ $index0 }}.cp-zookeeper:2888:3888{{ if ne $index1 $nodeCount }};{{ end }}
  {{- end -}}
{{- end -}}

{{- define "zookeeper-connect" -}}
{{- $nodeCount := . | int }}
  {{- range $index0 := until $nodeCount -}}
    {{- $index1 := $index0 | add1 -}}
cp-zookeeper-{{ $index0 }}.cp-zookeeper:2181{{ if ne $index1 $nodeCount }},{{ end }}
  {{- end -}}
{{- end -}}