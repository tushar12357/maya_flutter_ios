import 'package:permission_handler/permission_handler.dart';

// call before scanning
Future<bool> ensureBlePermissions() async {
  // Android 12+ needs BLUETOOTH_SCAN and CONNECT
  if (await Permission.bluetoothScan.isDenied) {
    await Permission.bluetoothScan.request();
  }
  if (await Permission.bluetoothConnect.isDenied) {
    await Permission.bluetoothConnect.request();
  }

  // Android <12 / iOS needs location
  if (await Permission.location.isDenied) {
    await Permission.location.request();
  }

  return await Permission.bluetoothScan.isGranted;
}
