#!/usr/bin/env bash
# Read-only diagnostics for the RHPS1 PPC. Touches nothing, prints everything
# needed to decide what to do next.
#
#   git pull && bash scripts/ppc/diag.sh
#
# Set SANDBOX/OLD if your trees live elsewhere.
SANDBOX="${SANDBOX:-$HOME/sanbox_leo/workspace}"
OLD="${OLD:-$HOME/workspace}"

hr() { printf '\n===== %s =====\n' "$1"; }
show() { printf '%-46s %s\n' "$1" "${2:-<vide>}"; }

hr "shell"
show "PKG_CONFIG_PATH entries:"
printf '%s\n' "$PKG_CONFIG_PATH" | tr ':' '\n' | sed 's/^/  /'
show "hrpsys-base prefix" "$(pkg-config --variable=prefix hrpsys-base 2>/dev/null)"
show "openhrp3.1 prefix" "$(pkg-config --variable=prefix openhrp3.1 2>/dev/null)"
show "setup_mc_rtc in .bashrc" "$(grep -c setup_mc_rtc "$HOME/.bashrc" 2>/dev/null)"

hr "superbuild"
show "HEAD" "$(git -C "$(dirname "$0")/../.." log --oneline -1 2>/dev/null)"
for v in WITH_RHPS1_HARDWARE BUILD_TESTING CMAKE_INSTALL_PREFIX SOURCE_DESTINATION; do
  show "$v" "$(grep -m1 "^${v}:" "$SANDBOX/build/superbuild/CMakeCache.txt" 2>/dev/null | cut -d= -f2)"
done

hr "projets clones (sandbox vs ancien)"
for d in "" /openhrp; do
  echo "--- devel$d"
  diff <(ls "$OLD/devel$d" 2>/dev/null) <(ls "$SANDBOX/devel$d" 2>/dev/null) \
    | sed -e 's/^</  seulement ANCIEN: /' -e 's/^>/  seulement SANDBOX: /' | grep -E 'seulement' || echo "  identiques"
done

hr "hrpsys-rhps1 (fournit CylinderToAngle)"
for base in "$OLD" "$SANDBOX"; do
  p="$base/devel/openhrp/hrpsys-rhps1"
  if [ -d "$p" ]; then
    echo "--- $p"
    show "  remote" "$(git -C "$p" remote get-url origin 2>/dev/null)"
    show "  HEAD" "$(git -C "$p" rev-parse HEAD 2>/dev/null)"
    show "  branche" "$(git -C "$p" status -sb 2>/dev/null | head -1)"
  else
    echo "--- $p : absent"
  fi
done

hr "artefacts attendus"
show "CylinderToAngle.so (sandbox)" "$(ls "$SANDBOX/install/lib/CylinderToAngle.so" 2>/dev/null)"
show "CylinderToAngle.so (ancien)" "$(ls "$OLD/install/lib/CylinderToAngle.so" 2>/dev/null)"
show "RHPS1main.wrl" "$(ls "$SANDBOX/install/share/OpenHRP-3.1/robot/RHPS1/model/RHPS1main.wrl" 2>/dev/null)"
show "RHPS1main_sake_sake.wrl" "$(ls "$SANDBOX/install/share/OpenHRP-3.1/robot/RHPS1/model/RHPS1main_sake_sake.wrl" 2>/dev/null)"
show "nocnoid.py (sandbox)" "$(ls "$SANDBOX/install/share/hrpsys/samples/RHPS1/nocnoid.py" 2>/dev/null)"
# The RTCManager looks for modules here; if it points at the other tree, nothing loads.
show "rtc.conf load_path" "$(grep -m1 'load_path' "$SANDBOX/install/share/hrpsys/samples/RHPS1/rtc.conf" 2>/dev/null)"
show "nocnoid nshost" "$(grep -m1 '^rtm.nshost' "$SANDBOX/install/share/hrpsys/samples/RHPS1/nocnoid.py" 2>/dev/null)"

hr "runtime"
show "/etc/omniORB.cfg" "$(grep -m1 InitRef /etc/omniORB.cfg 2>/dev/null)"
echo "ports 2809/2810:"; ss -lntp 2>/dev/null | grep -E '2809|2810' | sed 's/^/  /' || echo "  libres"
echo "process:"; pgrep -af 'rtcd|omniNames|hrpsys|RobotHardware' | sed 's/^/  /' || echo "  aucun"
show "atemsys charge" "$(lsmod 2>/dev/null | grep -c atemsys)"
show "/dev/atemsys" "$(ls -l /dev/atemsys 2>/dev/null)"
echo "interfaces:"; ip -br link 2>/dev/null | sed 's/^/  /'
echo "cartes reseau PCI:"; lspci 2>/dev/null | grep -i ethernet | sed 's/^/  /'
