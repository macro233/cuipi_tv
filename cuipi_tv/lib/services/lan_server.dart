import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class NetworkInfo {
  final String name;
  final String address;
  NetworkInfo(this.name, this.address);
}

class LanServerService {
  HttpServer? _server;
  String _ipAddress = "0.0.0.0";
  int _port = 18088;
  bool _isRunning = false;
  String _lastError = "";
  List<NetworkInfo> _allInterfaces = [];

  // Stream Controllers for signals
  final StreamController<Map<String, dynamic>> _remoteCmdController = StreamController.broadcast();
  final StreamController<Map<String, String>> _addSourceController = StreamController.broadcast();
  final StreamController<Map<String, String>> _castVideoController = StreamController.broadcast();
  final StreamController<String> _searchPushController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _statusController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get onRemoteCmd => _remoteCmdController.stream;
  Stream<Map<String, String>> get onAddSource => _addSourceController.stream;
  Stream<Map<String, String>> get onCastVideo => _castVideoController.stream;
  Stream<String> get onSearchPush => _searchPushController.stream;
  Stream<Map<String, dynamic>> get onStatusChange => _statusController.stream;

  String get ipAddress => _ipAddress;
  int get port => _port;
  bool get isRunning => _isRunning;
  String get lastError => _lastError;
  String get serverUrl => "http://$_ipAddress:$_port";
  List<NetworkInfo> get allInterfaces => _allInterfaces;

  /// 判断是否为有效的局域网 IP（排除回环、链路本地、虚拟网卡等）
  bool _isValidLanIp(String ip) {
    if (ip.isEmpty) return false;
    // 回环地址
    if (ip.startsWith("127.") || ip == "0.0.0.0") return false;
    // 链路本地地址
    if (ip.startsWith("169.254.")) return false;
    // VPN/代理虚拟网卡
    if (ip.startsWith("198.18.")) return false;
    // Docker 默认网段
    if (ip.startsWith("172.17.") || ip.startsWith("172.18.") ||
        ip.startsWith("172.19.") || ip.startsWith("172.20.") ||
        ip.startsWith("172.21.") || ip.startsWith("172.22.") ||
        ip.startsWith("172.23.") || ip.startsWith("172.24.") ||
        ip.startsWith("172.25.") || ip.startsWith("172.26.") ||
        ip.startsWith("172.27.") || ip.startsWith("172.28.") ||
        ip.startsWith("172.29.") || ip.startsWith("172.30.") ||
        ip.startsWith("172.31.")) return false;
    // 排除公网 IP（DNS 等）
    if (ip == "8.8.8.8" || ip == "1.1.1.1" || ip == "114.114.114.114" ||
        ip == "223.5.5.5" || ip == "119.29.29.29") return false;
    return true;
  }

  /// 判断接口名是否为物理网络接口（WiFi / 以太网）
  bool _isPhysicalInterface(String name) {
    final n = name.toLowerCase();
    return n.contains('wlan') || n.contains('eth') || n.contains('wifi') ||
           n.contains('wlan0') || n.contains('eth0') || n.contains('en') ||
           n.contains('p2p') || n.contains('ap');
  }

