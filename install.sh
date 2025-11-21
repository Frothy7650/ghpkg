#!/bin/sh
# ghpkg installer for Linux/macOS

DB_DIR="/etc/ghpkg"
DB_PATH="$DB_DIR/db.json"

# Create directories
echo "Creating directories..."
sudo mkdir -p "$DB_DIR"

# Create db.json with empty JSON array if it doesn't exist
if [ ! -f "$DB_PATH" ]; then
    echo "[]" | sudo tee "$DB_PATH" > /dev/null
fi

echo "ghpkg installed"
echo "DB path: $DB_PATH"
