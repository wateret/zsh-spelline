#!/bin/sh
# Mock: returns 3 candidates separated by ---
cat >/dev/null
cat <<'EOF'
find . -type f -size +100M
---
du -sh * | sort -rh | head -20
---
ls -lSr | tail -20
EOF