  /// 收集所有网络接口信息
  Future<void> _collectAllInterfaces() async {
    _allInterfaces.clear();
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          _allInterfaces.add(NetworkInfo(interface.name, addr.address));
          print("Interface: ${interface.name} -> ${addr.address}");
        }
      }
      print("Total interfaces collected: ${_allInterfaces.length}");
    } catch (e) {
      print("Collect interfaces error: $e");
    }
  }

  Future<void> _detectLocalIp() async {
    await _collectAllInterfaces();

    if (_allInterfaces.isEmpty) {
      print("WARNING: No network interfaces found!");
      return;
    }

    // 策略 1: 优先选择物理网络接口（wlan/eth/wifi/en）的 192.168.x.x 地址
    for (final info in _allInterfaces) {
      if (_isPhysicalInterface(info.name) &&
          info.address.startsWith("192.168.") &&
          _isValidLanIp(info.address)) {
        _ipAddress = info.address;
        print("Detected LAN IP via physical+192.168 (${info.name}): $_ipAddress");
        return;
      }
    }

    // 策略 2: 物理接口的任意有效局域网 IP
    for (final info in _allInterfaces) {
      if (_isPhysicalInterface(info.name) && _isValidLanIp(info.address)) {
        _ipAddress = info.address;
        print("Detected LAN IP via physical interface (${info.name}): $_ipAddress");
        return;
      }
    }

    // 策略 3: 任意接口的 192.168.x.x 地址
    for (final info in _allInterfaces) {
      if (info.address.startsWith("192.168.") && _isValidLanIp(info.address)) {
        _ipAddress = info.address;
        print("Detected LAN IP via 192.168 (${info.name}): $_ipAddress");
        return;
      }
    }

    // 策略 4: 10.x 私有网段
    for (final info in _allInterfaces) {
      if (info.address.startsWith("10.") && _isValidLanIp(info.address)) {
        _ipAddress = info.address;
        print("Detected LAN IP via 10.x (${info.name}): $_ipAddress");
        return;
      }
    }

    // 策略 5: 任意有效私有 IP
    for (final info in _allInterfaces) {
      if (_isValidLanIp(info.address)) {
        _ipAddress = info.address;
        print("Detected LAN IP fallback (${info.name}): $_ipAddress");
        return;
      }
    }

    print("WARNING: Could not detect valid LAN IP from ${_allInterfaces.length} interfaces");
  }

  /// 手动设置 IP
  void setManualIp(String ip) {
    _ipAddress = ip.trim();
    print("Manually set IP: $_ipAddress");
    _notifyStatus();
  }

  void _notifyStatus() {
    _statusController.add({
      'running': _isRunning,
      'ip': _ipAddress,
      'port': _port,
      'url': serverUrl,
      'error': _lastError,
    });
  }

  Future<void> startServer() async {
    await _detectLocalIp();

    final List<int> portsToTry = [18088, 18089, 8080, 8888, 9090];
    for (final tryPort in portsToTry) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, tryPort, shared: true);
        _port = tryPort;
        _isRunning = true;
        _lastError = "";
        print("Crispy TV LAN Server running on http://$_ipAddress:$_port");
        _notifyStatus();
        break;
      } catch (e) {
        print("Failed to bind port $tryPort: $e");
        _lastError = "Port $tryPort: $e";
      }
    }

    if (_server == null) {
      _isRunning = false;
      _lastError = "All ports failed: ${portsToTry.join(', ')}";
      print("ERROR: $_lastError");
      _notifyStatus();
      return;
    }

    _server?.listen((HttpRequest request) async {
      final path = request.uri.path;
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Headers', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      if (path == '/' || path == '/mobile.html') {
        await _serveMobileHtml(request);
      } else if (path == '/api/remote' && request.method == 'POST') {
        await _handlePost(request, (data) {
          _remoteCmdController.add(data);
        });
      } else if (path == '/api/source' && request.method == 'POST') {
        await _handlePost(request, (data) {
          _addSourceController.add(<String, String>{
            'name': data['name']?.toString() ?? '手机推送源',
            'url': data['url']?.toString() ?? '',
          });
        });
      } else if (path == '/api/cast' && request.method == 'POST') {
        await _handlePost(request, (data) {
          _castVideoController.add(<String, String>{
            'title': data['title']?.toString() ?? '手机投屏',
            'url': data['url']?.toString() ?? '',
          });
        });
      } else if (path == '/api/search' && request.method == 'POST') {
        await _handlePost(request, (data) {
          _searchPushController.add(data['text'] ?? '');
        });
      } else if (path == '/api/health') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'ok',
          'ip': _ipAddress,
          'port': _port,
          'url': serverUrl,
          'interfaces': _allInterfaces.map((e) => {'name': e.name, 'address': e.address}).toList(),
        }));
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    });
  }

  Future<void> _serveMobileHtml(HttpRequest request) async {
    try {
      final htmlContent = await rootBundle.loadString('assets/mobile.html');
      request.response.headers.contentType = ContentType.html;
      request.response.write(htmlContent);
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error loading mobile UI asset');
    }
    await request.response.close();
  }

  Future<void> _handlePost(HttpRequest request, Function(Map<String, dynamic>) callback) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      callback(data);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok'}));
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'status': 'error', 'message': e.toString()}));
    }
    await request.response.close();
  }

  void stopServer() {
    _isRunning = false;
    _notifyStatus();
    _server?.close(force: true);
    _remoteCmdController.close();
    _addSourceController.close();
    _castVideoController.close();
    _searchPushController.close();
    _statusController.close();
  }
}
