import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YOLO Alert Detection',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const YOLODetection(),
    );
  }
}

class YOLODetection extends StatefulWidget {
  const YOLODetection({super.key});

  @override
  State<YOLODetection> createState() => _YOLODetectionState();
}

class _YOLODetectionState extends State<YOLODetection>
    with SingleTickerProviderStateMixin {
  List<YOLOResult> _detections = [];
  double _fps = 0;

  final Set<String> _targetLabels = {'person'};

  final List<String> _availableLabels = [
    'person', 'car', 'truck', 'bus', 'motorcycle',
    'bicycle', 'dog', 'cat', 'bottle', 'phone',
  ];

  bool _alertActive = false;
  DateTime? _lastAlertTime;
  static const Duration _alertCooldown = Duration(seconds: 3);

  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _processDetections(List<YOLOResult> results) {
    final now = DateTime.now();

    final detected = results.any(
          (r) => _targetLabels.contains(r.className?.toLowerCase()),
    );

    final canAlert = _lastAlertTime == null ||
        now.difference(_lastAlertTime!) > _alertCooldown;

    if (detected && canAlert) {
      _lastAlertTime = now;
      _triggerAlert();
    }

    setState(() {
      _detections = results;
      _alertActive = detected;
    });
  }

  void _triggerAlert() {
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });

    _flashController.forward().then((_) => _flashController.reverse());
  }

  void _showTargetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Objek Target Alert',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vibrate akan aktif saat objek ini terdeteksi',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableLabels.map((label) {
                  final selected = _targetLabels.contains(label);
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    selectedColor: Colors.redAccent.withOpacity(0.8),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.grey[300],
                    ),
                    backgroundColor: Colors.grey[800],
                    onSelected: (val) {
                      setModalState(() {
                        setState(() {
                          if (val) {
                            _targetLabels.add(label);
                          } else {
                            _targetLabels.remove(label);
                          }
                        });
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<YOLOResult> get _targetDetections => _detections
      .where((r) => _targetLabels.contains(r.className?.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Camera View ──
          YOLOView(
            modelPath: 'assets/models/yolo11n_int8.tflite',
            confidenceThreshold: 0.5,
            iouThreshold: 0.45,
            lensFacing: LensFacing.back,
            showOverlays: true,
            onResult: _processDetections,
            onPerformanceMetrics: (metrics) {
              setState(() => _fps = metrics.fps);
            },
          ),

          // ── Alert Flash Overlay ──
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (_, __) => IgnorePointer(
              child: Container(
                color: Colors.red.withOpacity(_flashAnimation.value * 0.35),
              ),
            ),
          ),

          // ── Top Bar ──
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                if (_alertActive) _buildAlertBanner(),
              ],
            ),
          ),

          // ── Bottom Panel ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _alertActive ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _alertActive ? 'TARGET DETECTED!' : 'Monitoring...',
            style: TextStyle(
              color: _alertActive ? Colors.redAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            '${_fps.toStringAsFixed(1)} FPS',
            style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
          ),
          const SizedBox(width: 12),
          // Settings button
          GestureDetector(
            onTap: _showTargetPicker,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_targetDetections.length} objek target terdeteksi: '
                  '${_targetDetections.map((r) => r.className).toSet().join(", ")}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Target labels chips
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Text(
                'Target: ',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Expanded(
                child: Text(
                  _targetLabels.isEmpty ? 'Belum dipilih' : _targetLabels.join(', '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _showTargetPicker,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Ubah',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Total detections
          Text(
            '${_detections.length} objek terdeteksi total',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}