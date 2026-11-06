# Apply before launching OpenCode, including its background service.
Remove-Item Env:OTEL_EXPORTER_OTLP_ENDPOINT -ErrorAction SilentlyContinue
Remove-Item Env:OTEL_EXPORTER_OTLP_HEADERS -ErrorAction SilentlyContinue
$env:OPENCODE_LOG_LEVEL = 'INFO'
