replicaCount: 2

image:
  repository: ${simple_api_image_repository}
  tag: ${simple_api_image_tag}
  pullPolicy: IfNotPresent

service:
  port: 80
  targetPort: 8080

env:
  VLLM_BASE_URL: "http://vllm-router-service.${vllm_namespace}.svc.cluster.local"
  MODEL_NAME: "/data/models/smollm2"
  HTTP_TIMEOUT: "60"
  LOG_LEVEL: "INFO"

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

ingress:
  enabled: true
  className: alb
  host: ""
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'