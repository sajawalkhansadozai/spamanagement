#!/usr/bin/env bash
set -e
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"
flutter config --enable-web
flutter pub get
flutter build web --release
