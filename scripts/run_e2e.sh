#!/bin/bash
set -e

echo "=== Unit + Widget tests ==="
flutter test test/

echo "=== Integration tests ==="
flutter test integration_test/app_boot_test.dart --reporter expanded
flutter test integration_test/launch_stop_test.dart --reporter expanded
flutter test integration_test/delete_avd_test.dart --reporter expanded
flutter test integration_test/config_edit_test.dart --reporter expanded
flutter test integration_test/no_sdk_test.dart --reporter expanded
