#!/bin/sh
# Mock: returns output wrapped in markdown code fences
cat >/dev/null
cat <<'EOF'
```bash
ls -la /tmp
```
EOF
