#!/bin/bash
# Run Swift Testing through swiftpm, injecting the CommandLineTools framework
# search path and runtime paths so the Testing framework can be found.
set -euo pipefail

FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
INTEROP="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

exec swift test \
  -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$INTEROP" \
  "$@"
