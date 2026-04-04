#!/bin/sh
# Mock: returns a single candidate spanning multiple lines
cat >/dev/null
cat <<'EOF'
for f in *.log; do
  gzip "$f"
done
EOF
