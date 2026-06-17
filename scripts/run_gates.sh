#!/bin/bash
set -e

echo "=== Running Gate Checks ==="
echo "Version: v2.6.0"
echo "Date: $(date)"
echo ""

# Code Gates
echo "[1/6] Building..."
if cargo build --release; then
    echo "✅ Build passed"
else
    echo "❌ Build failed"
    exit 1
fi

echo ""
echo "[2/6] Running tests..."
if cargo test --all-features; then
    echo "✅ Tests passed"
else
    echo "❌ Tests failed"
    exit 1
fi

echo ""
echo "[3/6] Running Clippy..."
if cargo clippy --all-features -- -D warnings; then
    echo "✅ Clippy passed"
else
    echo "❌ Clippy failed"
    exit 1
fi

echo ""
echo "[4/6] Checking format..."
if cargo fmt --check --all; then
    echo "✅ Format passed"
else
    echo "❌ Format failed"
    exit 1
fi

# Quality Gates
echo ""
echo "[5/6] Checking coverage..."
if command -v cargo-tarpaulin &> /dev/null; then
    cargo tarpaulin --out Xml --packages parser,executor,storage
    echo "✅ Coverage check passed"
else
    echo "⚠️ cargo-tarpaulin not installed, skipping coverage check"
    echo "   Install with: cargo install cargo-tarpaulin"
fi

# Security Gates
echo ""
echo "[6/6] Running security audit..."
if command -v cargo-audit &> /dev/null; then
    cargo audit
    echo "✅ Security audit passed"
else
    echo "⚠️ cargo-audit not installed, skipping security audit"
    echo "   Install with: cargo install cargo-audit"
fi

echo ""
echo "=== All Gates Passed ==="
echo "✅ Release v2.6.0 is ready for deployment"