import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../models/document_type.dart';
import '../widgets/camera_overlay.dart';
import 'preview_screen.dart';

enum _CameraStatus { loading, ready, denied, permanentlyDenied, error }

/// Layar kamera live capture (kamera sungguhan, tanpa mode demo).
/// Mengembalikan `Uint8List` (bytes foto) saat "Gunakan Foto Ini", atau null.
///
/// Foto hanya hidup di memori: berkas sementara dari plugin kamera dibaca ke
/// bytes lalu langsung dihapus. Tidak ada penyimpanan ke galeri atau upload.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.documentType});
  final DocumentType documentType;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  _CameraStatus _status = _CameraStatus.loading;
  String? _errorMessage;
  bool _torchOn = false;
  bool _capturing = false;
  bool _starting = false;
  Uint8List? _captured; // hasil foto (memori saja)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Bersihkan resource kamera saat layar ditutup.
    final c = _controller;
    _controller = null;
    c?.dispose();
    _captured = null;
    super.dispose();
  }

  /* ── Lifecycle: jangan biarkan kamera aktif saat app di background ── */

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _releaseCamera();
      case AppLifecycleState.resumed:
        _resumeCamera();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _releaseCamera() {
    final c = _controller;
    if (c == null) return;
    if (mounted) setState(() => _controller = null);
    c.dispose();
  }

  Future<void> _resumeCamera() async {
    if (!mounted) return;
    if (_status == _CameraStatus.denied ||
        _status == _CameraStatus.permanentlyDenied) {
      // Pengguna mungkin baru mengaktifkan izin dari Pengaturan.
      if (await Permission.camera.status.isGranted) _initCamera();
    } else if (_status == _CameraStatus.ready &&
        _controller == null &&
        _captured == null &&
        _cameras.isNotEmpty) {
      _startController(_cameras[_cameraIndex]);
    }
  }

  /* ── Inisialisasi: izin kamera → daftar kamera → controller ── */

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _status = _CameraStatus.loading;
      _errorMessage = null;
    });

    // Minta izin kamera saat layar dibuka (satu-satunya izin yang diminta).
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(
        () => _status = permission.isPermanentlyDenied
            ? _CameraStatus.permanentlyDenied
            : _CameraStatus.denied,
      );
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _status = _CameraStatus.error;
          _errorMessage = 'Perangkat ini tidak memiliki kamera.';
        });
        return;
      }
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = back < 0 ? 0 : back;
      await _startController(_cameras[_cameraIndex]);
    } on CameraException catch (e) {
      _handleCameraException(e);
    }
  }

  Future<void> _startController(CameraDescription description) async {
    if (_starting) return;
    _starting = true;
    try {
      final old = _controller;
      if (old != null) {
        if (mounted) setState(() => _controller = null);
        await old.dispose();
      }
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false, // tidak butuh izin mikrofon
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        /* sebagian kamera tidak punya flash */
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = _CameraStatus.ready;
        _torchOn = false;
      });
    } on CameraException catch (e) {
      _handleCameraException(e);
    } finally {
      _starting = false;
    }
  }

  void _handleCameraException(CameraException e) {
    if (!mounted) return;
    setState(() {
      if (e.code.startsWith('CameraAccess')) {
        _status = _CameraStatus.permanentlyDenied;
      } else {
        _status = _CameraStatus.error;
        _errorMessage = e.description ?? 'Kamera tidak dapat dibuka.';
      }
    });
  }

  /* ── Aksi ── */

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    final next = !_torchOn;
    try {
      await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } on CameraException {
      _showSnack('Flash tidak tersedia di kamera ini.');
    }
  }

  bool get _canSwitchCamera {
    if (_cameras.length < 2) return false;
    final cur = _cameras[_cameraIndex].lensDirection;
    return _cameras.any(
      (c) =>
          c.lensDirection != cur &&
          c.lensDirection != CameraLensDirection.external,
    );
  }

  Future<void> _switchCamera() async {
    if (!_canSwitchCamera || _starting) return;
    final cur = _cameras[_cameraIndex].lensDirection;
    final next = _cameras.indexWhere(
      (c) =>
          c.lensDirection != cur &&
          c.lensDirection != CameraLensDirection.external,
    );
    if (next < 0) return;
    _cameraIndex = next;
    await _startController(_cameras[next]);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      // Hapus berkas sementara: foto hanya disimpan di memori.
      try {
        await File(file.path).delete();
      } catch (_) {}
      if (!mounted) return;
      final old = _controller;
      setState(() {
        _captured = bytes;
        _controller = null; // lepas kamera saat melihat pratinjau
        _capturing = false;
        _torchOn = false;
      });
      await old?.dispose();
    } on CameraException {
      if (mounted) setState(() => _capturing = false);
      _showSnack('Gagal mengambil foto. Coba lagi.');
    }
  }

  void _retake() {
    setState(() => _captured = null);
    _startController(_cameras[_cameraIndex]);
  }

  void _usePhoto() {
    // TODO: integrasi upload ke backend di sini
    // Saat ini bytes hanya dikembalikan ke state lokal di halaman register.
    Navigator.of(context).pop(_captured);
  }

  void _discard() => Navigator.of(context).pop();

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  /* ── UI ── */

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
    if (captured != null) {
      return PreviewScreen(
        bytes: captured,
        title: 'Foto ${widget.documentType.label}',
        onUse: _usePhoto,
        onRetake: _retake,
        onDiscard: _discard,
      );
    }

    final media = MediaQuery.of(context);
    final ready = _status == _CameraStatus.ready;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody()),
          if (ready && _controller != null)
            Positioned.fill(
              child: CameraOverlay(
                documentType: widget.documentType,
                framePadding: EdgeInsets.only(
                  top: media.padding.top + 64,
                  bottom: media.padding.bottom + 190,
                ),
              ),
            ),
          Positioned(top: 0, left: 0, right: 0, child: _buildHeader(ready)),
          if (ready)
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

  Widget _buildBody() {
    switch (_status) {
      case _CameraStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _CameraStatus.ready:
        final c = _controller;
        if (c == null || !c.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return _buildPreview(c);
      case _CameraStatus.denied:
      case _CameraStatus.permanentlyDenied:
        return _CameraMessage(
          icon: Icons.no_photography_outlined,
          title: 'Izin kamera diperlukan',
          message: _status == _CameraStatus.permanentlyDenied
              ? 'Izin kamera dinonaktifkan. Aktifkan lewat Pengaturan agar ERTE dapat memfoto KTP dan KK Anda.'
              : 'ERTE memerlukan akses kamera untuk memfoto KTP dan KK Anda.',
          onOpenSettings: openAppSettings,
          onRetry: _initCamera,
        );
      case _CameraStatus.error:
        return _CameraMessage(
          icon: Icons.error_outline,
          title: 'Kamera tidak dapat dibuka',
          message: _errorMessage ?? 'Terjadi kesalahan pada kamera.',
          onRetry: _initCamera,
        );
    }
  }

  /// Preview kamera memenuhi layar (cover) tanpa mendistorsi rasio.
  Widget _buildPreview(CameraController c) {
    final size = c.value.previewSize;
    if (size == null) return CameraPreview(c);
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            // previewSize berorientasi landscape → tukar untuk portrait.
            width: size.height,
            height: size.width,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool ready) {
    return Container(
      color: const Color(0x66000000),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Tutup kamera',
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: _discard,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Foto ${widget.documentType.label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (ready && _controller != null)
                IconButton(
                  tooltip: _torchOn ? 'Matikan flash' : 'Nyalakan flash',
                  color: _torchOn ? const Color(0xFFFDE047) : Colors.white,
                  icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                  onPressed: _toggleTorch,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final enabled = _controller != null && !_capturing;
    return Container(
      color: const Color(0x99000000),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Jangan sampai terpotong, hindari pantulan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Slot kiri: tombol galeri (opsional) tidak diaktifkan.
                const SizedBox(width: 56, height: 56),
                _ShutterButton(enabled: enabled, onPressed: _capture),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton(
                    tooltip: 'Ganti kamera depan/belakang',
                    color: Colors.white,
                    iconSize: 28,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    onPressed: (_canSwitchCamera && !_capturing)
                        ? _switchCamera
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol shutter bulat putih besar dengan ring biru muda (#60A5FA).
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Ambil foto',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.5,
            child: Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF60A5FA), width: 4),
              ),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layar pesan untuk izin ditolak / error kamera.
class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onOpenSettings,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<bool> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, size: 64, color: const Color(0xFF93C5FD)),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                if (onOpenSettings != null) ...[
                  AppButton(
                    label: 'Buka Pengaturan',
                    onPressed: () => onOpenSettings!(),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
