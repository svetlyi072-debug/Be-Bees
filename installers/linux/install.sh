#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/.local/share/Be_Bees"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  Be_Bees Setup"
echo "============================================"
echo
echo "Installing to: $INSTALL_DIR"
echo

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

cp "$SRC_DIR/Be_Bees.x86_64" "$INSTALL_DIR/Be_Bees.x86_64"
cp "$SRC_DIR/icon.png" "$INSTALL_DIR/icon.png"
chmod +x "$INSTALL_DIR/Be_Bees.x86_64"

# A launcher on PATH, for running it from a terminal as `be_bees`.
cat > "$BIN_DIR/be_bees" <<EOF
#!/usr/bin/env bash
exec "$INSTALL_DIR/Be_Bees.x86_64" "\$@"
EOF
chmod +x "$BIN_DIR/be_bees"

# A .desktop entry so it shows up in the application menu like any other
# installed app, with no terminal/chmod step needed to launch it.
cat > "$DESKTOP_DIR/be_bees.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Be_Bees
Comment=Chess: Bees vs Wasps
Exec=$INSTALL_DIR/Be_Bees.x86_64
Icon=$INSTALL_DIR/icon.png
Terminal=false
Categories=Game;BoardGame;
EOF

cat > "$INSTALL_DIR/uninstall.sh" <<EOF
#!/usr/bin/env bash
echo "Removing Be_Bees..."
rm -f "$BIN_DIR/be_bees"
rm -f "$DESKTOP_DIR/be_bees.desktop"
rm -rf "$INSTALL_DIR"
echo "Be_Bees has been removed."
EOF
chmod +x "$INSTALL_DIR/uninstall.sh"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo "============================================"
echo "  Done! Be_Bees was installed."
echo "  It should now appear in your application"
echo "  menu. You can also run it from a terminal"
echo "  with: be_bees  (if ~/.local/bin is on your"
echo "  PATH, which it is on most distros by default)"
echo
echo "  To uninstall later, run:"
echo "    $INSTALL_DIR/uninstall.sh"
echo "============================================"
echo

read -r -p "Launch Be_Bees now? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    "$INSTALL_DIR/Be_Bees.x86_64" &
fi
