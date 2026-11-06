# Source before launching OpenCode, including its background service.
# v2 enables OTLP export when an endpoint is present, independent of SDK flags.
unset OTEL_EXPORTER_OTLP_ENDPOINT OTEL_EXPORTER_OTLP_HEADERS
export OPENCODE_LOG_LEVEL=INFO
