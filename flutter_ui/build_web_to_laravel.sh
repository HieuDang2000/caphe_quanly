#!/usr/bin/env bash
set -e

# 1. Build Flutter Web
flutter build web --release
flutter build web --release --base-href=/flutter/

rm -rf ../api/public/flutter/*
cp -R build/web/* ../api/public/flutter/

rm -rf api/public/flutter/*
cp -R flutter_ui/build/web/* api/public/flutter/