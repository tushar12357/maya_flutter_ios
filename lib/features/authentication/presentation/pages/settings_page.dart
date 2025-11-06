import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/utils/debouncer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ──────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────
  double _volume = 75;
  double _micVolume = 80;
  bool _wakeWordEnabled = true;
  bool _wifiConnected = true;
  bool _bluetoothEnabled = false;
  bool _showShutdownModal = false;
  bool _showRestartModal = false;
  bool _isLoading = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = true;
  bool _deviceNotifications = true;
  bool _callNotifications = true;

  // BLE
  final  flutterBlue = FlutterBluePlus.instance;
  BluetoothDevice? _piDevice;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _respChar;
  bool _isScanning = false;
  String _bleStatus = 'Bluetooth Off';
  List<Map<String, dynamic>> _bleWifiNetworks = [];

  // UUIDs
  static const String _svcUuid = '0000feed-0000-1000-8000-00805f9b34fb';
  static const String _cmdUuid = '0000beef-0000-1000-8000-00805f9b34fb';
  static const String _respUuid = '0000feed-0000-1000-8000-00805f9b34fc';

  // Dependencies
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  final Debouncer _volumeDebouncer = Debouncer(delay: const Duration(milliseconds: 500));
  final Debouncer _micVolumeDebouncer = Debouncer(delay: const Duration(milliseconds: 500));
  final Debouncer _notiDebouncer = Debouncer(delay: const Duration(milliseconds: 600));

  // ──────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchInitialAudioSettings();
    _fetchNotificationPreferences();
  }

  @override
  void dispose() {
    _volumeDebouncer.cancel();
    _micVolumeDebouncer.cancel();
    _notiDebouncer.cancel();
    _teardownBle();
    super.dispose();
  }

  Future<void> _teardownBle() async {
    try {
      await _piDevice?.disconnect();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────
  // Permissions
  // ──────────────────────────────────────────────────────────────
  Future<bool> _ensureBlePermissions() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    final loc = await Permission.location.request();
    return scan.isGranted && connect.isGranted && loc.isGranted;
  }

  // ──────────────────────────────────────────────────────────────
  // BLE: Scan
  // ──────────────────────────────────────────────────────────────
  Future<void> _startBleScan() async {
    final ok = await _ensureBlePermissions();
    if (!ok) {
      setState(() => _bleStatus = 'Permission denied');
      return;
    }

    setState(() {
      _isScanning = true;
      _bleWifiNetworks.clear();
      _bleStatus = 'Scanning...';
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

    FlutterBluePlus.onScanResults.listen((results) async {
      for (final r in results) {
        final name = r.device.platformName;
        final adv = r.advertisementData;
        final hasService = adv.serviceUuids.map((u) => u.toString().toLowerCase()).contains(_svcUuid.toLowerCase());

        if (name == 'Pi-Configurator' || hasService) {
          _piDevice = r.device;
          setState(() => _bleStatus = 'Found Pi. Connecting...');
          await FlutterBluePlus.stopScan();
          await _connectPi();
          return;
        }
      }
    });
  }

  // ──────────────────────────────────────────────────────────────
  // BLE: Connect + Discover
  // ──────────────────────────────────────────────────────────────
  Future<void> _connectPi() async {
    final d = _piDevice;
    if (d == null) return;

    try {
      // Required license (free for individuals/small teams)
      await d.connect(
        license: License.free,
        timeout: const Duration(seconds: 12),
        mtu: 512,
        autoConnect: false,
      );

      setState(() => _bleStatus = 'Connected. Discovering...');

      final services = await d.discoverServices();
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() == _svcUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            final cu = c.uuid.toString().toLowerCase();
            if (cu == _cmdUuid.toLowerCase()) _cmdChar = c;
            if (cu == _respUuid.toLowerCase()) _respChar = c;
          }
        }
      }

      if (_respChar != null) {
        await _respChar!.setNotifyValue(true);

        _respChar!.lastValueStream.listen((bytes) {
          if (bytes.isEmpty) return;
          try {
            final msg = jsonDecode(utf8.decode(bytes));
            final result = msg['result'];

            if (result == 'SCAN') {
              final nets = (msg['networks'] as List)
                  .map((e) => {
                        'name': e['ssid'],
                        'signal': 'Good',
                        'connected': false,
                      })
                  .toList();
              setState(() {
                _bleWifiNetworks = nets;
                _bleStatus = 'WiFi list ready';
              });
            } else if (result == 'CONNECT') {
              final status = msg['status'] == 'OK'
                  ? 'Connected to ${msg['ssid']}'
                  : 'WiFi failed';
              _showSnackBar(status);
            }
          } catch (_) {}
        });

        await _sendBleCmd({'cmd': 'SCAN'});
        setState(() => _bleStatus = 'Fetching WiFi...');
      } else {
        setState(() => _bleStatus = 'Resp char not found');
      }
    } catch (e) {
      setState(() => _bleStatus = 'Connect error: $e');
      _disconnectBle();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // BLE: Send Command
  // ──────────────────────────────────────────────────────────────
  Future<void> _sendBleCmd(Map<String, dynamic> jsonObj) async {
    if (_cmdChar == null) return;
    final data = utf8.encode(jsonEncode(jsonObj));
    await _cmdChar!.write(data, withoutResponse: true);
  }

  // ──────────────────────────────────────────────────────────────
  // BLE: Disconnect
  // ──────────────────────────────────────────────────────────────
  Future<void> _disconnectBle() async {
    try {
      await _piDevice?.disconnect();
    } catch (_) {}
    setState(() {
      _bleWifiNetworks.clear();
      _bleStatus = 'Bluetooth Off';
      _bluetoothEnabled = false;
    });
  }

  // ──────────────────────────────────────────────────────────────
  // WiFi Password Dialog
  // ──────────────────────────────────────────────────────────────
  void _showWifiPasswordDialog(String ssid) {
    String pass = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text('Connect to $ssid', style: const TextStyle(color: Colors.white)),
        content: TextField(
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter password',
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: (v) => pass = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendBleCmd({'cmd': 'CONNECT', 'ssid': ssid, 'psk': pass});
            },
            child: const Text('Connect', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // API Calls
  // ──────────────────────────────────────────────────────────────
  Future<void> _fetchInitialAudioSettings() async {
    setState(() => _isLoading = true);
    try {
      final vol = await _apiClient.getVolume();
      if (vol['statusCode'] == 200 && vol['data']?['level'] != null) {
        setState(() => _volume = (vol['data']['level'] as num).toDouble());
      }

      final mic = await _apiClient.getMicVolume();
      if (mic['statusCode'] == 200 && mic['data']?['level'] != null) {
        setState(() => _micVolume = (mic['data']['level'] as num).toDouble());
      }

      final wake = await _apiClient.getWakeWord();
      if (wake['statusCode'] == 200 && wake['data']?['mode'] != null) {
        setState(() => _wakeWordEnabled = wake['data']['mode'] == 'on');
      }
    } catch (e) {
      _showSnackBar('Audio fetch error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNotificationPreferences() async {
    try {
      final resp = await _apiClient.getCurrentUser();
      final data = resp['data']['notification_preference'] as Map<String, dynamic>;
      setState(() {
        _emailNotifications = data['email_notifications'] ?? true;
        _pushNotifications = data['push_notifications'] ?? true;
        _smsNotifications = data['sms_notifications'] ?? true;
        _deviceNotifications = data['device_notifications'] ?? true;
        _callNotifications = data['call_notifications'] ?? true;
      });
    } catch (_) {}
  }

  Future<void> _setVolume(double v) async => _debouncedApi(() => _apiClient.setVolume(v.round()), 'Volume');
  Future<void> _setMicVolume(double v) async => _debouncedApi(() => _apiClient.setMicVolume(v.round()), 'Mic volume');
  Future<void> _setWakeWord(bool v) async => _debouncedApi(() => _apiClient.setWakeWord(v ? 'on' : 'off'), v ? 'Wake enabled' : 'Wake disabled');

  Future<void> _wakeMaya() async => _apiCall(() => _apiClient.wakeMaya(), 'Maya activated', 'Failed to wake Maya');
  Future<void> _rebootDevice() async => _apiCall(() => _apiClient.rebootDevice(), 'Restarting...', 'Failed to restart');
  Future<void> _shutdownDevice() async => _apiCall(() => _apiClient.shutdownDevice(), 'Shutting down...', 'Failed to shutdown');

  Future<void> _updateNotificationPrefs() async {
    setState(() => _isLoading = true);
    try {
      final r = await _apiClient.updateNotificationPreferences(
        emailNotifications: _emailNotifications,
        pushNotifications: _pushNotifications,
        smsNotifications: _smsNotifications,
        deviceNotifications: _deviceNotifications,
        callNotifications: _callNotifications,
      );
      _showSnackBar(r['statusCode'] == 200 ? 'Prefs saved' : 'Save failed');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _debouncedApi(Future<Map<String, dynamic>> Function() call, String successMsg) async {
    setState(() => _isLoading = true);
    try {
      final r = await call();
      if (r['statusCode'] == 200) _showSnackBar(successMsg);
      else _showSnackBar('Failed');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _apiCall(Future<Map<String, dynamic>> Function() call, String ok, String err) async {
    setState(() => _isLoading = true);
    try {
      final r = await call();
      _showSnackBar(r['statusCode'] == 200 ? ok : err);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1F2937)),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF111827)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('Doll Setup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 20),
                  _buildPowerSection(),
                  const SizedBox(height: 16),
                  _buildConnectivitySection(),
                  const SizedBox(height: 16),
                  _buildDeviceStatusSection(),
                  const SizedBox(height: 16),
                  _buildAudioControlSection(),
                  const SizedBox(height: 16),
                  _buildWakeWordSection(),
                  const SizedBox(height: 16),
                  _buildWifiSection(),
                  const SizedBox(height: 16),
                  _buildBluetoothSection(),
                  const SizedBox(height: 16),
                  _buildNotificationSection(),
                  const SizedBox(height: 16),
                  _buildAdditionalSettingsSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_showShutdownModal) _buildShutdownModal(),
          if (_showRestartModal) _buildRestartModal(),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A57E8))),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // UI Sections (unchanged – only Bluetooth & WiFi use BLE state)
  // ──────────────────────────────────────────────────────────────
  Widget _buildPowerSection() => _buildSection(
        title: 'Power',
        child: Row(children: [
          Expanded(child: _buildActionButton(icon: Icons.power_settings_new, label: 'Power Off', color: const Color(0xFFEF4444), onTap: () => setState(() => _showShutdownModal = true))),
          const SizedBox(width: 12),
          Expanded(child: _buildActionButton(icon: Icons.restart_alt, label: 'Restart', color: const Color(0xFF6B7280), onTap: () => setState(() => _showRestartModal = true))),
        ]),
      );

  Widget _buildConnectivitySection() => _buildSection(
        title: 'Connectivity',
        child: Row(children: [
          Expanded(child: _buildStatusCard(icon: Icons.wifi, label: 'Wi-Fi', status: _wifiConnected ? 'On' : 'Off', iconColor: _wifiConnected ? const Color(0xFF10B981) : const Color(0xFF6B7280))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatusCard(icon: Icons.bluetooth, label: 'Bluetooth', status: _bluetoothEnabled ? 'On' : 'Off', iconColor: _bluetoothEnabled ? const Color(0xFF3B82F6) : const Color(0xFF6B7280))),
        ]),
      );

  Widget _buildDeviceStatusSection() => _buildSection(
        title: 'Device Status',
        child: Column(children: [
          Row(children: [
            Expanded(child: _buildInfoCard(icon: Icons.battery_charging_full, label: 'Battery', value: '87%', iconColor: const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard(icon: Icons.thermostat, label: 'Temperature', value: '32°C', iconColor: const Color(0xFFF59E0B))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildInfoCard(icon: Icons.schedule, label: 'Uptime', value: '18h', iconColor: const Color(0xFF3B82F6))),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard(icon: Icons.system_update, label: 'Firmware', value: 'v2.4.1', iconColor: const Color(0xFF8B5CF6))),
          ]),
        ]),
      );

  Widget _buildAudioControlSection() => _buildSection(
        title: 'Audio Control',
        child: Column(children: [
          _buildSliderControl(
            label: 'Speaker Volume',
            value: _volume,
            onChanged: (v) {
              setState(() => _volume = v);
              _volumeDebouncer.run(() => _setVolume(v));
            },
          ),
          const SizedBox(height: 16),
          _buildSliderControl(
            label: 'Microphone Sensitivity',
            value: _micVolume,
            onChanged: (v) {
              setState(() => _micVolume = v);
              _micVolumeDebouncer.run(() => _setMicVolume(v));
            },
          ),
        ]),
      );

  Widget _buildWakeWordSection() => _buildSection(
        title: 'Wake Word Setting',
        child: Column(children: [
          _buildSwitchRow(label: 'Activate Maya with "Hey Maya"', value: _wakeWordEnabled, onChanged: _setWakeWord),
          if (!_wakeWordEnabled) ...[
            const SizedBox(height: 12),
            _buildActionButton(icon: Icons.mic, label: 'Wake Maya', color: const Color(0xFF2A57E8), onTap: _wakeMaya),
          ],
        ]),
      );

  Widget _buildBluetoothSection() => _buildSection(
        title: 'Bluetooth',
        child: Column(children: [
          _buildSwitchRow(
            label: 'Bluetooth',
            value: _bluetoothEnabled,
            onChanged: (v) async {
              setState(() => _bluetoothEnabled = v);
              if (v) {
                _startBleScan();
              } else {
                _disconnectBle();
              }
            },
          ),
          if (_bluetoothEnabled)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF374151))),
              child: Center(child: Text(_bleStatus, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14))),
            ),
        ]),
      );

  Widget _buildWifiSection() => _buildSection(
        title: 'WiFi Configuration',
        child: Column(children: [
          _buildSwitchRow(label: 'WiFi', value: _wifiConnected, onChanged: (v) => setState(() => _wifiConnected = v)),
          if (_wifiConnected) ...[
            const SizedBox(height: 12),
            if (_bleWifiNetworks.isEmpty)
              Text(_bleStatus, style: const TextStyle(color: Color(0xFF9CA3AF)))
            else
              ..._bleWifiNetworks.map((net) => GestureDetector(
                    onTap: () => _showWifiPasswordDialog(net['name']),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildWifiCard(name: net['name'], signal: net['signal'], connected: net['connected']),
                    ),
                  )),
          ],
        ]),
      );

 Widget _buildNotificationSection() {
    return _buildSection(
      title: 'Notification',
      child: Column(
        children: [
          _buildSwitchRow(
            label: 'Email Notification',
            value: _emailNotifications,
            onChanged: (v) {
              setState(() => _emailNotifications = v);
              _notiDebouncer.run(_updateNotificationPrefs);
            },
          ),
          const SizedBox(height: 8),
          _buildSwitchRow(
            label: 'Push Notification',
            value: _pushNotifications,
            onChanged: (v) {
              setState(() => _pushNotifications = v);
              _notiDebouncer.run(_updateNotificationPrefs);
            },
          ),
          const SizedBox(height: 8),
          _buildSwitchRow(
            label: 'SMS Notification',
            value: _smsNotifications,
            onChanged: (v) {
              setState(() => _smsNotifications = v);
              _notiDebouncer.run(_updateNotificationPrefs);
            },
          ),
          const SizedBox(height: 8),
          _buildSwitchRow(
            label: 'Device Notification',
            value: _deviceNotifications,
            onChanged: (v) {
              setState(() => _deviceNotifications = v);
              _notiDebouncer.run(_updateNotificationPrefs);
            },
          ),
          const SizedBox(height: 8),
          _buildSwitchRow(
            label: 'Call Notification',
            value: _callNotifications,
            onChanged: (v) {
              setState(() => _callNotifications = v);
              _notiDebouncer.run(_updateNotificationPrefs);
            },
          ),
        ],
      ),
    );
  }
  Widget _buildAdditionalSettingsSection() => _buildSection(
        title: 'Additional Setting',
        child: Column(children: [
          _buildSettingRow(icon: Icons.tune, label: 'Voice Settings', onTap: () {}),
          const SizedBox(height: 8),
          _buildSettingRow(icon: Icons.security, label: 'Privacy & Security', onTap: () {}),
          const SizedBox(height: 8),
          _buildSettingRow(icon: Icons.cloud_download, label: 'Software Update', onTap: () {}),
        ]),
      );

  // ──────────────────────────────────────────────────────────────
  // Reusable UI Widgets (unchanged)
  // ──────────────────────────────────────────────────────────────
  Widget _buildSection({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1F2937).withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF374151))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)), const SizedBox(height: 12), child]),
      );

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF374151))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500))]),
        ),
      );

  Widget _buildStatusCard({required IconData icon, required String label, required String status, required Color iconColor}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF374151))),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), Text(status, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))])),
        ]),
      );

  Widget _buildInfoCard({required IconData icon, required String label, required String value, required Color iconColor}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF374151))),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))])),
        ]),
      );

  Widget _buildSliderControl({required String label, required double value, required ValueChanged<double> onChanged}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), Text('${value.round()}%', style: const TextStyle(color: Color(0xFF2A57E8), fontSize: 14, fontWeight: FontWeight.w600))]),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: const Color(0xFF2A57E8), inactiveTrackColor: const Color(0xFF374151), thumbColor: const Color(0xFF2A57E8), overlayColor: const Color(0xFF2A57E8).withOpacity(0.2), trackHeight: 4),
            child: Slider(value: value, min: 0, max: 100, onChanged: onChanged),
          ),
        ],
      );

  Widget _buildSwitchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF2A57E8), inactiveThumbColor: const Color(0xFF6B7280), inactiveTrackColor: const Color(0xFF374151))],
      );

  Widget _buildWifiCard({required String name, required String signal, required bool connected}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8), border: Border.all(color: connected ? const Color(0xFF2A57E8) : const Color(0xFF374151))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.wifi, color: connected ? const Color(0xFF2A57E8) : const Color(0xFF6B7280), size: 20),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), Text(signal, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))]),
          ]),
          if (connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF2A57E8).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text('Connected', style: TextStyle(color: Color(0xFF2A57E8), fontSize: 12, fontWeight: FontWeight.w500)),
            ),
        ]),
      );

  Widget _buildSettingRow({required IconData icon, required String label, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF374151))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [Icon(icon, color: const Color(0xFF9CA3AF), size: 20), const SizedBox(width: 12), Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))]),
            const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
          ]),
        ),
      );

  Widget _buildShutdownModal() => _modal(
        title: 'Shutdown Maya Doll?',
        body: "The doll will power off completely. You'll need to manually turn it back on.",
        cancel: () => setState(() => _showShutdownModal = false),
        action: () {
          setState(() => _showShutdownModal = false);
          _shutdownDevice();
        },
        actionLabel: 'Shutdown',
        actionColor: const Color(0xFFEF4444),
      );

  Widget _buildRestartModal() => _modal(
        title: 'Restart Maya Doll?',
        body: 'The doll will restart and be back online in about 30 seconds.',
        cancel: () => setState(() => _showRestartModal = false),
        action: () {
          setState(() => _showRestartModal = false);
          _rebootDevice();
        },
        actionLabel: 'Restart',
        actionColor: const Color(0xFF2A57E8),
      );

  Widget _modal({
    required String title,
    required String body,
    required VoidCallback cancel,
    required VoidCallback action,
    required String actionLabel,
    required Color actionColor,
  }) =>
      Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF374151))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Text(body, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: TextButton(onPressed: cancel, child: _modalButton('Cancel', const Color(0xFF374151)))),
                const SizedBox(width: 12),
                Expanded(child: TextButton(onPressed: action, child: _modalButton(actionLabel, actionColor))),
              ]),
            ]),
          ),
        ),
      );

  Widget _modalButton(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))),
      );
}

// Helper extension
extension on VoidCallback {
  VoidCallback also(VoidCallback other) => () {
        this();
        other();
      };
}