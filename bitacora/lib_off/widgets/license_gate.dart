// lib/widgets/license_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class LicenseGate extends StatefulWidget {
  const LicenseGate({
    super.key,
    required this.licenseId,
    required this.child,
  });

  final String licenseId;
  final Widget child;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  bool _loading = true;
  String? _blockReason;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _blockReason = null;
    });

    // ? Bypass en debug o si la licencia es "trial-demo"
    if (kDebugMode || widget.licenseId == 'trial-demo') {
      _expiresAt = DateTime.now().add(const Duration(days: 365));
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(widget.licenseId)
          .get();

      if (!doc.exists) {
        _blockReason = 'Licencia no encontrada.';
      } else {
        final data = doc.data()!;
        final status = (data['status'] ?? 'inactive').toString();

        final rawExp = data['expiresAt'];
        DateTime? exp;
        if (rawExp is Timestamp) {
          exp = rawExp.toDate();
        } else if (rawExp is String) {
          exp = DateTime.tryParse(rawExp);
        }
        _expiresAt = exp;

        if (status != 'active') {
          _blockReason = 'Licencia inactiva.';
        } else if (exp != null && exp.isBefore(DateTime.now())) {
          _blockReason = 'Licencia vencida.';
        }
      }
    } catch (e) {
      _blockReason = 'Error al validar la licencia: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_blockReason != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('BitÃƒÆ’Ã‚Â¡cora')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    'Acceso bloqueado',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(_blockReason!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  if (_expiresAt != null)
                    Text(
                      'Vencimiento: ${_expiresAt!.toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID licencia: ${widget.licenseId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
