servingEngineSpec:
  enableEngine: true
  runtimeClassName: ""
  startupProbe:
    initialDelaySeconds: 60
    periodSeconds: 30
    failureThreshold: 120
    httpGet:
      path: /health
      port: 8000

  nodeSelector:
    workload-type: cpu
    node-group: cpu-pool

  containerSecurityContext:
    privileged: true

  modelSpec:
    - name: "smollm2-cpu"
      repository: "public.ecr.aws/q9t5s3a7/vllm-cpu-release-repo"
      tag: "v0.8.5.post1"
      modelURL: "/data/models/smollm2"
      replicaCount: 1
      requestCPU: 1
      requestMemory: "2Gi"
      requestGPU: 0
      limitCPU: "2"
      limitMemory: "6Gi"
      pvcStorage: "10Gi"
      storageClass: ""
      vllmConfig:
        dtype: "float16"
        extraArgs:
          - "--device=cpu"
          - "--no-enable-prefix-caching"
      keda:
        enabled: true
        minReplicaCount: 0  # Allow scaling to zero
        maxReplicaCount: 5
        triggers:
          - type: prometheus
            metadata:
              serverAddress: http://prometheus-operated.monitoring.svc:9090
              metricName: vllm:num_requests_waiting
              query: vllm:num_requests_waiting
              threshold: '5'
          - type: prometheus
            metadata:
              serverAddress: http://prometheus-operated.monitoring.svc:9090
              metricName: vllm:incoming_keepalive
              query: sum(rate(vllm:num_incoming_requests_total[1m]) > bool 0)
              threshold: "1"
      env:
        - name: VLLM_CPU_KVCACHE_SPACE
          value: "1"
        - name: VLLM_CPU_OMP_THREADS_BIND
          value: "0-1"
        - name: OTEL_SERVICE_NAME
          value: "vllm-engine"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector:4317"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.name=vllm-engine,deployment.environment=test"
      initContainer:
        name: downloader
        image: python:3.11-slim
        command: ["/bin/sh","-c"]
        args:
          - |
            pip install --no-cache-dir --timeout=300 huggingface_hub && \
            hf download HuggingFaceTB/SmolLM2-135M-Instruct \
            --local-dir /data/models/smollm2
        env:
          - name: HUGGING_FACE_HUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: hf-token
                key: HF_TOKEN
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            memory: "2Gi"
        mountPvcStorage: true

routerSpec:
  enableRouter: true
  routingLogic: "roundrobin"
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1"
      memory: "2Gi"
  otel:
    endpoint: "otel-collector:4317"
    serviceName: "vllm-router"
    secure: false