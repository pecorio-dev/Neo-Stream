import 'package:flutter/material.dart';
import '../../data/services/chromecast_service.dart';
import '../../core/theme/app_theme.dart';

class ChromecastButton extends StatefulWidget {
  final Color? color;
  final double? size;
  final VoidCallback? onPressed;

  const ChromecastButton({
    Key? key,
    this.color,
    this.size = 24.0,
    this.onPressed,
  }) : super(key: key);

  @override
  State<ChromecastButton> createState() => _ChromecastButtonState();
}

class _ChromecastButtonState extends State<ChromecastButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  ChromecastService? _chromecastService;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeChromecast();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeChromecast() async {
    _chromecastService = ChromecastService();
    await _chromecastService!.initialize();
    
    // Écouter les changements d'état
    _chromecastService!.addListener(_onChromecastStateChanged);
  }

  void _onChromecastStateChanged() {
    if (mounted) {
      setState(() {});
      
      // Animer le bouton quand connecté
      if (_chromecastService!.isConnected) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _chromecastService?.removeListener(_onChromecastStateChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chromecastService == null || !_chromecastService!.isInitialized) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _chromecastService!.isConnected ? _pulseAnimation.value : 1.0,
          child: IconButton(
            onPressed: widget.onPressed ?? _showChromecastDialog,
            icon: Icon(
              _getChromecastIcon(),
              color: _getChromecastColor(),
              size: widget.size,
            ),
            tooltip: _getChromecastTooltip(),
          ),
        );
      },
    );
  }

  IconData _getChromecastIcon() {
    if (_chromecastService!.isConnected) {
      return Icons.cast_connected;
    } else if (_chromecastService!.availableDevices.isNotEmpty) {
      return Icons.cast;
    } else {
      return Icons.cast;
    }
  }

  Color _getChromecastColor() {
    if (_chromecastService!.isConnected) {
      return AppTheme.accentNeon;
    } else if (_chromecastService!.availableDevices.isNotEmpty) {
      return widget.color ?? AppTheme.textPrimary;
    } else {
      return widget.color?.withOpacity(0.5) ?? AppTheme.textSecondary;
    }
  }

  String _getChromecastTooltip() {
    if (_chromecastService!.isConnected) {
      return 'Connecté à ${_chromecastService!.connectedDevice?.deviceName}';
    } else if (_chromecastService!.availableDevices.isNotEmpty) {
      return 'Diffuser sur TV';
    } else {
      return 'Aucun appareil trouvé';
    }
  }

  void _showChromecastDialog() {
    showDialog(
      context: context,
      builder: (context) => ChromecastDialog(chromecastService: _chromecastService!),
    );
  }
}

class ChromecastDialog extends StatefulWidget {
  final ChromecastService chromecastService;

  const ChromecastDialog({
    Key? key,
    required this.chromecastService,
  }) : super(key: key);

  @override
  State<ChromecastDialog> createState() => _ChromecastDialogState();
}

class _ChromecastDialogState extends State<ChromecastDialog> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  void _refreshDevices() async {
    setState(() => _isScanning = true);
    await widget.chromecastService.discoverDevices();
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.cast,
            color: AppTheme.accentNeon,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Diffuser sur TV',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          IconButton(
            onPressed: _isScanning ? null : _refreshDevices,
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentNeon),
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    color: AppTheme.accentNeon,
                  ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.chromecastService.isConnected) ...[
              _buildConnectedDevice(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            
            if (widget.chromecastService.availableDevices.isEmpty && !_isScanning)
              _buildNoDevicesFound()
            else if (_isScanning)
              _buildScanningIndicator()
            else
              _buildDevicesList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildConnectedDevice() {
    final device = widget.chromecastService.connectedDevice!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentNeon.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentNeon.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentNeon,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tv,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Connecté',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await widget.chromecastService.disconnect();
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.close,
              color: AppTheme.errorColor,
            ),
            tooltip: 'Déconnecter',
          ),
        ],
      ),
    );
  }

  Widget _buildNoDevicesFound() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.cast_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun appareil trouvé',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assurez-vous que votre Chromecast ou TV compatible est allumé et connecté au même réseau Wi-Fi.',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentNeon),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recherche d\'appareils...',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recherche de Chromecast et TV compatibles sur le réseau.',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Appareils disponibles',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.chromecastService.availableDevices.map((device) {
          return _buildDeviceItem(device);
        }).toList(),
      ],
    );
  }

  Widget _buildDeviceItem(device) {
    final isConnected = widget.chromecastService.connectedDevice?.deviceId == device.deviceId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isConnected ? null : () => _connectToDevice(device),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConnected 
                  ? AppTheme.accentNeon.withOpacity(0.1)
                  : AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected 
                    ? AppTheme.accentNeon.withOpacity(0.3)
                    : AppTheme.textSecondary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tv,
                  color: isConnected ? AppTheme.accentNeon : AppTheme.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName,
                        style: TextStyle(
                          color: isConnected ? AppTheme.accentNeon : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.deviceId,
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentNeon,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Connecté',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _connectToDevice(device) async {
    try {
      final success = await widget.chromecastService.connectToDevice(device);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connecté à ${device.deviceName}'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de se connecter à ${device.deviceName}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}