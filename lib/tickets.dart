import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jalasupport/FCMService.dart';
import 'package:jalasupport/chat.dart' hide AppColors;
import 'package:jalasupport/create_complaint_dialog.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/tickets_modules/allDialogs.dart';
import 'package:jalasupport/main.dart';
import 'package:jalasupport/models.dart';
import 'package:jalasupport/searchable_dropdown.dart';
import 'package:jalasupport/services.dart';
import 'package:jalasupport/branch_admin_service.dart' hide supabase;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

// REPLACE the entire OptimizedDialog class

class OptimizedDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double? width;
  final double? height;
  final EdgeInsets? contentPadding;
  final bool isScrollable;

  const OptimizedDialog({
    Key? key,
    required this.title,
    required this.child,
    this.actions,
    this.width,
    this.height,
    this.contentPadding,
    this.isScrollable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final effectiveWidth = width ??
        (isMobile
            ? MediaQuery.of(context).size.width * 0.95
            : MediaQuery.of(context).size.width * 0.6);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: effectiveWidth,
        height: height,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 48,
              spreadRadius: 0,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isMobile ? 13 : 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFf16936), Color(0xFFcf4f1a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: isScrollable
                  ? SingleChildScrollView(
                      padding: contentPadding ?? const EdgeInsets.all(20),
                      child: child,
                    )
                  : Padding(
                      padding: contentPadding ?? const EdgeInsets.all(20),
                      child: child,
                    ),
            ),

            // Actions
            if (actions != null && actions!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AddTrackingNoteDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onNoteAdded;

  const AddTrackingNoteDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onNoteAdded,
  });

  @override
  State<AddTrackingNoteDialog> createState() => _AddTrackingNoteDialogState();
}

class _AddTrackingNoteDialogState extends State<AddTrackingNoteDialog> {
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitNote() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterDescription)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await TrackingService.createTrackingPoint(
        ticketId: widget.ticket.id,
        createdBy: widget.currentUser.id,
        description: _descriptionController.text.trim(),
        pointType: 'note',
        checkInTime: null,
        checkOutTime: null,
      );

      if (success && mounted) {
        Navigator.pop(context);
        widget.onNoteAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noteAddedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorAddingNote}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return OptimizedDialog(
      title: l10n.addTrackingNote,
      contentPadding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.noteDescription} *',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.addUpdateOrNote,
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
            maxLines: 5,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.noteAddedWithoutTimeTracking,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitNote,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.addNote, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

// NEW: Check-out dialog with visit report
class CheckOutDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final TicketCheckInStatus checkInStatus;
  final VoidCallback onCheckOut;

  const CheckOutDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.checkInStatus,
    required this.onCheckOut,
  });

  @override
  State<CheckOutDialog> createState() => _CheckOutDialogState();
}

class _CheckOutDialogState extends State<CheckOutDialog> {
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final duration =
        DateTime.now().difference(widget.checkInStatus.checkInTime);

    return OptimizedDialog(
      title: l10n.checkOut,
      contentPadding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visit duration info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time,
                        color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      l10n.visitDuration,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.checkInTime}:',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('HH:mm')
                                .format(widget.checkInStatus.checkInTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        color: Colors.grey[600], size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.duration}:',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            '${l10n.visitReport} *',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.workPerformed,
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
            maxLines: 5,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitCheckOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.checkOut, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

// Update _submitCheckOut method
  Future<void> _submitCheckOut() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseDescribeWork)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final checkOutTime = DateTime.now();

      final success = await TrackingService.checkOut(
        trackingPointId: widget.checkInStatus.trackingPointId,
        checkOutTime: checkOutTime,
        description: _descriptionController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pop(context);
        widget.onCheckOut();

        final duration =
            checkOutTime.difference(widget.checkInStatus.checkInTime);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.checkedOutSuccessfully} • ${l10n.duration}: ${_formatDuration(duration)}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorCheckingOut}: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

class AddTrackingPointDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onPointAdded;

  const AddTrackingPointDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onPointAdded,
  });

  @override
  State<AddTrackingPointDialog> createState() => _AddTrackingPointDialogState();
}

class _AddTrackingPointDialogState extends State<AddTrackingPointDialog> {
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String _pointType = 'note'; // 'note' or 'visit'
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  bool _isCheckedIn = false;

  String _formatDuration() {
    if (_checkInTime == null || _checkOutTime == null) return 'N/A';

    final duration = _checkOutTime!.difference(_checkInTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      child: Container(
        width: isMobile
            ? MediaQuery.of(context).size.width * 0.95
            : MediaQuery.of(context).size.width * 0.5,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.addTrackingPoint,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Point Type Selection
            Text(
              '${l10n.trackingType}:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text(l10n.siteVisit),
                    subtitle: Text(l10n.trackCheckInOutTime),
                    value: 'visit',
                    groupValue: _pointType,
                    onChanged: (value) {
                      setState(() => _pointType = value!);
                    },
                    activeColor: Colors.blue,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text(l10n.note),
                    subtitle: Text(l10n.simpleUpdate),
                    value: 'note',
                    groupValue: _pointType,
                    onChanged: (value) {
                      setState(() {
                        _pointType = value!;
                        _checkInTime = null;
                        _checkOutTime = null;
                        _isCheckedIn = false;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Check In/Out Section (only for visit type)
            if (_pointType == 'visit') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.timeTracking,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.checkIn}:',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _checkInTime != null
                                    ? DateFormat('HH:mm').format(_checkInTime!)
                                    : l10n.notCheckedIn,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _checkInTime != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.checkOut}:',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _checkOutTime != null
                                    ? DateFormat('HH:mm').format(_checkOutTime!)
                                    : l10n.notCheckedOut,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _checkOutTime != null
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_checkInTime != null && _checkOutTime != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l10n.duration}:',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDuration(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!_isCheckedIn && _checkInTime == null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _checkIn,
                              icon: const Icon(Icons.login, size: 18),
                              label: Text(l10n.checkIn),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        if (_isCheckedIn && _checkOutTime == null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _checkOut,
                              icon: const Icon(Icons.logout, size: 18),
                              label: Text(l10n.checkOut),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        if (_checkInTime != null && _checkOutTime != null) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.visitComplete,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Description
            Text(
              '${l10n.description} *',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: _pointType == 'visit'
                    ? l10n.whatWorkPerformed
                    : l10n.addUpdateNote,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pointType == 'visit'
                          ? l10n.trackingPointWillRecord
                          : l10n.trackingPointSimpleNote,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitTrackingPoint,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.addTrackingPoint,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Update _submitTrackingPoint method
  Future<void> _submitTrackingPoint() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterDescription)),
      );
      return;
    }

    if (_pointType == 'visit' &&
        _checkInTime == null &&
        _checkOutTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseCheckInOrChangeToNote)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await TrackingService.createTrackingPoint(
        ticketId: widget.ticket.id,
        createdBy: widget.currentUser.id,
        description: _descriptionController.text.trim(),
        pointType: _pointType,
        checkInTime: _checkInTime,
        checkOutTime: _checkOutTime,
      );

      if (success) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pop(context);
          widget.onPointAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.trackingPointAddedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorAddingTrackingPoint}: $e')),
        );
      }
    }
  }

// Update _checkIn method
  Future<void> _checkIn() async {
    final l10n = AppLocalizations.safeOf(context);

    setState(() {
      _checkInTime = DateTime.now();
      _isCheckedIn = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${l10n.checkedInAt} ${DateFormat('HH:mm').format(_checkInTime!)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

// Update _checkOut method
  Future<void> _checkOut() async {
    final l10n = AppLocalizations.safeOf(context);

    setState(() {
      _checkOutTime = DateTime.now();
      _isCheckedIn = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${l10n.checkedOutAt} ${DateFormat('HH:mm').format(_checkOutTime!)}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

// UPDATED: Tracking Timeline Widget with real-time updates
class TrackingTimelineWidget extends StatefulWidget {
  final String ticketId;
  final UserModel currentUser;

  const TrackingTimelineWidget({
    super.key,
    required this.ticketId,
    required this.currentUser,
  });

  @override
  State<TrackingTimelineWidget> createState() => _TrackingTimelineWidgetState();
}

class _TrackingTimelineWidgetState extends State<TrackingTimelineWidget> {
  List<TicketTrackingPoint> _trackingPoints = [];
  bool _loading = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // NEW: Setup real-time subscription for instant updates
  void _setupRealtimeSubscription() {
    _subscription =
        TrackingService.subscribeToTrackingPoints(widget.ticketId).listen(
      (points) {
        if (mounted) {
          setState(() {
            _trackingPoints = points;
            _loading = false;
          });
        }
      },
      onError: (error) {
        print('Error in tracking points stream: $error');
        if (mounted) {
          setState(() => _loading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_trackingPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                l10n.noTrackingPointsYet,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _trackingPoints.length,
      itemBuilder: (context, index) {
        final point = _trackingPoints[index];
        final isLast = index == _trackingPoints.length - 1;
        return _buildTimelineItem(point, isLast);
      },
    );
  }

  Widget _buildTimelineItem(TicketTrackingPoint point, bool isLast) {
    final l10n = AppLocalizations.safeOf(context);
    final isVisit = point.pointType == 'visit';
    final color = isVisit ? Colors.blue : Colors.green;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Indicator
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Time
                Text(
                  DateFormat('HH:mm').format(point.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  DateFormat('dd/MM').format(point.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // Timeline Line and Dot
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Icon(
                    isVisit ? Icons.location_on : Icons.note,
                    size: 12,
                    color: color,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 100,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isVisit ? l10n.siteVisitUpper : l10n.noteUpper,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point.creatorName ?? l10n.unknown,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Visit Details
                  if (isVisit &&
                      (point.checkInTime != null ||
                          point.checkOutTime != null)) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          if (point.checkInTime != null) ...[
                            Icon(Icons.login,
                                size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm').format(point.checkInTime!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                          if (point.checkInTime != null &&
                              point.checkOutTime != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.arrow_forward,
                                size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                          ],
                          if (point.checkOutTime != null) ...[
                            Icon(Icons.logout,
                                size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm').format(point.checkOutTime!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                          if (point.duration != null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                point.formattedDuration,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Description
                  if (point.description.isNotEmpty)
                    Text(
                      point.description,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TicketsScreen extends StatefulWidget {
  final UserModel currentUser;

  const TicketsScreen({super.key, required this.currentUser});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

// REPLACE the entire _TicketsScreenState class with this updated version

// COMPLETE FIXED VERSION - Replace your entire _TicketsScreenState class with this

class _TicketsScreenState extends State<TicketsScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  final Map<TicketStatus, List<TicketModel>> _ticketsByStatus = {};
  final Map<TicketStatus, bool> _loadingByStatus = {};
  final Map<TicketStatus, StreamSubscription?> _subscriptionsByStatus = {};
  final Map<TicketStatus, Map<String, String>> _userCacheByStatus = {};
  // In _TicketsScreenState class, add these with other state variables:
  final Map<TicketStatus, DateTime> _lastStreamUpdate = {};
  final Map<TicketStatus, int> _failedConnectionAttempts = {};
  bool _showConnectionWarning = false;
  Timer? _unreadRefreshTimer;

  // Highlight animation
  String? _highlightedTicketId;
  Timer? _highlightTimer;
  AnimationController? _highlightAnimationController;
  Animation<Color?>? _highlightAnimation;

  // Search and filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Filter states
  String? _selectedPlace;
  String? _selectedCreator;
  DateTimeRange? _selectedDateRange;
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _showFilters = false;

  // Toggle: show all place tickets vs only my tickets (UserType.user only)
  bool _showMyTicketsOnly = false;

  List<Map<String, String?>> _availablePlaces = [];
  List<Map<String, String>> _availableCreators = [];

  final Map<String, String> _placeNamesCache = {};
  final Map<String, String?> _placeNameEnCache = {};
  final Map<String, String?> _placeNameArCache = {};

  bool _isInitialLoad = true;
  String? _selectedChatRoomId;
  String? _selectedTicketId;
  Map<String, int> _ticketCounts = {};

  Map<String, int> _unreadCounts = {};
  Timer? _unreadCountsRefreshTimer;
  bool _isLoadingUnreadCounts = false;

  StreamSubscription? _unreadCountsSubscription;

  // Enhanced connection management
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  final Map<TicketStatus, bool> _subscriptionHealthy = {};

  StreamSubscription? _ticketCountsSubscription;

  Timer? _updateDebounceTimer;

  bool _isVisible = true;
  bool _isDisposed = false; // NEW: Track if widget is disposed

  final Map<TicketStatus, List<Map<String, dynamic>>> _updateQueue = {};

  // NEW: Add connection monitoring
  Timer? _connectionMonitorTimer;
  DateTime? _lastSuccessfulUpdate;

  final List<TicketStatus> _statuses = [
    TicketStatus.pending,
    TicketStatus.inprogress,
    TicketStatus.prefinished,
    TicketStatus.closed,
    TicketStatus.wrongInfo,
  ];

  @override
  bool get wantKeepAlive => true;

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedPlace != null) count++;
    if (_selectedCreator != null) count++;
    if (_selectedDateRange != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    for (var status in _statuses) {
      _ticketsByStatus[status] = [];
      _loadingByStatus[status] = false;
      _userCacheByStatus[status] = {};
      _updateQueue[status] = [];
      _lastStreamUpdate[status] = DateTime.now(); // ADD THIS LINE
      _failedConnectionAttempts[status] = 0; // ADD THIS LINE
    }

    _initializeRealTimeData();
    _setupUnreadCountsRefresh();
    _startConnectionMonitoring(); // NEW: Start monitoring

    _highlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _highlightAnimation = ColorTween(
      begin: Colors.orange.withOpacity(0.3),
      end: Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _highlightAnimationController!,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNavigation();
    });

    // Register for in-app notification navigation.
    TicketNavigationService.setListener(_onNavigationRequested);
  }

  void _onNavigationRequested() {
    final ticketId = TicketNavigationService.consume();
    if (ticketId == null || !mounted || _isDisposed) return;
    // Brief delay so the tab switcher has time to become visible.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _isDisposed) return;
      _jumpToTicket(ticketId);
    });
  }

  void _jumpToTicket(String ticketId) {
    // Search every loaded tab for this ticket.
    for (int i = 0; i < _statuses.length; i++) {
      final tickets = _ticketsByStatus[_statuses[i]] ?? [];
      if (tickets.any((t) => t.id == ticketId)) {
        _tabController.animateTo(i);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isDisposed) _highlightTicket(ticketId);
        });
        return;
      }
    }
    // Ticket not yet in any loaded list — just highlight without tab switch.
    _highlightTicket(ticketId);
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing TicketsScreen...');
    _isDisposed = true; // NEW: Mark as disposed
    _isVisible = false;
    TicketNavigationService.removeListener();

    WidgetsBinding.instance.removeObserver(this);
    _highlightTimer?.cancel();
    _highlightAnimationController?.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _updateDebounceTimer?.cancel();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _connectionMonitorTimer?.cancel(); // NEW: Cancel monitor
    _cleanupAllResources();
    super.dispose();
  }

// REPLACE the existing _startConnectionMonitoring method with this:
  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _lastSuccessfulUpdate = DateTime.now();

    _connectionMonitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isDisposed || !_isVisible) return;

      final currentStatus = _statuses[_tabController.index];
      final timeSinceLastUpdate = _lastStreamUpdate[currentStatus] != null
          ? DateTime.now().difference(_lastStreamUpdate[currentStatus]!)
          : Duration(minutes: 10);

      // Check if current tab's stream is stale
      if (timeSinceLastUpdate.inMinutes >= 2) {
        debugPrint(
            '⚠️ No updates for ${timeSinceLastUpdate.inMinutes} minutes for ${currentStatus.value} - restarting...');
        _showConnectionWarning = true;
        _restartStreamForStatus(currentStatus);
      }

      // Check overall health
      if (_lastSuccessfulUpdate != null) {
        final overallTimeSinceUpdate =
            DateTime.now().difference(_lastSuccessfulUpdate!);
        if (overallTimeSinceUpdate.inMinutes >= 5) {
          debugPrint('⚠️ No overall updates for 5+ minutes - reconnecting...');
          _reconnectAllStreams();
        }
      }
    });
  }

// ADD this new method to _TicketsScreenState class:
  void _restartStreamForStatus(TicketStatus status) {
    if (!mounted || _isDisposed) return;

    debugPrint('🔄 Restarting stream for ${status.value}...');

    try {
      _subscriptionsByStatus[status]?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling stream during restart: $e');
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isVisible && !_isDisposed) {
        _setupRealTimeTicketsForStatus(status);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - reconnecting streams');
        _isVisible = true;
        if (!_isDisposed) {
          _reconnectAllStreams();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        debugPrint('📱 App paused - pausing streams');
        _isVisible = false;
        break;
    }
  }

  void _cleanupAllResources() {
    debugPrint('🧹 Cleaning up all resources...');
    _cleanupSubscriptions();
    _ticketCountsSubscription?.cancel();
    _unreadCountsSubscription?.cancel();
    _unreadCountsRefreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _updateDebounceTimer?.cancel();
    _connectionMonitorTimer?.cancel();

    _ticketsByStatus.clear();
    _userCacheByStatus.clear();
    _updateQueue.clear();
    _placeNamesCache.clear();
    _placeNameEnCache.clear();
    _placeNameArCache.clear();

    debugPrint('✅ All resources cleaned up');
  }

  void _cleanupSubscriptions() {
    for (var entry in _subscriptionsByStatus.entries) {
      try {
        entry.value?.cancel();
      } catch (e) {
        debugPrint(
            '❌ Error cancelling subscription for ${entry.key.value}: $e');
      }
    }
    _subscriptionsByStatus.clear();
    _subscriptionHealthy.clear(); // NEW: Clear health status
  }

  Future<void> _reconnectAllStreams() async {
    if (!mounted || !_isVisible || _isDisposed) return;

    debugPrint('🔄 Reconnecting all streams...');

    _cleanupSubscriptions();

    _reconnectAttempts = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _lastSuccessfulUpdate = DateTime.now(); // NEW: Reset timer
    _showConnectionWarning = false;

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted && _isVisible && !_isDisposed) {
      _setupRealTimeTicketCounts();
      _loadCurrentTabTickets();
      _refreshUnreadCounts();

      debugPrint('✅ All streams reconnected');
    }
  }

  void _setupUnreadCountsRefresh() {
    _unreadRefreshTimer?.cancel();
    _unreadRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isVisible && !_isDisposed) {
        _refreshUnreadCounts();
      }
    });
  }

  Future<void> _refreshUnreadCounts() async {
    if (!mounted || !_isVisible || _isDisposed) return;

    try {
      final chatableTickets = <String>[];

      final isRegularUser = widget.currentUser.userType == UserType.user ||
          widget.currentUser.userType == UserType.superUser;

      for (final ticketList in _ticketsByStatus.values) {
        chatableTickets.addAll(
          ticketList
              .where((ticket) {
                final isActiveStatus =
                    ticket.status == TicketStatus.inprogress ||
                        ticket.status == TicketStatus.prefinished;
                if (!isActiveStatus) return false;
                // Regular users only get unread counts for their own tickets
                if (isRegularUser) {
                  return ticket.createdBy == widget.currentUser.id ||
                      ticket.assignedTo == widget.currentUser.id;
                }
                return true;
              })
              .map((ticket) => ticket.id),
        );
      }

      if (chatableTickets.isEmpty) {
        if (mounted && !_isDisposed) {
          setState(() {
            _unreadCounts = {};
          });
        }
        return;
      }

      final newUnreadCounts = await ChatService.getUnreadCountsForTickets(
          chatableTickets, widget.currentUser.id);

      if (mounted &&
          !_isDisposed &&
          !_mapEquals(_unreadCounts, newUnreadCounts)) {
        setState(() {
          _unreadCounts = newUnreadCounts;
        });
      }
    } catch (e) {
      debugPrint('❌ Error refreshing unread counts: $e');
    }
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  void _initializeRealTimeData() {
    if (_isDisposed) return;

    debugPrint('🚀 Initializing real-time data...');
    _setupRealTimeTicketCounts();
    _loadCurrentTabTickets();
    _subscribeToUnreadUpdates();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isVisible && !_isDisposed) {
        _refreshUnreadCounts();
      }
    });
  }

  void _subscribeToUnreadUpdates() {
    if (_isDisposed) return;

    _unreadCountsSubscription?.cancel();

    try {
      _unreadCountsSubscription =
          supabase.from('chat_messages').stream(primaryKey: ['id']).listen(
        (data) {
          if (mounted && _isVisible && !_isDisposed) {
            _updateDebounceTimer?.cancel();
            _updateDebounceTimer =
                Timer(const Duration(milliseconds: 1000), () {
              if (mounted && _isVisible && !_isDisposed) {
                _refreshUnreadCounts();
              }
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Error in unread counts subscription: $error');
          // Don't reconnect immediately to avoid cascading failures
          if (!_isDisposed) {
            Timer(const Duration(seconds: 5), () {
              if (mounted && !_isDisposed) {
                _subscribeToUnreadUpdates();
              }
            });
          }
        },
        cancelOnError: false, // NEW: Don't cancel on error
      );
    } catch (e) {
      debugPrint('❌ Error setting up unread subscription: $e');
    }
  }

  Future<void> _handlePendingNavigation() async {
    if (!FCMService.hasPendingNavigation() || _isDisposed) return;

    final navigation = FCMService.consumePendingNavigation();
    if (navigation == null) return;

    final ticketId = navigation['ticket_id'] as String?;
    if (ticketId == null) return;

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted || _isDisposed) return;

    for (int i = 0; i < _statuses.length; i++) {
      final tickets = _ticketsByStatus[_statuses[i]] ?? [];
      if (tickets.any((t) => t.id == ticketId)) {
        _tabController.animateTo(i);
        _highlightTicket(ticketId);
        Future.delayed(const Duration(milliseconds: 500), () {
          _scrollToTicket(ticketId);
        });
        break;
      }
    }
  }

  void _highlightTicket(String ticketId) {
    if (!mounted || _isDisposed) return;

    setState(() {
      _highlightedTicketId = ticketId;
    });

    _highlightAnimationController?.repeat(reverse: true);

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDisposed) {
        _highlightAnimationController?.stop();
        setState(() {
          _highlightedTicketId = null;
        });
      }
    });
  }

  void _scrollToTicket(String ticketId) {
    debugPrint('🎯 Ticket $ticketId should be highlighted');
  }

  bool _isTicketHighlighted(String ticketId) {
    return _highlightedTicketId == ticketId;
  }

  Color? _getTicketHighlightColor(String ticketId) {
    if (_highlightedTicketId != ticketId) return null;
    return _highlightAnimation?.value;
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isDisposed) {
        setState(() {
          _searchQuery = query.trim();
        });
        _loadCurrentTabTickets();
      }
    });
  }

  void _clearFilters() {
    if (_isDisposed) return;

    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedPlace = null;
      _selectedCreator = null;
      _selectedDateRange = null;
      _sortBy = 'date';
      _sortAscending = false;
    });
    _loadCurrentTabTickets();
  }

  List<TicketModel> _applyFiltersAndSort(List<TicketModel> tickets) {
    var filtered = tickets;

    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      filtered = filtered.where((ticket) {
        if (ticket.title.toLowerCase().contains(searchLower)) return true;
        if (ticket.description.toLowerCase().contains(searchLower)) return true;
        if (ticket.ticketNumber.toLowerCase().contains(searchLower))
          return true;

        final placeName = _getPlaceName(ticket.placeId);
        if (placeName != null && placeName.toLowerCase().contains(searchLower))
          return true;

        final creatorName = _getUserNameForStatus(
            ticket.createdBy, _statuses[_tabController.index]);
        if (creatorName != null &&
            creatorName.toLowerCase().contains(searchLower)) return true;

        if (ticket.assignedTo != null) {
          final assignedName = _getUserNameForStatus(
              ticket.assignedTo!, _statuses[_tabController.index]);
          if (assignedName != null &&
              assignedName.toLowerCase().contains(searchLower)) return true;
        }

        return false;
      }).toList();
    }

    if (_selectedPlace != null) {
      filtered = filtered.where((ticket) {
        return ticket.placeId == _selectedPlace;
      }).toList();
    }

    if (_selectedCreator != null) {
      filtered = filtered.where((ticket) {
        return ticket.createdBy == _selectedCreator;
      }).toList();
    }

    if (_selectedDateRange != null) {
      filtered = filtered.where((ticket) {
        return ticket.createdAt.isAfter(_selectedDateRange!.start) &&
            ticket.createdAt
                .isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    filtered.sort((a, b) {
      int comparison = 0;

      if (_sortBy == 'date') {
        comparison = a.createdAt.compareTo(b.createdAt);
      } else if (_sortBy == 'priority') {
        final priorityOrder = {
          PriorityType.urgent: 4,
          PriorityType.high: 3,
          PriorityType.medium: 2,
          PriorityType.low: 1,
        };
        comparison = (priorityOrder[a.priority] ?? 0)
            .compareTo(priorityOrder[b.priority] ?? 0);
      }

      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<void> _extractFilterOptions(List<TicketModel> tickets) async {
    if (_isDisposed) return;

    final places = <String, String>{};
    final creators = <String, String>{};

    final placeIds = <String>{};
    final creatorIds = <String>{};

    for (final ticket in tickets) {
      if (ticket.placeId != null) {
        placeIds.add(ticket.placeId!);
      }
      creatorIds.add(ticket.createdBy);
    }

    for (final placeId in placeIds) {
      if (!_placeNamesCache.containsKey(placeId)) {
        try {
          final placeData = await supabase
              .from('places')
              .select('id, name, name_en, name_ar')
              .eq('id', placeId)
              .maybeSingle();

          if (placeData != null && !_isDisposed) {
            _placeNamesCache[placeId] = placeData['name'];
            _placeNameEnCache[placeId] = placeData['name_en'];
            _placeNameArCache[placeId] = placeData['name_ar'];
          }
        } catch (e) {
          debugPrint('❌ Error loading place name for $placeId: $e');
        }
      }

      if (_placeNamesCache.containsKey(placeId)) {
        places[placeId] = _placeNamesCache[placeId]!;
      }
    }

    final currentStatus = _statuses[_tabController.index];
    for (final creatorId in creatorIds) {
      final creatorName = _getUserNameForStatus(creatorId, currentStatus);
      if (creatorName != null) {
        creators[creatorId] = creatorName;
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _availablePlaces = places.entries
            .map((e) => {
                  'id': e.key,
                  'name': e.value,
                  'name_en': _placeNameEnCache[e.key],
                  'name_ar': _placeNameArCache[e.key],
                })
            .toList()
          ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

        _availableCreators = creators.entries
            .map((e) => {'id': e.key, 'name': e.value})
            .toList()
          ..sort((a, b) => a['name']!.compareTo(b['name']!));
      });
    }
  }

  String? _getPlaceName(String? placeId) {
    if (placeId == null) return 'N/A';
    return _placeNamesCache[placeId] ?? 'Loading...';
  }

  Future<void> _loadUserNamesForStatus(
      List<String> userIds, TicketStatus status) async {
    if (!mounted || _isDisposed) return;

    if (_userCacheByStatus[status] == null) {
      _userCacheByStatus[status] = {};
    }

    final uncachedIds = userIds
        .where((id) => !_userCacheByStatus[status]!.containsKey(id))
        .toList();

    if (uncachedIds.isEmpty) return;

    try {
      const chunkSize = 50;
      for (var i = 0; i < uncachedIds.length; i += chunkSize) {
        final chunk = uncachedIds.skip(i).take(chunkSize).toList();

        final users = await supabase
            .from('users')
            .select('id, full_name')
            .inFilter('id', chunk);

        if (!mounted || _isDisposed) return;

        for (final user in users) {
          _userCacheByStatus[status]![user['id']] = user['full_name'] ?? 'User';
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user names for status $status: $e');
    }
  }

  Future<void> _processTicketStreamData(
      TicketStatus status, List<Map<String, dynamic>> data) async {
    if (!mounted || !_isVisible || _isDisposed) return;

    // NEW: Mark successful update
    _lastSuccessfulUpdate = DateTime.now();

    try {
      final tickets = await _filterAndParseTickets(data);

      if (!mounted || _isDisposed) return;

      final userIds = <String>{};
      for (final ticket in tickets) {
        userIds.add(ticket.createdBy);
        if (ticket.assignedTo != null) {
          userIds.add(ticket.assignedTo!);
        }
      }

      await _loadUserNamesForStatus(userIds.toList(), status);

      final filteredTickets = _applyFiltersAndSort(tickets);

      await _extractFilterOptions(tickets);

      if (mounted && !_isDisposed) {
        setState(() {
          _ticketsByStatus[status] = filteredTickets;
          _loadingByStatus[status] = false;
          _isInitialLoad = false;
        });

        debugPrint(
            '✅ Updated ${filteredTickets.length} tickets for ${status.value}');
      }
    } catch (e) {
      debugPrint('❌ Error processing stream data for status $status: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _loadingByStatus[status] = false;
        });
      }
    }
  }

  Future<List<TicketModel>> _filterAndParseTickets(
      List<Map<String, dynamic>> data) async {
    final tickets = <TicketModel>[];

    try {
      if (widget.currentUser.userType == UserType.systemAdmin) {
        for (final ticketData in data) {
          try {
            tickets.add(TicketModel.fromJson(ticketData));
          } catch (e) {
            debugPrint('❌ Error parsing ticket: $e');
          }
        }
      } else if (widget.currentUser.userType == UserType.branchAdmin) {
        final assignedPlaces = await supabase
            .from('branch_admin_places')
            .select('place_id')
            .eq('admin_id', widget.currentUser.id);
        final placeIds =
            assignedPlaces.map((p) => p['place_id'] as String).toList();

        for (final ticketData in data) {
          try {
            final ticket = TicketModel.fromJson(ticketData);
            if (ticket.placeId != null && placeIds.contains(ticket.placeId)) {
              tickets.add(ticket);
            }
          } catch (e) {
            debugPrint('❌ Error processing branch admin ticket: $e');
          }
        }
      } else if (widget.currentUser.userType == UserType.superAdmin) {
        if (widget.currentUser.departmentId != null) {
          for (final ticketData in data) {
            try {
              final ticket = TicketModel.fromJson(ticketData);
              if (ticket.targetDepartmentId ==
                      widget.currentUser.departmentId ||
                  ticket.createdBy == widget.currentUser.id ||
                  (ticket.parentTicketId != null &&
                      await _isSubticketAccessible(ticket))) {
                tickets.add(ticket);
              }
            } catch (e) {
              debugPrint('❌ Error processing super admin ticket: $e');
            }
          }
        }
      } else if (widget.currentUser.userType == UserType.admin) {
        for (final ticketData in data) {
          try {
            final ticket = TicketModel.fromJson(ticketData);
            if (ticket.assignedTo == widget.currentUser.id ||
                ticket.createdBy == widget.currentUser.id) {
              tickets.add(ticket);
            }
          } catch (e) {
            debugPrint('❌ Error processing admin ticket: $e');
          }
        }
      } else if (widget.currentUser.userType == UserType.superUser) {
        if (widget.currentUser.placeId != null) {
          try {
            final usersInPlace = await supabase
                .from('users')
                .select('id')
                .eq('place_id', widget.currentUser.placeId!)
                .eq('user_type', 'user');
            final userIds = [
              widget.currentUser.id,
              ...usersInPlace.map((u) => u['id']).cast<String>()
            ];
            for (final ticketData in data) {
              try {
                final ticket = TicketModel.fromJson(ticketData);
                if (userIds.contains(ticket.createdBy)) tickets.add(ticket);
              } catch (e) {
                debugPrint('❌ Error processing super user ticket: $e');
              }
            }
          } catch (e) {
            debugPrint('❌ Error loading users in place: $e');
          }
        }
      } else {
        for (final ticketData in data) {
          try {
            final ticket = TicketModel.fromJson(ticketData);
            if (_showMyTicketsOnly &&
                ticket.createdBy != widget.currentUser.id) continue;
            tickets.add(ticket);
          } catch (e) {
            debugPrint('❌ Error parsing user ticket: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _filterAndParseTickets: $e');
    }

    return tickets;
  }

  String? _getUserNameForStatus(String userId, TicketStatus status) {
    return _userCacheByStatus[status]?[userId];
  }

// REPLACE the entire _setupRealTimeTicketsForStatus method with this:
  void _setupRealTimeTicketsForStatus(TicketStatus status) {
    if (!mounted || !_isVisible || _isDisposed) return;

    debugPrint('🔄 Setting up real-time stream for ${status.value}...');

    // Cancel existing subscription
    try {
      _subscriptionsByStatus[status]?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling previous subscription: $e');
    }
    _subscriptionsByStatus[status] = null;

    setState(() {
      _loadingByStatus[status] = true;
      _subscriptionHealthy[status] = false;
    });

    final attemptSetup = () async {
      try {
        debugPrint('🔄 Attempting to create stream for ${status.value}...');

        _subscriptionsByStatus[status] = supabase
            .from('tickets')
            .stream(primaryKey: ['id'])
            .eq('status', status.value)
            .order('created_at', ascending: false)
            .limit(100)
            .listen(
              (data) {
                if (!mounted || !_isVisible || _isDisposed) {
                  debugPrint('⚠️ Ignoring stream data - widget not ready');
                  return;
                }

                debugPrint(
                    '✅ Stream update for ${status.value}: ${data.length} tickets');

                _subscriptionHealthy[status] = true;
                _reconnectAttempts = 0;
                _failedConnectionAttempts[status] = 0;
                _lastStreamUpdate[status] = DateTime.now();
                _lastSuccessfulUpdate = DateTime.now();
                _showConnectionWarning = false;

                _processTicketStreamData(status, data);
              },
              onError: (error) {
                debugPrint('❌ Stream error for status $status: $error');
                _subscriptionHealthy[status] = false;

                // Increment failed attempts
                final failedCount = _failedConnectionAttempts[status] =
                    (_failedConnectionAttempts[status] ?? 0) + 1;

                if (mounted && !_isDisposed) {
                  setState(() {
                    _loadingByStatus[status] = false;
                  });
                }

                // Check if we should retry
                if (_shouldAttemptReconnect(error) &&
                    failedCount <= 3 &&
                    !_isDisposed) {
                  debugPrint(
                      '🔄 Retrying connection for $status (attempt $failedCount/3)...');
                  Future.delayed(Duration(seconds: 2 * failedCount), () {
                    if (mounted && _isVisible && !_isDisposed) {
                      _restartStreamForStatus(status);
                    }
                  });
                } else if (failedCount > 3) {
                  debugPrint('❌ Max retry attempts reached for status $status');
                  _showConnectionIssueSnackBar();
                }
              },
              onDone: () {
                debugPrint('⚠️ Stream completed for status $status');
                _subscriptionHealthy[status] = false;
                if (!_isDisposed) {
                  _handleSubscriptionClosure(status);
                }
              },
              cancelOnError: false,
            );

        debugPrint('✅ Real-time stream setup complete for ${status.value}');
      } catch (e) {
        debugPrint('❌ Error setting up stream for status $status: $e');
        _subscriptionHealthy[status] = false;

        if (mounted && !_isDisposed) {
          setState(() {
            _loadingByStatus[status] = false;
          });
        }

        // Retry after delay
        if (!_isDisposed) {
          final failedCount = _failedConnectionAttempts[status] =
              (_failedConnectionAttempts[status] ?? 0) + 1;
          if (failedCount <= 3) {
            Future.delayed(Duration(seconds: 2 * failedCount), () {
              if (mounted && _isVisible && !_isDisposed) {
                _restartStreamForStatus(status);
              }
            });
          }
        }
      }
    };

    // Initial attempt
    attemptSetup();
  }

  void _clearUserCacheForStatus(TicketStatus status) {
    _userCacheByStatus[status]?.clear();
  }

  void _onTabChanged() {
    if (!mounted || !_isVisible || _isDisposed) return;

    final previousStatus = _statuses[_tabController.previousIndex ?? 0];
    final currentStatus = _statuses[_tabController.index];

    debugPrint(
        '📑 Tab changed: ${previousStatus.value} → ${currentStatus.value}');

    _clearUserCacheForStatus(previousStatus);

    if (_selectedChatRoomId != null) {
      _closeChat();
    }

    _loadCurrentTabTickets();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isVisible && !_isDisposed) {
        _refreshUnreadCounts();
      }
    });
  }

  void _refreshData() {
    if (!mounted || _isDisposed) return;

    debugPrint('🔄 Refreshing all data...');

    _reconnectAttempts = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();

    for (var status in _statuses) {
      _userCacheByStatus[status]?.clear();
    }

    ChatService.clearAllCaches();

    _loadCurrentTabTickets();
    _setupRealTimeTicketCounts();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isVisible && !_isDisposed) {
        _refreshUnreadCounts();
      }
    });

  }

  void _loadCurrentTabTickets() {
    if (!mounted || !_isVisible || _isDisposed) return;

    final currentStatus = _statuses[_tabController.index];
    debugPrint('📥 Loading tickets for tab: ${currentStatus.value}');
    _setupRealTimeTicketsForStatus(currentStatus);
  }

  void _setupRealTimeTicketCounts() {
    if (_isDisposed) return;

    debugPrint('🔢 Setting up real-time ticket counts...');

    try {
      _ticketCountsSubscription?.cancel();
    } catch (e) {
      debugPrint('⚠️ Error cancelling ticket counts subscription: $e');
    }

    try {
      _ticketCountsSubscription = supabase
          .from('tickets')
          .stream(primaryKey: ['id'])
          .neq('status', 'deleted')
          .listen(
            (data) {
              if (mounted && _isVisible && !_isDisposed) {
                _processTicketCounts(data);
              }
            },
            onError: (error) {
              debugPrint('❌ Error in ticket counts stream: $error');
              // Retry after delay
              if (!_isDisposed) {
                Timer(const Duration(seconds: 10), () {
                  if (mounted && _isVisible && !_isDisposed) {
                    _setupRealTimeTicketCounts();
                  }
                });
              }
            },
            cancelOnError: false,
          );
    } catch (e) {
      debugPrint('❌ Error setting up ticket counts: $e');
    }
  }

  // REPLACE the entire _processTicketCounts method in _TicketsScreenState
  Future<void> _processTicketCounts(List<Map<String, dynamic>> data) async {
    if (!mounted || _isDisposed) return;

    try {
      Map<String, int> counts = {};

      for (final ticketData in data) {
        final ticket = TicketModel.fromJson(ticketData);
        bool shouldCount = false;

        if (widget.currentUser.userType == UserType.systemAdmin) {
          shouldCount = true;
        } else if (widget.currentUser.userType == UserType.branchAdmin) {
          // NEW: Branch admin can see tickets from their assigned places
          try {
            final assignedPlaces = await supabase
                .from('branch_admin_places')
                .select('place_id')
                .eq('admin_id', widget.currentUser.id);

            final placeIds =
                assignedPlaces.map((p) => p['place_id'] as String).toList();

            shouldCount =
                ticket.placeId != null && placeIds.contains(ticket.placeId);
          } catch (e) {
            debugPrint('❌ Error checking branch admin places: $e');
          }
        } else if (widget.currentUser.userType == UserType.superAdmin) {
          if (widget.currentUser.departmentId != null) {
            shouldCount =
                ticket.targetDepartmentId == widget.currentUser.departmentId ||
                    ticket.createdBy == widget.currentUser.id ||
                    (ticket.parentTicketId != null &&
                        await _isSubticketAccessible(ticket));
          } else {
            shouldCount = ticket.createdBy == widget.currentUser.id;
          }
        } else if (widget.currentUser.userType == UserType.admin) {
          shouldCount = ticket.assignedTo == widget.currentUser.id ||
              ticket.createdBy == widget.currentUser.id;
        } else if (widget.currentUser.userType == UserType.superUser) {
          if (widget.currentUser.placeId != null) {
            final creator = await supabase
                .from('users')
                .select('place_id')
                .eq('id', ticket.createdBy)
                .maybeSingle();

            shouldCount = creator != null &&
                (creator['place_id'] == widget.currentUser.placeId ||
                    ticket.createdBy == widget.currentUser.id);
          } else {
            shouldCount = ticket.createdBy == widget.currentUser.id;
          }
        } else {
          // Regular users: own tickets or same-place tickets (mirrors the list filter)
          shouldCount = _showMyTicketsOnly
              ? ticket.createdBy == widget.currentUser.id
              : (widget.currentUser.placeId != null
                  ? ticket.placeId == widget.currentUser.placeId
                  : ticket.createdBy == widget.currentUser.id);
        }

        if (shouldCount) {
          counts[ticket.status.value] = (counts[ticket.status.value] ?? 0) + 1;
        }
      }

      if (mounted && !_isDisposed) {
        setState(() => _ticketCounts = counts);
      }
    } catch (e) {
      debugPrint('❌ Error processing ticket counts: $e');
    }
  }

  Future<bool> _isSubticketAccessible(TicketModel subticket) async {
    if (subticket.parentTicketId == null) return false;

    try {
      final parentTicket = await supabase
          .from('tickets')
          .select('target_department_id')
          .eq('id', subticket.parentTicketId!)
          .maybeSingle();

      if (parentTicket == null) return false;

      return parentTicket['target_department_id'] ==
          widget.currentUser.departmentId;
    } catch (e) {
      debugPrint('❌ Error checking subticket accessibility: $e');
      return false;
    }
  }

  bool _isSubscriptionHealthy(TicketStatus status) {
    return _subscriptionHealthy[status] ?? false;
  }

  void _openChat(String ticketId) async {
    if (!mounted || _isDisposed) return;

    try {
      final currentTickets = _getCurrentTickets();
      final ticket = currentTickets.cast<TicketModel?>().firstWhere(
            (t) => t?.id == ticketId,
            orElse: () => null,
          );

      if (ticket == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket not found')),
        );
        return;
      }

      if (ticket.status != TicketStatus.inprogress &&
          ticket.status != TicketStatus.prefinished) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Chat is only available for tickets in progress or pre-finished status')),
        );
        return;
      }

      final response = await supabase
          .from('chat_rooms')
          .select('id')
          .eq('ticket_id', ticketId)
          .single();

      final chatRoomId = response['id'];

      if (MediaQuery.of(context).size.width < 768) {
        activeChatRoomId = chatRoomId;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatWidget(
              chatRoomId: chatRoomId,
              currentUser: widget.currentUser,
              isFullScreen: true,
              ticketNumber: ticket.ticketNumber,
              ticketTitle: ticket.title,
              onMessageSent: () {
                debugPrint(
                    '📱 Mobile chat message sent/read - refreshing counts');
                _refreshUnreadCounts();
              },
            ),
          ),
        ).then((_) {
          activeChatRoomId = null;
          _refreshUnreadCounts();
        });
      } else {
        activeChatRoomId = chatRoomId;
        setState(() {
          _selectedChatRoomId = chatRoomId;
          _selectedTicketId = ticketId;
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _refreshUnreadCounts();
          }
        });
      }

      setState(() {
        _unreadCounts[ticketId] = 0;
      });
    } catch (e) {
      debugPrint('❌ Error opening chat: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    }
  }

  void _closeChat() async {
    if (!mounted || _isDisposed) return;

    activeChatRoomId = null;
    setState(() {
      _selectedChatRoomId = null;
      _selectedTicketId = null;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isDisposed) {
        _refreshUnreadCounts();
      }
    });
  }

  int getUnreadCount(String ticketId) {
    return _unreadCounts[ticketId] ?? 0;
  }

  void _handleSubscriptionError(TicketStatus status, dynamic error) {
    if (!mounted || !_isVisible || _isDisposed) return;
    if (_isReconnecting) return;

    debugPrint('⚠️ Handling subscription error for ${status.value}: $error');

    _clearUserCacheForStatus(status);

    if (_shouldAttemptReconnect(error)) {
      _attemptReconnection(status);
    } else {
      debugPrint('❌ Error not recoverable, not attempting reconnect');
    }
  }

  bool _shouldAttemptReconnect(dynamic error) {
    if (error is PostgrestException) {
      if (error.code == 'PGRST301' || error.code == 'PGRST116') {
        return false;
      }
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('1006') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('websocket');
  }

  void _attemptReconnection(TicketStatus status) {
    if (!mounted || !_isVisible || _isDisposed || _isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;

    debugPrint(
        '🔄 Attempting reconnection for $status (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    final delay =
        Duration(seconds: math.min(2 << (_reconnectAttempts - 1), 30));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!mounted || !_isVisible || _isDisposed) return;

      _isReconnecting = false;

      if (_reconnectAttempts <= _maxReconnectAttempts) {
        debugPrint(
            '🔄 Executing reconnection attempt $_reconnectAttempts for $status');
        _clearUserCacheForStatus(status);
        _setupRealTimeTicketsForStatus(status);
      } else {
        debugPrint('❌ Max reconnection attempts reached for status $status');
        if (!_isDisposed) {
          _showConnectionIssueSnackBar();
        }
      }
    });
  }

  void _handleSubscriptionClosure(TicketStatus status) {
    if (!mounted || !_isVisible || _isDisposed) return;

    debugPrint('⚠️ Subscription closed for ${status.value}');

    _clearUserCacheForStatus(status);

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnection(status);
    }
  }

  void _showConnectionIssueSnackBar() {
    if (!mounted || _isDisposed) return;

    final l10n = AppLocalizations.safeOf(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.connectionIssuesDetectedPullToRefresh),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            _reconnectAttempts = 0;
            _reconnectAllStreams();
          },
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final l10n = AppLocalizations.safeOf(context);
    final currentStatus = _statuses[_tabController.index];
    final isCurrentSubscriptionHealthy = _isSubscriptionHealthy(currentStatus);
    final totalUnreadCount =
        _unreadCounts.values.fold(0, (sum, count) => sum + count);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;
    final hasChatOpen = _selectedChatRoomId != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        title: Row(
          children: [
            Text(
              l10n.tickets,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isCurrentSubscriptionHealthy &&
                !_isCurrentStatusLoading()) ...[
              const SizedBox(width: 8),
              const Icon(Icons.signal_wifi_off, size: 16, color: Colors.orange),
            ],
            if (totalUnreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  totalUnreadCount > 99 ? '99+' : totalUnreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.orange,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
              tabs: _statuses.map((status) {
                final count = _getTabCount(status);
                final title = _getTabTitle(status, l10n);
                final isSelected =
                    _tabController.index == _statuses.indexOf(status);

                return Tab(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.orange : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              count > 99 ? '99' : count.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          // My tickets / All place tickets toggle — only for normal users
          if (widget.currentUser.userType == UserType.user) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Tooltip(
                message: !_showMyTicketsOnly
                    ? l10n.showingMyTickets
                    : l10n.showingAllPlaceTickets,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _showMyTicketsOnly = !_showMyTicketsOnly;
                    });
                    // Re-process current data with new filter
                    _loadCurrentTabTickets();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showMyTicketsOnly
                          ? Colors.deepPurple
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !_showMyTicketsOnly
                              ? Icons.person
                              : Icons.location_city,
                          size: 14,
                          color: _showMyTicketsOnly
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showMyTicketsOnly ? l10n.showPlace : l10n.showMyTicket,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _showMyTicketsOnly
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: _showFilters ? Colors.orange : Colors.grey[700],
                  ),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                  tooltip: l10n.filtersAndSort,
                ),
                if (_activeFiltersCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _activeFiltersCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'it_solution') {
                  _showITSolutionTicketDialog();
                } else if (value == 'places_maintenance') {
                  _showPlacesMaintenanceTicketDialog();
                } else if (value == 'complaint') {
                  _showCreateComplaintDialog();
                } else if (value == 'individuals_maintenance') {
                  _showIndividualsMaintenanceTicketDialog();
                } else if (value == 'requests') {
                  _showRequestsTicketDialog();
                }
              },
              tooltip: l10n.createNewTicket,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'it_solution',
                  child: Row(
                    children: [
                      Icon(Icons.computer, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(l10n.itSolutionTicket),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'places_maintenance',
                  child: Row(
                    children: [
                      Icon(Icons.home_repair_service,
                          size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text(l10n.placesMaintenanceTicket),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'complaint',
                  child: Row(
                    children: [
                      Icon(Icons.report_problem,
                          size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(l10n.qualityComplaint),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'individuals_maintenance',
                  child: Row(
                    children: [
                      Icon(Icons.person_pin, size: 18, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(l10n.individualsMaintenanceTicket),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'requests',
                  child: Row(
                    children: [
                      Icon(Icons.request_page, size: 18, color: Colors.teal),
                      SizedBox(width: 8),
                      Text(l10n.requestsTicket),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: Colors.white),
                    if (!isMobile) ...[
                      SizedBox(width: 4),
                      Text(
                        l10n.create,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[700]),
            onPressed: _refreshData,
            tooltip: l10n.refresh,
          ),
          if (_isReconnecting)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          Expanded(
            flex: hasChatOpen ? 2 : 1,
            child: Column(
              children: [
                // In the build() method's body Column, add this after the opening Column:
                if (_showConnectionWarning) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.orange.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.connectionIssuesDetected,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _reconnectAttempts = 0;
                            _reconnectAllStreams();
                          },
                          child: Text(
                            l10n.reconnect,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isCurrentSubscriptionHealthy && !_isCurrentStatusLoading())
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.orange.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.connectionIssuesDetected,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _reconnectAttempts = 0;
                            _reconnectAllStreams();
                          },
                          child: Text(
                            l10n.retry,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_showFilters ||
                    _searchQuery.isNotEmpty ||
                    _activeFiltersCount > 0)
                  _buildSearchAndFiltersSection(isMobile),
                Expanded(
                  child: _buildTicketList(isMobile, isTablet),
                ),
              ],
            ),
          ),
          if (hasChatOpen)
            Expanded(
              flex: 1,
              child: _buildChatPanel(),
            ),
        ],
      ),
    );
  }

// 1. UPDATE: _buildSearchAndFiltersSection - Add localization
  Widget _buildSearchAndFiltersSection(bool isMobile) {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.searchTicketsPlacesCreators,
              hintStyle: TextStyle(fontSize: isMobile ? 13 : 14),
              prefixIcon: Icon(Icons.search, size: isMobile ? 20 : 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          if (_showFilters) ...[
            const SizedBox(height: 12),
            if (isMobile) _buildMobileFilters() else _buildDesktopFilters(),
            if (_activeFiltersCount > 0) ...[
              const SizedBox(height: 12),
              _buildActiveFiltersChips(),
            ],
          ],
        ],
      ),
    );
  }

// 2. UPDATE: _buildMobileFilters - Add localization
  Widget _buildMobileFilters() {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPlaceFilter()),
            const SizedBox(width: 8),
            Expanded(child: _buildCreatorFilter()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDateRangeFilter()),
            const SizedBox(width: 8),
            Expanded(child: _buildSortOptions()),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(l10n.clearAllFilters),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

// 3. UPDATE: _buildDesktopFilters - Add localization
  Widget _buildDesktopFilters() {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: _buildPlaceFilter()),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildCreatorFilter()),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildDateRangeFilter()),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildSortOptions()),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(l10n.clearAll),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

// 4. UPDATE: _buildPlaceFilter - Add localization
  Widget _buildPlaceFilter() {
    final l10n = AppLocalizations.safeOf(context);

    return DropdownButtonFormField<String>(
      value: _selectedPlace,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.place,
        labelStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(l10n.allPlaces,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        ..._availablePlaces.map((place) {
          final lang = Localizations.localeOf(context).languageCode;
          final displayName = (lang == 'ar' &&
                  place['name_ar'] != null &&
                  place['name_ar']!.isNotEmpty)
              ? place['name_ar']!
              : (lang == 'en' &&
                      place['name_en'] != null &&
                      place['name_en']!.isNotEmpty)
                  ? place['name_en']!
                  : (place['name'] ?? '');
          return DropdownMenuItem(
            value: place['id'],
            child: Text(
              displayName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedPlace = value;
        });
        _loadCurrentTabTickets();
      },
    );
  }

// 5. UPDATE: _buildCreatorFilter - Add localization
  Widget _buildCreatorFilter() {
    final l10n = AppLocalizations.safeOf(context);

    return DropdownButtonFormField<String>(
      value: _selectedCreator,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.creator,
        labelStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(l10n.allCreators,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        ..._availableCreators.map((creator) {
          return DropdownMenuItem(
            value: creator['id'],
            child: Text(
              creator['name']!,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCreator = value;
        });
        _loadCurrentTabTickets();
      },
    );
  }

// 6. UPDATE: _buildDateRangeFilter - Add localization
  Widget _buildDateRangeFilter() {
    final l10n = AppLocalizations.safeOf(context);

    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _selectedDateRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.orange,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          setState(() {
            _selectedDateRange = picked;
          });
          _loadCurrentTabTickets();
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.dateRange,
          labelStyle: const TextStyle(fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.grey[50],
          suffixIcon: _selectedDateRange != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedDateRange = null;
                    });
                    _loadCurrentTabTickets();
                  },
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          _selectedDateRange != null
              ? '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'
              : l10n.allDates,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

// 7. UPDATE: _buildSortOptions - Add localization
  Widget _buildSortOptions() {
    final l10n = AppLocalizations.safeOf(context);

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'date' || value == 'priority') {
          setState(() {
            if (_sortBy == value) {
              _sortAscending = !_sortAscending;
            } else {
              _sortBy = value;
              _sortAscending = false;
            }
          });
          _loadCurrentTabTickets();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'date',
          child: Row(
            children: [
              Icon(
                _sortBy == 'date'
                    ? (_sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.access_time,
                size: 18,
                color: _sortBy == 'date' ? Colors.orange : null,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.sortByDate,
                style: TextStyle(
                  color: _sortBy == 'date' ? Colors.orange : null,
                  fontWeight: _sortBy == 'date' ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'priority',
          child: Row(
            children: [
              Icon(
                _sortBy == 'priority'
                    ? (_sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.priority_high,
                size: 18,
                color: _sortBy == 'priority' ? Colors.orange : null,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.sortByPriority,
                style: TextStyle(
                  color: _sortBy == 'priority' ? Colors.orange : null,
                  fontWeight: _sortBy == 'priority' ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(
              _sortBy == 'date' ? Icons.access_time : Icons.priority_high,
              size: 18,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _sortBy == 'date' ? l10n.byDate : l10n.byPriority,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

// 8. UPDATE: _buildActiveFiltersChips - Add localization
  Widget _buildActiveFiltersChips() {
    final l10n = AppLocalizations.safeOf(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_selectedPlace != null)
          Chip(
            label: Text(
              () {
                final place = _availablePlaces.firstWhere((p) => p['id'] == _selectedPlace);
                final lang = Localizations.localeOf(context).languageCode;
                final name = (lang == 'ar' && place['name_ar'] != null && place['name_ar']!.isNotEmpty)
                    ? place['name_ar']!
                    : (lang == 'en' && place['name_en'] != null && place['name_en']!.isNotEmpty)
                        ? place['name_en']!
                        : (place['name'] ?? '');
                return '${l10n.place}: $name';
              }(),
              style: const TextStyle(fontSize: 12),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _selectedPlace = null;
              });
              _loadCurrentTabTickets();
            },
            backgroundColor: Colors.orange.withOpacity(0.1),
            deleteIconColor: Colors.orange,
          ),
        if (_selectedCreator != null)
          Chip(
            label: Text(
              '${l10n.creator}: ${_availableCreators.firstWhere((c) => c['id'] == _selectedCreator)['name']}',
              style: const TextStyle(fontSize: 12),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _selectedCreator = null;
              });
              _loadCurrentTabTickets();
            },
            backgroundColor: Colors.blue.withOpacity(0.1),
            deleteIconColor: Colors.blue,
          ),
        if (_selectedDateRange != null)
          Chip(
            label: Text(
              '${l10n.date}: ${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}',
              style: const TextStyle(fontSize: 12),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _selectedDateRange = null;
              });
              _loadCurrentTabTickets();
            },
            backgroundColor: Colors.green.withOpacity(0.1),
            deleteIconColor: Colors.green,
          ),
      ],
    );
  }

// 13. NEW: Helper method to get status display name
  String _getStatusDisplayName(TicketStatus status, AppLocalizations l10n) {
    switch (status) {
      case TicketStatus.pending:
        return l10n.pending.toLowerCase();
      case TicketStatus.inprogress:
        return l10n.inProgress.toLowerCase();
      case TicketStatus.prefinished:
        return l10n.prefinished.toLowerCase();
      case TicketStatus.closed:
        return l10n.closed.toLowerCase();
      case TicketStatus.wrongInfo:
        return l10n.wrongInfo.toLowerCase();
      case TicketStatus.deleted:
        return l10n.deleted.toLowerCase();
    }
  }

// REPLACE _buildTicketList method in _TicketsScreenState

// 10. UPDATE: _buildTicketList - Add localization
  Widget _buildTicketList(bool isMobile, bool isTablet) {
    final l10n = AppLocalizations.safeOf(context);
    final tickets = _getCurrentTickets();
    final isLoading = _isCurrentStatusLoading();
    final currentStatus = _statuses[_tabController.index];
    final screenWidth = MediaQuery.of(context).size.width;

    final double listWidth;
    if (screenWidth >= 1400) {
      listWidth = 1320;
    } else if (screenWidth >= 1200) {
      listWidth = 1140;
    } else if (screenWidth >= 992) {
      listWidth = 960;
    } else if (screenWidth >= 768) {
      listWidth = 720;
    } else {
      listWidth = screenWidth;
    }

    final isTablett = MediaQuery.of(context).size.width < 992;
    final bottomNavBarHeight = isTablett && !kIsWeb ? 90.0 : 0.0;

    if (isLoading && _isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tickets.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.noTicketsFound} ${_getStatusDisplayName(currentStatus, l10n)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isNotEmpty ||
                _selectedPlace != null ||
                _selectedCreator != null ||
                _selectedDateRange != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.tryAdjustingFilters,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshData();
        await Future.delayed(const Duration(seconds: 1));
      },
      child: Center(
        child: Container(
          width: listWidth,
          child: ListView.builder(
            key: ValueKey('ticket_list_$currentStatus'),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tickets.length,
            padding: EdgeInsets.only(
              left: isMobile || isTablet ? 16 : 24,
              right: isMobile || isTablet ? 16 : 24,
              top: 8,
              bottom: bottomNavBarHeight + 8,
            ),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: EnhancedTicketCard(
                  key: ValueKey(ticket.id),
                  ticket: ticket,
                  currentUser: widget.currentUser,
                  onChatPressed: () => _openChat(ticket.id),
                  onRefresh: _refreshData,
                  unreadCount: getUnreadCount(ticket.id),
                  currentTabStatus: currentStatus,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

// 11. UPDATE: _buildChatPanel - Add localization
  Widget _buildChatPanel() {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chat,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (_selectedTicketId != null)
                        Builder(
                          builder: (context) {
                            final tickets = _getCurrentTickets();
                            final ticket =
                                tickets.cast<TicketModel?>().firstWhere(
                                      (t) => t?.id == _selectedTicketId,
                                      orElse: () => null,
                                    );
                            return Text(
                              ticket?.ticketNumber ?? l10n.unknown,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[700]),
                  onPressed: _closeChat,
                  tooltip: l10n.closeChat,
                ),
              ],
            ),
          ),
          Expanded(
            child: ChatWidget(
              key: ValueKey(_selectedChatRoomId),
              chatRoomId: _selectedChatRoomId!,
              currentUser: widget.currentUser,
              onMessageSent: () {
                _refreshUnreadCounts();
              },
            ),
          ),
        ],
      ),
    );
  }

// 12. UPDATE: _getTabTitle - Add localization
  String _getTabTitle(TicketStatus status, AppLocalizations l10n) {
    switch (status) {
      case TicketStatus.pending:
        return l10n.pending.toUpperCase();
      case TicketStatus.inprogress:
        return l10n.inProgress.toUpperCase();
      case TicketStatus.prefinished:
        return l10n.prefinished.toUpperCase();
      case TicketStatus.closed:
        return l10n.closed.toUpperCase();
      case TicketStatus.wrongInfo:
        return l10n.wrongInfo.toUpperCase();
      case TicketStatus.deleted:
        return l10n.deleted.toUpperCase();
    }
  }

  int _getTabCount(TicketStatus status) {
    return _ticketCounts[status.value] ?? 0;
  }

  List<TicketModel> _getCurrentTickets() {
    final currentStatus = _statuses[_tabController.index];
    return _ticketsByStatus[currentStatus] ?? [];
  }

  bool _isCurrentStatusLoading() {
    final currentStatus = _statuses[_tabController.index];
    return _loadingByStatus[currentStatus] ?? false;
  }

  void _showITSolutionTicketDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ITSolutionTicketScreen(
            currentUser: widget.currentUser,
            onTicketCreated: _refreshData,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => ITSolutionTicketDialog(
          currentUser: widget.currentUser,
          onTicketCreated: _refreshData,
        ),
      );
    }
  }

  void _showPlacesMaintenanceTicketDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlacesMaintenanceTicketScreen(
            currentUser: widget.currentUser,
            onTicketCreated: _refreshData,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => PlacesMaintenanceTicketDialog(
          currentUser: widget.currentUser,
          onTicketCreated: _refreshData,
        ),
      );
    }
  }

  void _showIndividualsMaintenanceTicketDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IndividualsMaintenanceTicketScreen(
            currentUser: widget.currentUser,
            onTicketCreated: _refreshData,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => IndividualsMaintenanceTicketDialog(
          currentUser: widget.currentUser,
          onTicketCreated: _refreshData,
        ),
      );
    }
  }

  void _showRequestsTicketDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestsTicketScreen(
            currentUser: widget.currentUser,
            onTicketCreated: _refreshData,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => RequestsTicketDialog(
          currentUser: widget.currentUser,
          onTicketCreated: _refreshData,
        ),
      );
    }
  }

  void _showCreateTicketDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateTicketDialog(
        currentUser: widget.currentUser,
        onTicketCreated: _refreshData,
      ),
    );
  }

  void _showCreateComplaintDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateComplaintScreen(
            currentUser: widget.currentUser,
            onComplaintCreated: _refreshData,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => CreateComplaintDialog(
          currentUser: widget.currentUser,
          onComplaintCreated: _refreshData,
        ),
      );
    }
  }

  // Add this at the top of your tickets.dart file or in a utils file
  bool _shouldUseFullScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 992;
  }
}

// ENHANCED: Mobile-optimized ticket card with approval actions
class EnhancedTicketCard extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onChatPressed;
  final VoidCallback onRefresh;
  final int unreadCount;
  final TicketStatus currentTabStatus;

  const EnhancedTicketCard({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onChatPressed,
    required this.onRefresh,
    this.unreadCount = 0,
    required this.currentTabStatus,
  });

  @override
  State<EnhancedTicketCard> createState() => _EnhancedTicketCardState();
}

class _EnhancedTicketCardState extends State<EnhancedTicketCard> {
  bool _isExpanded = false;
  bool _loadingUserInfo = false;
  bool _loadingSubtickets = false;
  bool _loadingExpandedData = false;

  // NEW: Check-in status tracking
  TicketCheckInStatus? _checkInStatus;
  bool _loadingCheckInStatus = false;
  Timer? _checkInTimer;

  // User info cache
  String? _creatorName;
  String? _assignedToName;
  String? _placeName;
  String? _placeNameEn;
  String? _placeNameAr;
  String? _departmentName;
  String? _departmentNameEn;
  String? _departmentNameAr;
  String? _problemTitleName;
  String? _problemTitleNameEn;
  String? _problemTitleNameAr;
  String? _partModelName;

  // Expanded data
  List<TicketModel> _subtickets = [];
  Map<String, dynamic>? _ticketReport;
  Map<String, dynamic>? _ticketApproval;
  Map<String, dynamic>? _rejectionInfo;
  Map<String, dynamic>? _wrongInfoFeedback;
  List<Map<String, dynamic>> _ticketAttachments = [];
  List<Map<String, dynamic>> _reportAttachments = [];
  List<Map<String, dynamic>> _activityLogs = [];

  @override
  void initState() {
    super.initState();
    _loadBasicUserInfo();
    _loadSubtickets();
    _loadCheckInStatus();
  }

  @override
  void dispose() {
    _checkInTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(EnhancedTicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id ||
        oldWidget.currentTabStatus != widget.currentTabStatus) {
      _clearCachedData();
      _loadBasicUserInfo();
      _loadSubtickets();
      _loadCheckInStatus();
    }
  }

  void _clearCachedData() {
    _creatorName = null;
    _assignedToName = null;
    _placeName = null;
    _departmentName = null;
    _problemTitleName = null;
    _partModelName = null;
    _subtickets.clear();
    _checkInStatus = null;
    _checkInTimer?.cancel();
  }

  // NEW: Load current check-in status for this ticket
  Future<void> _loadCheckInStatus() async {
    if (widget.ticket.assignedTo != widget.currentUser.id) return;
    if (widget.ticket.status != TicketStatus.inprogress) return;

    setState(() => _loadingCheckInStatus = true);

    try {
      final status = await TrackingService.getCurrentCheckInStatus(
        widget.ticket.id,
        widget.currentUser.id,
      );

      if (mounted) {
        setState(() {
          _checkInStatus = status;
          _loadingCheckInStatus = false;
        });

        // Start timer to update elapsed time if checked in
        if (_checkInStatus != null) {
          _startCheckInTimer();
        }
      }
    } catch (e) {
      print('Error loading check-in status: $e');
      if (mounted) {
        setState(() => _loadingCheckInStatus = false);
      }
    }
  }

  // NEW: Timer to update elapsed time
  void _startCheckInTimer() {
    _checkInTimer?.cancel();
    _checkInTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && _checkInStatus != null) {
        setState(() {}); // Trigger rebuild to update elapsed time
      } else {
        timer.cancel();
      }
    });
  }

  // NEW: Handle check-in
  Future<void> _handleCheckIn() async {
    try {
      final success = await TrackingService.checkIn(
        ticketId: widget.ticket.id,
        userId: widget.currentUser.id,
      );

      if (success && mounted) {
        await _loadCheckInStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                    'Checked in at ${DateFormat('HH:mm').format(DateTime.now())}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking in: $e')),
        );
      }
    }
  }

  // NEW: Handle check-out (show dialog)
  Future<void> _handleCheckOut() async {
    if (_checkInStatus == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckOutDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        checkInStatus: _checkInStatus!,
        onCheckOut: () {
          _loadCheckInStatus();
          widget.onRefresh();
        },
      ),
    );
  }

  // NEW: Show add note dialog
  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTrackingNoteDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onNoteAdded: widget.onRefresh,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _localizedEntityName(String? base, String? en, String? ar,
      [String fallback = '']) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ar' && ar != null && ar.isNotEmpty) return ar;
    if (lang == 'en' && en != null && en.isNotEmpty) return en;
    return base ?? fallback;
  }

  Future<void> _loadBasicUserInfo() async {
    if (_loadingUserInfo) return;
    setState(() => _loadingUserInfo = true);

    try {
      // Load creator name
      try {
        final creatorResponse = await supabase
            .from('users')
            .select('full_name')
            .eq('id', widget.ticket.createdBy)
            .maybeSingle();

        if (creatorResponse != null && mounted) {
          _creatorName = creatorResponse['full_name'];
        }
      } catch (e) {
        print('Error loading creator: $e');
      }

      // Load assigned user name
      if (widget.ticket.assignedTo != null) {
        try {
          final assignedResponse = await supabase
              .from('users')
              .select('full_name')
              .eq('id', widget.ticket.assignedTo!)
              .maybeSingle();

          if (assignedResponse != null && mounted) {
            _assignedToName = assignedResponse['full_name'];
          }
        } catch (e) {
          print('Error loading assigned user: $e');
        }
      }

      // Load place name (only if place_id exists)
      if (widget.ticket.placeId != null) {
        try {
          final placeResponse = await supabase
              .from('places')
              .select('name, name_en, name_ar')
              .eq('id', widget.ticket.placeId!)
              .maybeSingle();

          if (placeResponse != null && mounted) {
            _placeName = placeResponse['name'];
            _placeNameEn = placeResponse['name_en'];
            _placeNameAr = placeResponse['name_ar'];
          }
        } catch (e) {
          print('Error loading place: $e');
          _placeName = 'Unknown Place';
        }
      } else {
        // For IT tickets or tickets without a specific place
        if (mounted) {
          _placeName = 'N/A';
        }
      }

      // Load department name (ALWAYS - this is required)
      try {
        final deptResponse = await supabase
            .from('departments')
            .select('name, name_en, name_ar')
            .eq('id', widget.ticket.targetDepartmentId)
            .maybeSingle();

        if (deptResponse != null && mounted) {
          _departmentName = deptResponse['name'];
          _departmentNameEn = deptResponse['name_en'];
          _departmentNameAr = deptResponse['name_ar'];
        } else {
          print(
              'Department not found for ID: ${widget.ticket.targetDepartmentId}');
          _departmentName = 'Unknown Department';
        }
      } catch (e) {
        print('Error loading department: $e');
        _departmentName = 'Unknown Department';
      }

      // Load problem title (if exists)
      if (widget.ticket.problemTitleId != null) {
        try {
          final problemResponse = await supabase
              .from('problem_titles')
              .select('title, title_en, title_ar')
              .eq('id', widget.ticket.problemTitleId!)
              .maybeSingle();

          if (problemResponse != null && mounted) {
            _problemTitleName = problemResponse['title'];
            _problemTitleNameEn = problemResponse['title_en'];
            _problemTitleNameAr = problemResponse['title_ar'];
          }
        } catch (e) {
          print('Error loading problem title: $e');
        }
      }

      // Load part/model info (if exists)
      if (widget.ticket.modelNumberId != null) {
        try {
          final partResponse = await supabase
              .from('parts')
              .select('name, model_number')
              .eq('id', widget.ticket.modelNumberId!)
              .maybeSingle();

          if (partResponse != null && mounted) {
            _partModelName =
                '${partResponse['model_number']} - ${partResponse['name']}';
          }
        } catch (e) {
          print('Error loading part info: $e');
        }
      }

      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    } catch (e) {
      print('Error in _loadBasicUserInfo: $e');
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    }
  }

  Future<void> _loadExpandedData() async {
    if (_loadingExpandedData) return;
    setState(() => _loadingExpandedData = true);

    try {
      final futures = <Future>[];

      futures.add(
        supabase
            .from('ticket_attachments')
            .select('*')
            .eq('ticket_id', widget.ticket.id)
            .order('created_at', ascending: true)
            .then((response) => _ticketAttachments = response),
      );

      futures.add(
        supabase
            .from('activity_logs')
            .select('*, users(full_name)')
            .eq('record_id', widget.ticket.id)
            .eq('table_name', 'tickets')
            .order('created_at', ascending: false)
            .limit(10)
            .then((response) => _activityLogs = response),
      );

      futures.addAll([
        _loadTicketReport(),
        _loadApprovalHistory(),
      ]);

      await Future.wait(futures);

      if (mounted) {
        setState(() => _loadingExpandedData = false);
      }
    } catch (e) {
      print('Error loading expanded data: $e');
      if (mounted) {
        setState(() => _loadingExpandedData = false);
      }
    }
  }

  Future<void> _loadTicketReport() async {
    try {
      final response = await supabase
          .from('ticket_reports')
          .select('*, users(full_name), ticket_report_attachments(*)')
          .eq('ticket_id', widget.ticket.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        _ticketReport = response.first;
        _reportAttachments = List<Map<String, dynamic>>.from(
            _ticketReport!['ticket_report_attachments'] ?? []);
      }
    } catch (e) {
      print('Error loading ticket report: $e');
    }
  }

  Future<void> _loadApprovalHistory() async {
    try {
      final response = await supabase
          .from('ticket_approvals')
          .select('*, users(full_name)')
          .eq('ticket_id', widget.ticket.id)
          .order('created_at', ascending: false)
          .limit(5);

      if (response.isNotEmpty) {
        for (final approval in response) {
          final isApproved = approval['is_approved'];

          if (isApproved == true) {
            _ticketApproval = approval;
            break;
          } else if (isApproved == false) {
            final rejectionReason =
                approval['rejection_reason']?.toString() ?? '';

            if (rejectionReason.startsWith('WRONG INFO:')) {
              _wrongInfoFeedback = approval;
            } else {
              _rejectionInfo = approval;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading approval history: $e');
    }
  }

  Future<void> _loadSubtickets() async {
    if (_loadingSubtickets) return;
    setState(() => _loadingSubtickets = true);

    try {
      final subtickets = await TicketService.getSubtickets(widget.ticket.id);
      if (mounted) {
        setState(() {
          _subtickets = subtickets;
          _loadingSubtickets = false;
        });
      }
    } catch (e) {
      print('Error loading subtickets: $e');
      if (mounted) {
        setState(() {
          _subtickets = [];
          _loadingSubtickets = false;
        });
      }
    }
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && !_loadingExpandedData) {
      _loadExpandedData();
    }
  }

  Color _getStatusColor() {
    switch (widget.ticket.status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.inprogress:
        return Colors.blue;
      case TicketStatus.prefinished:
        return Colors.amber;
      case TicketStatus.closed:
        return Colors.green;
      case TicketStatus.wrongInfo:
        return Colors.red;
      case TicketStatus.deleted:
        return Colors.grey;
    }
  }

  Color _getPriorityColor() {
    switch (widget.ticket.priority) {
      case PriorityType.low:
        return Colors.green;
      case PriorityType.medium:
        return Colors.orange;
      case PriorityType.high:
        return Colors.red;
      case PriorityType.urgent:
        return Colors.purple;
    }
  }

  IconData _getTicketIcon() {
    if (widget.ticket.priority == PriorityType.urgent) {
      return Icons.priority_high;
    } else if (widget.ticket.priority == PriorityType.high) {
      return Icons.report_problem;
    } else {
      switch (widget.ticket.status) {
        case TicketStatus.pending:
          return Icons.pending;
        case TicketStatus.inprogress:
          return Icons.work;
        case TicketStatus.prefinished:
          return Icons.check_circle_outline;
        case TicketStatus.closed:
          return Icons.check_circle;
        case TicketStatus.wrongInfo:
          return Icons.error_outline;
        default:
          return Icons.confirmation_number;
      }
    }
  }

  bool _canShowChat() {
    final isActiveStatus = widget.ticket.status == TicketStatus.inprogress ||
        widget.ticket.status == TicketStatus.prefinished;
    if (!isActiveStatus) return false;

    // Regular users and super-users can only chat on tickets they created
    // or tickets assigned to them. Admins and higher can always chat.
    final isRegularUser = widget.currentUser.userType == UserType.user ||
        widget.currentUser.userType == UserType.superUser;
    if (isRegularUser) {
      return widget.ticket.createdBy == widget.currentUser.id ||
          widget.ticket.assignedTo == widget.currentUser.id;
    }

    return true;
  }

// UPDATE: _canCreatorApprove to exclude under_supervision tickets
  bool _canCreatorApprove() {
    return widget.ticket.createdBy == widget.currentUser.id &&
        widget.ticket.status == TicketStatus.prefinished &&
        !widget.ticket.underSupervision; // NEW: Exclude supervision tickets
  }

// NEW: Show mark finished dialog
  void _showMarkFinishedDialog() {
    showDialog(
      context: context,
      builder: (context) => FinishTicketDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onTicketFinished: widget.onRefresh,
        isUnderSupervision: false, // Regular finish
      ),
    );
  }

// NEW: Show mark under supervision dialog
  void _showMarkUnderSupervisionDialog() {
    showDialog(
      context: context,
      builder: (context) => FinishTicketDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onTicketFinished: widget.onRefresh,
        isUnderSupervision: true, // Under supervision
      ),
    );
  }
// REPLACE _showRejectSupervisionDialog method in _EnhancedTicketCardState

  void _showRejectSupervisionDialog() {
    final l10n = AppLocalizations.safeOf(context);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => OptimizedDialog(
        title: l10n.rejectFromSupervision,
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.thisWillReturnTicketInProgress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l10n.rejectionReasonRequired,
                hintText: l10n.whyWorkBeingRejected,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 4,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.pleaseProvideRejectionReason),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final success = await TicketService.rejectTicketFromSupervision(
                ticketId: widget.ticket.id,
                rejectionReason: reasonController.text.trim(),
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.ticketRejectedReturnedInProgress),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                widget.onRefresh();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cancel, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.reject,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColorForTicket(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.inprogress:
        return Colors.blue;
      case TicketStatus.prefinished:
        return Colors.amber;
      case TicketStatus.closed:
        return Colors.green;
      case TicketStatus.wrongInfo:
        return Colors.red;
      case TicketStatus.deleted:
        return Colors.grey;
    }
  }

// 1. UPDATE: _buildCompactHeader - Add localization
  Widget _buildCompactHeader() {
    final l10n = AppLocalizations.safeOf(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;
    final isTablet = screenWidth >= 500 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return InkWell(
      onTap: _toggleExpanded,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            // Check-in status indicator at the top
            if (_checkInStatus != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.15),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n.checkedInAt} ${DateFormat('HH:mm').format(_checkInStatus!.checkInTime)} • ${_formatDuration(DateTime.now().difference(_checkInStatus!.checkInTime))} ${l10n.elapsed}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Main header line
            if (isMobile)
              _buildMobileLayout()
            else if (isTablet)
              _buildTabletLayout()
            else
              _buildDesktopLayout(),

          ],
        ),
      ),
    );
  }

// UPDATE: Mobile layout to include supervision badge
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Icon + Ticket Number + Actions
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor().withOpacity(0.8),
                    _getStatusColor().withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTicketIcon(),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.ticket.ticketNumber,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            _buildActionButtons(isMobile: true),
          ],
        ),

        const SizedBox(height: 10),

        // Row 2: Title
        Text(
          widget.ticket.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 10),

        // Row 3: Status and Priority badges + Supervision badge + Sub-tickets badge
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildStatusBadge(),
            _buildPriorityBadge(),
            if (widget.ticket.underSupervision &&
                widget.ticket.status == TicketStatus.prefinished)
              _buildSupervisionBadge(),
            if (_subtickets.isNotEmpty)
              _buildSubticketsBadge(),
          ],
        ),

        const SizedBox(height: 10),

        // Grid layout for ticket information
        _buildMobileInfoGrid(),
      ],
    );
  }

// 5. UPDATE: _buildSupervisionBadge - Add localization
  Widget _buildSupervisionBadge() {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 6, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade400,
            Colors.deepPurple.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility,
            size: isMobile ? 12 : 10,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            l10n.underSupervision.toUpperCase(),
            style: TextStyle(
              fontSize: isMobile ? 10 : 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

// 2. UPDATE: Mobile info grid - free style without boxes, icon + value only
  Widget _buildMobileInfoGrid() {
    return Column(
      children: [
        // Row 1: Creator | Place
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFreeGridItem(
                Icons.person_outline,
                _loadingUserInfo ? 'Loading...' : _creatorName ?? 'Unknown',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFreeGridItem(
                Icons.location_on_outlined,
                _loadingUserInfo ? 'Loading...' : _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, 'Unknown'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Row 2: Department | Date
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFreeGridItem(
                Icons.business_outlined,
                _loadingUserInfo ? 'Loading...' : _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, 'Unknown'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFreeGridItem(
                Icons.access_time,
                DateFormat('dd/MM/yy').format(widget.ticket.createdAt),
              ),
            ),
          ],
        ),

        // Row 3: Assigned To (only if exists, takes full width)
        if (widget.ticket.assignedTo != null) ...[
          const SizedBox(height: 8),
          _buildFreeGridItem(
            Icons.assignment_ind,
            _loadingUserInfo ? 'Loading...' : _assignedToName ?? 'Unknown',
          ),
        ],
      ],
    );
  }

// 3. NEW: Free grid item without box - just icon and value
  Widget _buildFreeGridItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

// Replace _buildTabletLayout method in EnhancedTicketCard
  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Icon + Ticket Number + Title + Actions
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor().withOpacity(0.8),
                    _getStatusColor().withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTicketIcon(),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.ticket.ticketNumber,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.ticket.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildActionButtons(isMobile: false),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Status badges and info
        Row(
          children: [
            _buildStatusBadge(),
            const SizedBox(width: 6),
            _buildPriorityBadge(),
            if (widget.ticket.underSupervision &&
                widget.ticket.status == TicketStatus.prefinished) ...[
              const SizedBox(width: 6),
              _buildSupervisionBadge(),
            ],
            if (_subtickets.isNotEmpty) ...[
              const SizedBox(width: 6),
              _buildSubticketsBadge(),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildCompactInfo(
                    Icons.person_outline,
                    _loadingUserInfo ? 'Loading...' : _creatorName ?? 'Unknown',
                  ),
                  _buildCompactInfo(
                    Icons.location_on_outlined,
                    _loadingUserInfo ? 'Loading...' : _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, 'Unknown'),
                  ),
                  _buildCompactInfo(
                    Icons.business_outlined,
                    _loadingUserInfo
                        ? 'Loading...'
                        : _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, 'Unknown'),
                  ),
                  _buildCompactInfo(
                    Icons.access_time,
                    DateFormat('dd/MM/yy').format(widget.ticket.createdAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

// 4. NEW: Desktop layout (original)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getStatusColor().withOpacity(0.8),
                _getStatusColor().withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getTicketIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.ticket.ticketNumber,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_subtickets.isNotEmpty) ...[
                    _buildSubticketsBadge(),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.ticket.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildDesktopInfoLine(),
            ],
          ),
        ),
        _buildActionButtons(isMobile: false),
      ],
    );
  }

// 6. UPDATE: _buildActionButtons - Add localization
  Widget _buildActionButtons({required bool isMobile}) {
    final l10n = AppLocalizations.safeOf(context);
    final buttonSize = isMobile ? 40.0 : 36.0;
    final iconSize = isMobile ? 22.0 : 18.0;
    final buttonPadding = isMobile ? 10.0 : 8.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canShowChat())
          Padding(
            padding: EdgeInsets.symmetric(horizontal: buttonPadding),
            child: Stack(
              children: [
                Tooltip(
                  message: l10n.openChat,
                  child: IconButton(
                    icon: Icon(Icons.chat_bubble_outline, size: iconSize),
                    onPressed: widget.onChatPressed,
                    padding: EdgeInsets.all(buttonPadding),
                    constraints: BoxConstraints(
                      minWidth: buttonSize,
                      minHeight: buttonSize,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                if (widget.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 4 : 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
                      ),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 18 : 14,
                        minHeight: isMobile ? 18 : 14,
                      ),
                      child: Text(
                        widget.unreadCount > 99
                            ? '99+'
                            : widget.unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 10 : 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_canCreatorApprove())
          Padding(
            padding: EdgeInsets.symmetric(horizontal: buttonPadding),
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: iconSize,
                  color: Colors.grey[700],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'approve',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.approveAndClose),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'reject',
                  child: Row(
                    children: [
                      const Icon(Icons.edit,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.requestChanges),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                _showCreatorApprovalDialog(value == 'approve');
              },
            ),
          ),
        if (_getOtherActions().isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: buttonPadding),
            child: PopupMenuButton<VoidCallback>(
              padding: EdgeInsets.all(buttonPadding),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: iconSize,
                  color: Colors.grey[600],
                ),
              ),
              onSelected: (callback) => callback(),
              itemBuilder: (context) => _getOtherActions()
                  .map((action) => PopupMenuItem<VoidCallback>(
                        value: action['onPressed'],
                        child: Row(
                          children: [
                            Icon(action['icon'],
                                size: iconSize, color: action['color']),
                            SizedBox(width: isMobile ? 10 : 8),
                            Text(
                              action['label'],
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 12,
                                color: action['color'],
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        SizedBox(width: buttonPadding),
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[600],
          size: iconSize,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getOtherActions() {
    final allActions = _getAvailableActions();
    // Approve/reject have dedicated buttons — exclude them from the ••• menu
    return allActions.where((action) {
      final label = action['label'] as String;
      return !label.contains('Approve') &&
          !label.contains('Request') &&
          label != 'Review & Approve';
    }).toList();
  }

  // Mobile info stack
  Widget _buildMobileInfoStack() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildCompactInfo(Icons.person_outline,
                _loadingUserInfo ? 'Loading...' : _creatorName ?? 'Unknown'),
            _buildDivider(),
            _buildStatusBadge(),
            const SizedBox(width: 6),
            _buildPriorityBadge(),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildCompactInfo(Icons.location_on_outlined,
                _loadingUserInfo ? 'Loading...' : _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, 'Unknown')),
            _buildDivider(),
            _buildCompactInfo(Icons.business_outlined,
                _loadingUserInfo ? 'Loading...' : _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, 'Unknown')),
          ],
        ),
        if (widget.ticket.assignedTo != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              _buildCompactInfo(
                  Icons.assignment_ind,
                  _loadingUserInfo
                      ? 'Loading...'
                      : _assignedToName ?? 'Unknown'),
              _buildDivider(),
              _buildCompactInfo(Icons.access_time,
                  DateFormat('dd/MM/yy').format(widget.ticket.createdAt)),
            ],
          ),
        ] else ...[
          const SizedBox(height: 4),
          _buildCompactInfo(Icons.access_time,
              DateFormat('dd/MM/yy').format(widget.ticket.createdAt)),
        ],
      ],
    );
  }

  // Desktop info line (original)
  Widget _buildDesktopInfoLine() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCompactInfo(Icons.person_outline,
              _loadingUserInfo ? 'Loading...' : _creatorName ?? 'Unknown'),
          _buildDivider(),
          _buildCompactInfo(Icons.location_on_outlined,
              _loadingUserInfo ? 'Loading...' : _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, 'Unknown')),
          _buildDivider(),
          _buildCompactInfo(Icons.business_outlined,
              _loadingUserInfo ? 'Loading...' : _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, 'Unknown')),
          if (widget.ticket.assignedTo != null) ...[
            _buildDivider(),
            _buildCompactInfo(Icons.assignment_ind,
                _loadingUserInfo ? 'Loading...' : _assignedToName ?? 'Unknown'),
          ],
          _buildDivider(),
          _buildCompactInfo(Icons.access_time,
              DateFormat('dd/MM/yy').format(widget.ticket.createdAt)),
          _buildDivider(),
          _buildStatusBadge(),
          const SizedBox(width: 6),
          _buildPriorityBadge(),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(IconData icon, String text) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isMobile ? 14 : 12, color: Colors.grey[600]),
        SizedBox(width: isMobile ? 6 : 4),
        Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 12 : 11,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

// 21. NEW: Helper methods to get status and priority text
  String _getStatusText(TicketStatus status, AppLocalizations l10n) {
    switch (status) {
      case TicketStatus.pending:
        return l10n.pending;
      case TicketStatus.inprogress:
        return l10n.inProgress;
      case TicketStatus.prefinished:
        return l10n.prefinished;
      case TicketStatus.closed:
        return l10n.closed;
      case TicketStatus.wrongInfo:
        return l10n.wrongInfo;
      case TicketStatus.deleted:
        return l10n.deleted;
    }
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 1,
      height: 12,
      color: Colors.grey[300],
    );
  }

// 3. UPDATE: _buildStatusBadge - Add localization
  Widget _buildStatusBadge() {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 6, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
      ),
      child: Text(
        _getStatusText(widget.ticket.status, l10n).toUpperCase(),
        style: TextStyle(
          fontSize: isMobile ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

// 4. UPDATE: _buildPriorityBadge - Add localization
  Widget _buildPriorityBadge() {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 6, vertical: isMobile ? 4 : 2),
      decoration: BoxDecoration(
        color: _getPriorityColor(),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
      ),
      child: Text(
        _getPriorityText(widget.ticket.priority, l10n).toUpperCase(),
        style: TextStyle(
          fontSize: isMobile ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  // Small badge shown in the header row
  Widget _buildSubticketsBadge() {
        final l10n = AppLocalizations.safeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree, size: 11, color: Colors.cyan[700]),
          const SizedBox(width: 4),
          Text(
             '${l10n.subtickets} (${_subtickets.length})',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.cyan[700],
            ),
          ),
        ],
      ),
    );
  }

  // Tree view of sub-tickets shown in the collapsed card body
  Widget _buildSubticketsTree() {
    final l10n = AppLocalizations.safeOf(context);

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // Tree items
          ..._subtickets.asMap().entries.map((entry) {
            final index = entry.key;
            final subticket = entry.value;
            final isLast = index == _subtickets.length - 1;
            final statusColor = _getStatusColorForTicket(subticket.status);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tree lines column
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        // Vertical line above branch
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 1.5,
                              color: Colors.cyan.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        // Branch elbow
                        Row(
                          children: [
                            Container(
                              width: 1.5,
                              height: 10,
                              color: Colors.cyan.withValues(alpha: 0.35),
                            ),
                            Container(
                              width: 8,
                              height: 1.5,
                              color: Colors.cyan.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                        // Vertical line below branch (hidden for last)
                        if (!isLast)
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 1.5,
                                color: Colors.cyan.withValues(alpha: 0.35),
                              ),
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Sub-ticket card
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Number + status badge
                          Row(
                            children: [
                              Text(
                                '#${subticket.ticketNumber}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey[600],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getStatusText(subticket.status, l10n)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Title
                          Text(
                            subticket.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Description
                          if (subticket.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subticket.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

// Update the _buildExpandedContent method in EnhancedTicketCard

// 7. UPDATE: _buildExpandedContent - Add localization
  Widget _buildExpandedContent() {
    final l10n = AppLocalizations.safeOf(context);

    if (_loadingExpandedData) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.02),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supervision info banner
          _buildSupervisionInfo(),

          // Basic Information Section
          _buildInfoSection(
            l10n.basicInformation,
            Icons.info_outline,
            Colors.blue,
            [
              if (isMobile)
                _buildMobileBasicInfoGrid()
              else
                _buildDetailGrid(_buildBasicInfoDetails()),
            ],
          ),

          // Technical Details Section
          if (_hasTechnicalDetails()) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.technicalDetails,
              Icons.build_outlined,
              Colors.orange,
              [
                if (isMobile)
                  _buildMobileTechnicalGrid()
                else
                  _buildDetailGrid(_buildTechnicalDetails()),
              ],
            ),
          ],

          // Description Section
          const SizedBox(height: 16),
          _buildInfoSection(
            l10n.description,
            Icons.description_outlined,
            Colors.green,
            [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Text(
                  widget.ticket.description,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),

          // Sub-tickets Section
          if (_subtickets.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
               '${l10n.subtickets} (${_subtickets.length})',
              Icons.account_tree,
              Colors.cyan,
              [_buildSubticketsTree()],
            ),
          ],

          // Tracking Points Section (in-progress + closed tickets)
          if (widget.ticket.status == TicketStatus.inprogress ||
              widget.ticket.status == TicketStatus.closed) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.workTracking,
              Icons.timeline,
              Colors.purple,
              [
                TrackingTimelineWidget(
                  ticketId: widget.ticket.id,
                  currentUser: widget.currentUser,
                ),
              ],
            ),
          ],

          // Work Report Section
          if (_ticketReport != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.workReport,
              Icons.assignment_outlined,
              Colors.green,
              [_buildWorkReportContent()],
            ),
          ],

          // Approval Details Section
          if (_ticketApproval != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.approvalDetails,
              Icons.check_circle_outlined,
              Colors.green,
              [_buildApprovalDetails()],
            ),
          ],

          // Rejection Details Section
          if (_rejectionInfo != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.workRejected,
              Icons.cancel_outlined,
              Colors.red,
              [_buildRejectionDetails()],
            ),
          ],

          // Wrong Info Feedback Section
          if (_wrongInfoFeedback != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.informationIssues,
              Icons.info_outlined,
              Colors.orange,
              [_buildWrongInfoContent()],
            ),
          ],

          // Attachments Section
          if (_ticketAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.attachments,
              Icons.attach_file_outlined,
              Colors.purple,
              [_buildImageGallery(_ticketAttachments)],
            ),
          ],

          // Recent Activity Section
          if (_activityLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              l10n.recentActivity,
              Icons.timeline_outlined,
              Colors.grey,
              [_buildActivityTimeline()],
            ),
          ],
        ],
      ),
    );
  }

// 8. UPDATE: _buildBasicInfoDetails - Add localization
  List<Widget> _buildBasicInfoDetails() {
    final l10n = AppLocalizations.safeOf(context);

    return [
      _buildDetailItem(l10n.title, widget.ticket.title),
      _buildDetailItem(
        l10n.status,
        _getStatusText(widget.ticket.status, l10n).toUpperCase(),
      ),
      _buildDetailItem(
        l10n.priority,
        _getPriorityText(widget.ticket.priority, l10n).toUpperCase(),
      ),
      _buildDetailItem(
        l10n.created,
        DateFormat('dd/MM/yyyy HH:mm').format(widget.ticket.createdAt),
      ),
      _buildDetailItem(
        l10n.updated,
        DateFormat('dd/MM/yyyy HH:mm').format(widget.ticket.updatedAt),
      ),
      _buildDetailItem(l10n.creator, _creatorName ?? l10n.loading),
      if (widget.ticket.creatorPhone != null)
        _buildDetailItem(
          l10n.phone,
          widget.ticket.creatorPhone!,
          isPhone: true,
        ),
      if (widget.ticket.assignedTo != null)
        _buildDetailItem(l10n.assignedTo, _assignedToName ?? l10n.loading),
      _buildDetailItem(l10n.place, _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, l10n.loading)),
      if (widget.ticket.otherPlace != null)
        _buildDetailItem(l10n.otherPlace, widget.ticket.otherPlace!),
      if (widget.ticket.location?.isNotEmpty == true)
        _buildDetailItem(l10n.location, widget.ticket.location!),
      _buildDetailItem(l10n.department, _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, l10n.loading)),
    ];
  }

  Future<void> _launchPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildDetailItem(String label, String value, {bool isPhone = false}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          isPhone
              ? InkWell(
                  onTap: () => _launchPhone(value),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ],
      ),
    );
  }

// 9. UPDATE: _buildMobileBasicInfoGrid - Add localization
  Widget _buildMobileBasicInfoGrid() {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      children: [
        // Row 1
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildLabeledGridItem(l10n.title, widget.ticket.title)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeledGridItem(
                l10n.status,
                _getStatusText(widget.ticket.status, l10n).toUpperCase(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLabeledGridItem(
                l10n.priority,
                _getPriorityText(widget.ticket.priority, l10n).toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeledGridItem(
                l10n.created,
                DateFormat('dd/MM/yyyy HH:mm').format(widget.ticket.createdAt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 3
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLabeledGridItem(
                l10n.updated,
                DateFormat('dd/MM/yyyy HH:mm').format(widget.ticket.updatedAt),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeledGridItem(
                l10n.creator,
                _creatorName ?? l10n.loading,
              ),
            ),
          ],
        ),

        // Phone Number Row
        if (widget.ticket.creatorPhone != null) ...[
          const SizedBox(height: 12),
          _buildLabeledGridItemWithPhone(
            l10n.phone,
            widget.ticket.creatorPhone!,
          ),
        ],

        if (widget.ticket.assignedTo != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledGridItem(
                  l10n.assignedTo,
                  _assignedToName ?? l10n.loading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledGridItem(
                  l10n.place,
                  _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, l10n.loading),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledGridItem(
                  l10n.place,
                  _localizedEntityName(_placeName, _placeNameEn, _placeNameAr, l10n.loading),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],

        if (widget.ticket.location?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledGridItem(
                    l10n.location, widget.ticket.location!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledGridItem(
                    l10n.department, _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, l10n.loading)),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          _buildLabeledGridItem(
              l10n.department, _localizedEntityName(_departmentName, _departmentNameEn, _departmentNameAr, l10n.loading)),
        ],
      ],
    );
  }

// Add phone-specific grid item
  Widget _buildLabeledGridItemWithPhone(String label, String phoneNumber) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _launchPhone(phoneNumber),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  phoneNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// 6. NEW: Labeled grid item for expanded section (with label)
  Widget _buildLabeledGridItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailGrid(List<Widget> details) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: details,
    );
  }

// 10. UPDATE: _buildTechnicalDetails - Add localization
  List<Widget> _buildTechnicalDetails() {
    final l10n = AppLocalizations.safeOf(context);
    final details = <Widget>[];

    if (widget.ticket.natureOfProblem?.isNotEmpty == true) {
      details.add(_buildDetailItem(
          l10n.natureOfProblem, widget.ticket.natureOfProblem!));
    }
    if (_problemTitleName != null) {
      details.add(_buildDetailItem(l10n.problemType, _localizedEntityName(_problemTitleName, _problemTitleNameEn, _problemTitleNameAr, _problemTitleName!)));
    }
    if (widget.ticket.customProblemTitle?.isNotEmpty == true) {
      details.add(_buildDetailItem(
          l10n.customProblem, widget.ticket.customProblemTitle!));
    }
    if (_partModelName != null) {
      details.add(_buildDetailItem(l10n.partDevice, _partModelName!));
    }
    if (widget.ticket.customModelNumber?.isNotEmpty == true) {
      details.add(
          _buildDetailItem(l10n.customModel, widget.ticket.customModelNumber!));
    }
    if (widget.ticket.highPriorityExplain?.isNotEmpty == true) {
      details.add(_buildDetailItem(
          l10n.priorityExplanation, widget.ticket.highPriorityExplain!));
    }

    return details;
  }

// 11. UPDATE: _buildMobileTechnicalGrid - Add localization
  Widget _buildMobileTechnicalGrid() {
    final l10n = AppLocalizations.safeOf(context);
    final details = <Widget>[];

    if (widget.ticket.natureOfProblem?.isNotEmpty == true) {
      details.add(_buildLabeledGridItem(
        l10n.natureOfProblem,
        widget.ticket.natureOfProblem!,
      ));
    }

    if (_problemTitleName != null) {
      details.add(_buildLabeledGridItem(l10n.problemType, _localizedEntityName(_problemTitleName, _problemTitleNameEn, _problemTitleNameAr, _problemTitleName!)));
    }

    if (widget.ticket.customProblemTitle?.isNotEmpty == true) {
      details.add(_buildLabeledGridItem(
        l10n.customProblem,
        widget.ticket.customProblemTitle!,
      ));
    }

    if (_partModelName != null) {
      details.add(_buildLabeledGridItem(l10n.partDevice, _partModelName!));
    }

    if (widget.ticket.customModelNumber?.isNotEmpty == true) {
      details.add(_buildLabeledGridItem(
        l10n.customModel,
        widget.ticket.customModelNumber!,
      ));
    }

    if (widget.ticket.highPriorityExplain?.isNotEmpty == true) {
      details.add(_buildLabeledGridItem(
        l10n.priorityExplanation,
        widget.ticket.highPriorityExplain!,
      ));
    }

    return Column(
      children: List.generate(
        (details.length / 2).ceil(),
        (rowIndex) {
          final startIndex = rowIndex * 2;
          final endIndex = (startIndex + 2).clamp(0, details.length);
          final rowItems = details.sublist(startIndex, endIndex);

          return Padding(
            padding: EdgeInsets.only(
                bottom: rowIndex < (details.length / 2).ceil() - 1 ? 12.0 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: rowItems[0]),
                if (rowItems.length > 1) ...[
                  const SizedBox(width: 12),
                  Expanded(child: rowItems[1]),
                ] else
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
        },
      ),
    );
  }

// 12. UPDATE: _buildImageGallery - Add localization
  Widget _buildImageGallery(List<Map<String, dynamic>> attachments) {
    final l10n = AppLocalizations.safeOf(context);

    final imageAttachments = attachments.where((attachment) {
      final mimeType = attachment['mime_type'] as String?;
      return mimeType?.startsWith('image/') == true;
    }).toList();

    final nonImageAttachments = attachments.where((attachment) {
      final mimeType = attachment['mime_type'] as String?;
      return mimeType?.startsWith('image/') != true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageAttachments.isNotEmpty) ...[
          Text(
            '${l10n.images}:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageAttachments.length,
              itemBuilder: (context, index) {
                final attachment = imageAttachments[index];
                return _buildImageThumbnail(
                    attachment, index, imageAttachments);
              },
            ),
          ),
        ],
        if (nonImageAttachments.isNotEmpty) ...[
          if (imageAttachments.isNotEmpty) const SizedBox(height: 20),
          Text(
            '${l10n.files}:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...nonImageAttachments
              .map((attachment) => _buildFileAttachment(attachment)),
        ],
      ],
    );
  }

// 13. UPDATE: _buildImageThumbnail - Add localization
  Widget _buildImageThumbnail(
    Map<String, dynamic> attachment,
    int index,
    List<Map<String, dynamic>> imageAttachments,
  ) {
    final l10n = AppLocalizations.safeOf(context);
    final imageUrl = supabase.storage
        .from('attachments')
        .getPublicUrl(attachment['file_path']);

    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _showImageGallery(imageAttachments, index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${l10n.loading}...',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 30,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.failedToLoad,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    attachment['file_name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> attachment) {
    final fileName = attachment['file_name'] as String;
    final fileSize = attachment['file_size'] as int?;
    final mimeType = attachment['mime_type'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(mimeType),
              size: 20,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize != null)
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageGallery(List<Map<String, dynamic>> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

// 14. UPDATE: _buildWorkReportContent - Add localization
  Widget _buildWorkReportContent() {
    final l10n = AppLocalizations.safeOf(context);

    if (_ticketReport == null) return const SizedBox.shrink();

    final adminName =
        _ticketReport!['users']?['full_name'] ?? l10n.unknownAdmin;
    final reportTitle = _ticketReport!['title'] as String;
    final reportDescription = _ticketReport!['description'] as String;
    final createdAt = DateTime.parse(_ticketReport!['created_at']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text(
                '${l10n.completedBy}: $adminName',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reportTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reportDescription,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          if (_reportAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '${l10n.reportAttachments}:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildImageGallery(_reportAttachments),
          ],
        ],
      ),
    );
  }

// 15. UPDATE: _buildApprovalDetails - Add localization
  Widget _buildApprovalDetails() {
    final l10n = AppLocalizations.safeOf(context);

    final approverName =
        _ticketApproval!['users']?['full_name'] ?? l10n.unknown;
    final notes = _ticketApproval!['notes'] as String?;
    final approvedAt = DateTime.parse(_ticketApproval!['created_at']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                '${l10n.approvedBy} $approverName',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(approvedAt),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.approvalNotes}:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              notes,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

// 16. UPDATE: _buildRejectionDetails - Add localization
  Widget _buildRejectionDetails() {
    final l10n = AppLocalizations.safeOf(context);

    final rejectorName = _rejectionInfo!['users']?['full_name'] ?? l10n.unknown;
    final rejectionReason = _rejectionInfo!['rejection_reason'] as String?;
    final rejectedAt = DateTime.parse(_rejectionInfo!['created_at']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                '${l10n.workRejectedBy} $rejectorName',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(rejectedAt),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.rejectionReason}:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              rejectionReason.replaceAll('STATUS CHANGE: ', ''),
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

// 17. UPDATE: _buildWrongInfoContent - Add localization
  Widget _buildWrongInfoContent() {
    final l10n = AppLocalizations.safeOf(context);

    final feedbackGiver =
        _wrongInfoFeedback!['users']?['full_name'] ?? l10n.unknown;
    final feedback = _wrongInfoFeedback!['rejection_reason'] as String?;
    final feedbackDate = DateTime.parse(_wrongInfoFeedback!['created_at']);

    String cleanFeedback = feedback?.replaceAll('WRONG INFO: ', '') ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                '${l10n.issuesReportedBy} $feedbackGiver',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(feedbackDate),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (cleanFeedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.issuesToAddress}:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              cleanFeedback,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Column(
      children: _activityLogs.take(5).map((log) {
        final actionType = log['action'] as String;
        final userName = log['users']?['full_name'] ?? 'System';
        final timestamp = DateTime.parse(log['created_at']);
        final newValues = log['new_values'] is Map<String, dynamic>
            ? log['new_values'] as Map<String, dynamic>
            : null;
        final isSubticket = actionType.toLowerCase() == 'subticket_created';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSubticket
                ? Colors.deepPurple.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSubticket
                  ? Colors.deepPurple.withValues(alpha: 0.25)
                  : Colors.grey[200]!,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _getActivityIcon(actionType),
                size: 16,
                color: isSubticket ? Colors.deepPurple : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getActivityDescription(actionType, userName, newValues),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                DateFormat('dd/MM HH:mm').format(timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Helper methods
  bool _hasTechnicalDetails() {
    return widget.ticket.natureOfProblem?.isNotEmpty == true ||
        widget.ticket.problemTitleId != null ||
        widget.ticket.customProblemTitle?.isNotEmpty == true ||
        widget.ticket.modelNumberId != null ||
        widget.ticket.customModelNumber?.isNotEmpty == true ||
        widget.ticket.highPriorityExplain?.isNotEmpty == true;
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;

    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document'))
      return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet'))
      return Icons.table_chart;
    if (mimeType.contains('text')) return Icons.text_snippet;
    if (mimeType.contains('zip') || mimeType.contains('rar'))
      return Icons.archive;

    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _getActivityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'insert':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'subticket_created':
        return Icons.account_tree;
      default:
        return Icons.timeline;
    }
  }

  String _getActivityDescription(String actionType, String userName,
      [Map<String, dynamic>? newValues]) {
    switch (actionType.toLowerCase()) {
      case 'insert':
        return '$userName created this ticket';
      case 'update':
        return '$userName updated the ticket';
      case 'delete':
        return '$userName deleted the ticket';
      case 'subticket_created':
        final num = newValues?['subticket_number'] ?? '';
        final title = newValues?['title'] ?? '';
        final desc = newValues?['description'] ?? '';
        return '$userName created sub-ticket #$num\n$title\n$desc';
      default:
        return '$userName performed $actionType';
    }
  }

// 19. UPDATE: _getAvailableActions - Add localization
  List<Map<String, dynamic>> _getAvailableActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    // Add tracking actions for assigned admin in-progress tickets
    if (widget.ticket.assignedTo == widget.currentUser.id &&
        widget.ticket.status == TicketStatus.inprogress) {
      // Check-in button
      if (_checkInStatus == null && !_loadingCheckInStatus) {
        actions.add({
          'label': l10n.checkIn,
          'icon': Icons.login,
          'color': Colors.green,
          'onPressed': _handleCheckIn,
        });
      }

      // Check-out button
      if (_checkInStatus != null && !_loadingCheckInStatus) {
        actions.add({
          'label': l10n.checkOut,
          'icon': Icons.logout,
          'color': Colors.orange,
          'onPressed': _handleCheckOut,
        });
      }

      // Add Note button
      actions.add({
        'label': l10n.addNote,
        'icon': Icons.note_add,
        'color': Colors.blue,
        'onPressed': _showAddNoteDialog,
      });

      // Mark Under Supervision action
      actions.add({
        'label': l10n.markUnderSupervision,
        'icon': Icons.visibility,
        'color': Colors.deepPurple,
        'onPressed': _showMarkUnderSupervisionDialog,
      });
    }

    // Allow admin to reject ticket from supervision
    if (widget.ticket.assignedTo == widget.currentUser.id &&
        widget.ticket.status == TicketStatus.prefinished &&
        widget.ticket.underSupervision) {
      actions.add({
        'label': l10n.rejectFromSupervision,
        'icon': Icons.cancel,
        'color': Colors.red,
        'onPressed': _showRejectSupervisionDialog,
      });
    }

    // Rest of existing actions based on user type...
    switch (widget.currentUser.userType) {
      case UserType.systemAdmin:
        actions.addAll(_getSystemAdminActions());
        break;
      case UserType.superAdmin:
        actions.addAll(_getSuperAdminActions());
        break;
      case UserType.admin:
        actions.addAll(_getAdminActions());
        break;
      case UserType.superUser:
        actions.addAll(_getSuperUserActions());
        break;
      case UserType.user:
        actions.addAll(_getUserActions());

      case UserType.branchAdmin:
        actions.addAll(_getSuperUserActions());
        break;
    }

    return actions;
  }

// 20. UPDATE: Helper action methods - Add localization
  List<Map<String, dynamic>> _getSystemAdminActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    if (widget.ticket.status == TicketStatus.prefinished) {
      actions.add({
        'label': l10n.reviewAndApprove,
        'icon': Icons.verified,
        'color': Colors.green,
        'onPressed': () => _showApprovalDialog()
      });
    }

    if (_canGoBack()) {
      actions.add({
        'label': l10n.goBack,
        'icon': Icons.arrow_back,
        'color': Colors.orange,
        'onPressed': () => _showGoBackConfirmation()
      });
    }

    if (widget.ticket.status == TicketStatus.pending &&
        widget.ticket.assignedTo == null) {
      actions.add({
        'label': l10n.assign,
        'icon': Icons.assignment_ind,
        'color': Colors.blue,
        'onPressed': () => _showAssignDialog()
      });
    }

    // Reassign in-progress tickets
    if (widget.ticket.status == TicketStatus.inprogress &&
        widget.ticket.assignedTo != null) {
      actions.add({
        'label': l10n.assign,
        'icon': Icons.assignment_ind,
        'color': Colors.blue,
        'onPressed': () => _showAssignDialog()
      });
    }

    return actions;
  }

// UPDATE: Enhanced _getSuperAdminActions method in EnhancedTicketCard class
  List<Map<String, dynamic>> _getSuperAdminActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    // Check if super admin is from the target department
    if (widget.currentUser.departmentId == widget.ticket.targetDepartmentId) {
      // NEW: Super Admin can start working on ticket themselves (for pending tickets)
      if (widget.ticket.status == TicketStatus.pending &&
          widget.ticket.assignedTo == null) {
        actions.add({
          'label': l10n.startWork,
          'icon': Icons.play_arrow,
          'color': Colors.green,
          'onPressed': () => _superAdminStartWork()
        });

        actions.add({
          'label': l10n.assign,
          'icon': Icons.assignment_ind,
          'color': Colors.blue,
          'onPressed': () => _showAssignDialog()
        });
      }

      // Super Admin can go back status
      if (_canGoBack()) {
        actions.add({
          'label': l10n.goBack,
          'icon': Icons.arrow_back,
          'color': Colors.orange,
          'onPressed': () => _showGoBackConfirmation()
        });
      }

      // Review & Approve prefinished tickets in their department
      if (widget.ticket.status == TicketStatus.prefinished) {
        actions.add({
          'label': l10n.reviewAndApprove,
          'icon': Icons.verified,
          'color': Colors.green,
          'onPressed': () => _showApprovalDialog()
        });
      }

      // Reassign in-progress tickets in their department
      if (widget.ticket.status == TicketStatus.inprogress &&
          widget.ticket.assignedTo != null) {
        actions.add({
          'label': l10n.assign,
          'icon': Icons.assignment_ind,
          'color': Colors.blue,
          'onPressed': () => _showAssignDialog()
        });
      }

      if (widget.ticket.status == TicketStatus.inprogress &&
          widget.ticket.assignedTo == widget.currentUser.id) {
        actions.add({
          'label': l10n.markFinished,
          'icon': Icons.check_circle,
          'color': Colors.purple,
          'onPressed': () => _showFinishDialog()
        });
        actions.add({
          'label': l10n.createSubticket,
          'icon': Icons.account_tree,
          'color': Colors.deepPurple,
          'onPressed': () => _showCreateSubticketDialog()
        });
      }
    }

    // Super Admin can delete their own tickets
    if (widget.ticket.createdBy == widget.currentUser.id) {
      if (widget.ticket.status == TicketStatus.pending) {
        actions.add({
          'label': l10n.delete,
          'icon': Icons.delete,
          'color': Colors.red,
          'onPressed': () => _deleteTicket()
        });
      }
    }

    if ([TicketStatus.pending, TicketStatus.inprogress]
            .contains(widget.ticket.status) &&
        widget.ticket.createdBy != widget.currentUser.id &&
        widget.currentUser.departmentId == widget.ticket.targetDepartmentId) {
      actions.add({
        'label': l10n.wrongInfo,
        'icon': Icons.error_outline,
        'color': Colors.orange,
        'onPressed': () => _showWrongInfoDialog()
      });
    }

    return actions;
  }

// NEW: Super Admin starts working on the ticket themselves
  Future<void> _superAdminStartWork() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      debugPrint(
          '🛠️ Super Admin starting work on ticket ${widget.ticket.ticketNumber}');

      // Update ticket: assign to super admin and change status to inprogress
      await supabase.from('tickets').update({
        'assigned_to': widget.currentUser.id,
        'status': TicketStatus.inprogress.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.ticket.id);

      // Create activity log
      await supabase.from('activity_logs').insert({
        'table_name': 'tickets',
        'record_id': widget.ticket.id,
        'action': 'update',
        'old_values': {
          'assigned_to': null,
          'status': TicketStatus.pending.value,
        },
        'new_values': {
          'assigned_to': widget.currentUser.id,
          'status': TicketStatus.inprogress.value,
        },
        'user_id': widget.currentUser.id,
      });

      // Notify ticket creator
      await NotificationService.notifyTicketStatusChanged(
        ticketId: widget.ticket.id,
        ticketCreatorId: widget.ticket.createdBy,
        changedByUserId: widget.currentUser.id,
        ticketNumber: widget.ticket.ticketNumber,
        oldStatus: TicketStatus.pending.value,
        newStatus: TicketStatus.inprogress.value,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.youStartedWorkingOnTicket),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      debugPrint('❌ Error starting work as super admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorStartingWork}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getAdminActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    if (widget.ticket.assignedTo == widget.currentUser.id) {
      if (widget.ticket.status == TicketStatus.pending) {
        actions.add({
          'label': l10n.startWork,
          'icon': Icons.play_arrow,
          'color': Colors.green,
          'onPressed': () => _startWorking()
        });
      }

      if (widget.ticket.status == TicketStatus.inprogress) {
        actions.add({
          'label': l10n.markFinished,
          'icon': Icons.check_circle,
          'color': Colors.purple,
          'onPressed': () => _showFinishDialog()
        });
        actions.add({
          'label': l10n.createSubticket,
          'icon': Icons.account_tree,
          'color': Colors.deepPurple,
          'onPressed': () => _showCreateSubticketDialog()
        });
      }

      if ([TicketStatus.pending, TicketStatus.inprogress]
              .contains(widget.ticket.status) &&
          widget.ticket.createdBy != widget.currentUser.id) {
        actions.add({
          'label': l10n.wrongInfo,
          'icon': Icons.error_outline,
          'color': Colors.orange,
          'onPressed': () => _showWrongInfoDialog()
        });
      }
    }

    return actions;
  }

  List<Map<String, dynamic>> _getSuperUserActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    if (widget.ticket.createdBy == widget.currentUser.id ||
        (widget.currentUser.placeId != null &&
            widget.ticket.placeId == widget.currentUser.placeId)) {
      if (widget.ticket.status == TicketStatus.wrongInfo) {
        actions.add({
          'label': l10n.createCorrectedTicket,
          'icon': Icons.edit,
          'color': Colors.indigo,
          'onPressed': () => _showCreateCorrectedTicketDialog()
        });
      }

      if (widget.ticket.status == TicketStatus.pending &&
          widget.ticket.createdBy == widget.currentUser.id) {
        actions.add({
          'label': l10n.delete,
          'icon': Icons.delete,
          'color': Colors.red,
          'onPressed': () => _deleteTicket()
        });
      }
    }

    return actions;
  }

  List<Map<String, dynamic>> _getUserActions() {
    final l10n = AppLocalizations.safeOf(context);
    final actions = <Map<String, dynamic>>[];

    if (widget.ticket.createdBy == widget.currentUser.id) {
      if (widget.ticket.status == TicketStatus.wrongInfo) {
        actions.add({
          'label': l10n.createCorrectedTicket,
          'icon': Icons.edit,
          'color': Colors.indigo,
          'onPressed': () => _showCreateCorrectedTicketDialog()
        });
      }

      if (widget.ticket.status == TicketStatus.pending) {
        actions.add({
          'label': l10n.delete,
          'icon': Icons.delete,
          'color': Colors.red,
          'onPressed': () => _deleteTicket()
        });
      }
    }

    return actions;
  }

// 6. UPDATE: Enhanced can go back check with more conditions
  bool _canGoBack() {
    // System admin can revert closed tickets to in-progress
    if (widget.ticket.status == TicketStatus.closed &&
        widget.currentUser.userType == UserType.systemAdmin) {
      return true;
    }

    // Super admin of target department can go back from closed
    if (widget.ticket.status == TicketStatus.closed &&
        widget.currentUser.userType == UserType.superAdmin &&
        widget.currentUser.departmentId == widget.ticket.targetDepartmentId) {
      return true;
    }

    // Super admin or system admin can go back from pre-finished
    if (widget.ticket.status == TicketStatus.prefinished &&
        (widget.currentUser.userType == UserType.superAdmin ||
            widget.currentUser.userType == UserType.systemAdmin)) {
      // Only if they're from the target department or system admin
      if (widget.currentUser.userType == UserType.systemAdmin ||
          widget.currentUser.departmentId == widget.ticket.targetDepartmentId) {
        return true;
      }
    }

    // Super admin can revert in-progress back to pending if they assigned it
    if (widget.ticket.status == TicketStatus.inprogress &&
        widget.ticket.assignedTo != null &&
        widget.currentUser.userType == UserType.superAdmin &&
        widget.currentUser.departmentId == widget.ticket.targetDepartmentId) {
      return true;
    }

    return false;
  }

  TicketStatus _getPreviousStatus() {
    switch (widget.ticket.status) {
      case TicketStatus.closed:
        // Check if there's a work report - if yes, go to prefinished; if no, go to inprogress
        // For simplicity, we'll go to inprogress by default
        // You can enhance this to check if report exists
        return TicketStatus.inprogress;
      case TicketStatus.prefinished:
        return TicketStatus.inprogress;
      case TicketStatus.inprogress:
        return TicketStatus.pending;
      default:
        return widget.ticket.status;
    }
  }

  void _showGoBackConfirmation() {
    final l10n = AppLocalizations.safeOf(context);
    final previousStatus = _getPreviousStatus();
    final changesText = _getReversalChangesText();

    showDialog(
      context: context,
      builder: (context) => OptimizedDialog(
        title: l10n.revertTicketStatus,
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${l10n.thisWillRevertTicket} ${widget.ticket.ticketNumber} ${l10n.from} '
                    '${_getStatusText(widget.ticket.status, l10n)} ${l10n.backTo} '
                    '${_getStatusText(previousStatus, l10n)}.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.changesThatWillBeReverted,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    changesText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.thisActionCannotBeUndone,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goBackStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.revertStatus,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goBackStatus() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      final previousStatus = _getPreviousStatus();
      final updateData = <String, dynamic>{
        'status': previousStatus.value,
      };

      // Reverse state changes based on current status
      if (widget.ticket.status == TicketStatus.inprogress &&
          previousStatus == TicketStatus.pending) {
        updateData['assigned_to'] = null;
        print('Reverting: Removing admin assignment');
      } else if (widget.ticket.status == TicketStatus.prefinished &&
          previousStatus == TicketStatus.inprogress) {
        print('Attempting to delete work report...');
        final reportDeleted = await _deleteTicketReport(widget.ticket.id);
        if (reportDeleted) {
          print('Work report deleted successfully');
        } else {
          print('No work report found or already deleted');
        }
      } else if (widget.ticket.status == TicketStatus.closed &&
          previousStatus == TicketStatus.inprogress) {
        print('Attempting to delete approval and work report...');
        await _deleteTicketApproval(widget.ticket.id);
        await _deleteTicketReport(widget.ticket.id);
        print('Approval and work report deleted');
      }

      await supabase
          .from('tickets')
          .update(updateData)
          .eq('id', widget.ticket.id);

      print('Ticket status updated to: ${previousStatus.value}');

      await supabase.from('ticket_approvals').insert({
        'ticket_id': widget.ticket.id,
        'approved_by': widget.currentUser.id,
        'is_approved': null,
        'notes':
            'Status reverted from ${widget.ticket.status.value} to ${previousStatus.value}',
        'rejection_reason':
            'REGRESSION: Reverted by ${widget.currentUser.fullName}. '
                'Previous state restored.',
      });

      await NotificationService.notifyTicketStatusChanged(
        ticketId: widget.ticket.id,
        ticketCreatorId: widget.ticket.createdBy,
        changedByUserId: widget.currentUser.id,
        ticketNumber: widget.ticket.ticketNumber,
        oldStatus: widget.ticket.status.value,
        newStatus: previousStatus.value,
      );

      if (mounted) {
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.ticketRevertedTo} ${_getStatusText(previousStatus, l10n)}. '
              '${l10n.previousStateRestored}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error reverting status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorReverting}: $e')),
        );
      }
    }
  }

// 2. FIX: Properly delete ticket report and return success status
  Future<bool> _deleteTicketReport(String ticketId) async {
    try {
      print('Fetching reports for ticket: $ticketId');

      // Get report ID and attachments
      final reports = await supabase
          .from('ticket_reports')
          .select('id, ticket_report_attachments(id, file_path)')
          .eq('ticket_id', ticketId);

      if (reports.isEmpty) {
        print('No report found to delete');
        return false;
      }

      print('Found ${reports.length} report(s) to delete');

      for (final report in reports) {
        final reportId = report['id'];
        print('Processing report: $reportId');

        // Delete file attachments from storage first
        final attachments = report['ticket_report_attachments'] as List?;
        if (attachments != null && attachments.isNotEmpty) {
          print('Deleting ${attachments.length} attachment(s)');

          for (final attachment in attachments) {
            try {
              final filePath = attachment['file_path'] as String?;
              if (filePath != null) {
                await supabase.storage.from('attachments').remove([filePath]);
                print('Deleted file: $filePath');
              }
            } catch (e) {
              print('Warning: Failed to delete attachment file: $e');
              // Continue even if file deletion fails
            }
          }

          // Delete attachment records from database
          await supabase
              .from('ticket_report_attachments')
              .delete()
              .eq('report_id', reportId);

          print('Deleted attachment records for report: $reportId');
        }

        // Delete the report itself
        await supabase.from('ticket_reports').delete().eq('id', reportId);

        print('Deleted report: $reportId');
      }

      return true;
    } catch (e) {
      print('Error deleting ticket report: $e');
      // Throw the error so the caller knows something went wrong
      rethrow;
    }
  }

// 3. FIX: Properly delete ticket approval
  Future<void> _deleteTicketApproval(String ticketId) async {
    try {
      print('Deleting approvals for ticket: $ticketId');

      // Delete approval records where is_approved is true (actual approvals)
      await supabase
          .from('ticket_approvals')
          .delete()
          .eq('ticket_id', ticketId)
          .eq('is_approved', true);

      print('Deleted approval records');
    } catch (e) {
      print('Error deleting ticket approval: $e');
      // Don't throw - allow status change to proceed
    }
  }

  String _getReversalChangesText() {
    final l10n = AppLocalizations.safeOf(context);
    final previousStatus = _getPreviousStatus();

    if (widget.ticket.status == TicketStatus.inprogress &&
        previousStatus == TicketStatus.pending) {
      return '• ${l10n.adminAssignmentWillBeRemoved}\n'
          '• ${l10n.ticketWillReturnUnassigned}';
    } else if (widget.ticket.status == TicketStatus.prefinished &&
        previousStatus == TicketStatus.inprogress) {
      return '• ${l10n.workReportWillBeDeleted}\n'
          '• ${l10n.allReportAttachmentsRemoved}\n'
          '• ${l10n.ticketWillReturnActiveWork}';
    } else if (widget.ticket.status == TicketStatus.closed &&
        previousStatus == TicketStatus.inprogress) {
      return '• ${l10n.approvalRecordDeleted}\n'
          '• ${l10n.workReportWillBeDeleted}\n'
          '• ${l10n.allAttachmentsRemoved}\n'
          '• ${l10n.ticketWillReturnActiveWork}';
    } else if (widget.ticket.status == TicketStatus.closed &&
        previousStatus == TicketStatus.prefinished) {
      return '• ${l10n.approvalRecordDeleted}\n'
          '• ${l10n.ticketWillReturnAwaitingApproval}\n'
          '• ${l10n.workReportWillRemain}';
    }

    return '• ${l10n.ticketWillBeRevertedPrevious}';
  }

  // Dialog method implementations
  void _showApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => TicketApprovalDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onApprovalSubmitted: widget.onRefresh,
      ),
    );
  }

  void _showAssignDialog() {
    showDialog(
      context: context,
      builder: (context) => AssignTicketDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onTicketAssigned: widget.onRefresh,
      ),
    );
  }

  void _startWorking() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      await TicketService.updateTicket(widget.ticket.id, {
        'status': TicketStatus.inprogress.value,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ticketStatusChangedToInProgress)),
      );
      widget.onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
    }
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      builder: (context) => FinishTicketDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onTicketFinished: widget.onRefresh,
      ),
    );
  }

  // Add this at the top of your tickets.dart file or in a utils file
  bool _shouldUseFullScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  void _showCreateSubticketDialog() {
    void onCreated() {
      _loadSubtickets();
      widget.onRefresh();
    }

    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateSubticketScreen(
            parentTicket: widget.ticket,
            currentUser: widget.currentUser,
            onSubticketCreated: onCreated,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => CreateSubticketDialog(
          parentTicket: widget.ticket,
          currentUser: widget.currentUser,
          onSubticketCreated: onCreated,
        ),
      );
    }
  }

  void _showWrongInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => WrongInfoDialog(
        ticket: widget.ticket,
        currentUser: widget.currentUser,
        onWrongInfoSubmitted: widget.onRefresh,
      ),
    );
  }

  // NEW: Enhanced creator approval dialog with auto-close functionality
  void _showCreatorApprovalDialog(bool isApproval) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => CreatorApprovalDialog(
            ticket: widget.ticket,
            currentUser: widget.currentUser,
            onApprovalSubmitted: widget.onRefresh,
            initialApproval: isApproval,
            fullScreen: true,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => CreatorApprovalDialog(
          ticket: widget.ticket,
          currentUser: widget.currentUser,
          onApprovalSubmitted: widget.onRefresh,
          initialApproval: isApproval,
        ),
      );
    }
  }

  void _showCreateCorrectedTicketDialog() {
    if (_shouldUseFullScreen(context)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateTicketScreen(
            currentUser: widget.currentUser,
            onTicketCreated: widget.onRefresh,
            prefillFromTicket: widget.ticket,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => CreateTicketDialog(
          currentUser: widget.currentUser,
          onTicketCreated: widget.onRefresh,
          prefillFromTicket: widget.ticket,
        ),
      );
    }
  }

  Future<void> _deleteTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => OptimizedDialog(
        title: l10n.deleteTicket,
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${l10n.areYouSureDeleteTicket} ${widget.ticket.ticketNumber}?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.ticketWillBeMarkedDeleted,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.delete,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.from('tickets').update({
          'status': TicketStatus.deleted.value,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.ticket.id);

        await supabase.from('ticket_approvals').insert({
          'ticket_id': widget.ticket.id,
          'approved_by': widget.currentUser.id,
          'is_approved': null,
          'notes': 'Ticket soft-deleted by ${widget.currentUser.fullName}',
          'rejection_reason': 'DELETED: Ticket marked as deleted',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.ticketDeletedSuccessfully),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${l10n.errorDeletingTicket}: $e')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

// 18. UPDATE: _buildSupervisionInfo - Add localization
  Widget _buildSupervisionInfo() {
    final l10n = AppLocalizations.safeOf(context);

    if (!widget.ticket.underSupervision ||
        widget.ticket.status != TicketStatus.prefinished) {
      return SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.1),
            Colors.deepPurple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.underSupervision,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      l10n.ticketUnderSupervisionDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(color: Colors.deepPurple.withOpacity(0.2)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.ticket.createdBy == widget.currentUser.id
                      ? l10n.supervisionInfoCreator
                      : l10n.supervisionInfoAdmin,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsScreenState =
        context.findAncestorStateOfType<_TicketsScreenState>();
    final isHighlighted =
        ticketsScreenState?._isTicketHighlighted(widget.ticket.id) ?? false;
    final highlightColor =
        ticketsScreenState?._getTicketHighlightColor(widget.ticket.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.orange : Colors.grey.withOpacity(0.2),
          width: isHighlighted ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? Colors.orange.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: isHighlighted ? 12 : 4,
            spreadRadius: isHighlighted ? 2 : 0.1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        decoration: isHighlighted && highlightColor != null
            ? BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          children: [
            _buildCompactHeader(),
            if (_isExpanded) _buildExpandedContent(),
          ],
        ),
      ),
    );
  }
}

// UPDATED: Enhanced Creator Approval Dialog with configurable auto-close functionality
class CreatorApprovalDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onApprovalSubmitted;
  final bool initialApproval;
  final bool fullScreen;

  const CreatorApprovalDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onApprovalSubmitted,
    this.initialApproval = true,
    this.fullScreen = false,
  });

  @override
  State<CreatorApprovalDialog> createState() => _CreatorApprovalDialogState();
}

// REPLACE the entire _CreatorApprovalDialogState class in tickets_screen.dart

class _CreatorApprovalDialogState extends State<CreatorApprovalDialog> {
  late bool _isApproved;
  final _notesController = TextEditingController();
  final _rejectionReasonController = TextEditingController();
  bool _isLoading = false;
  DateTime? _ticketFinishedAt;
  Duration? _remainingTime;
  Timer? _countdownTimer;
  int _autoApprovalMinutes = 1440; // Will be loaded from settings
  bool _isLoadingTime = true;

  @override
  void initState() {
    super.initState();
    _isApproved = widget.initialApproval;
    _loadAutoApprovalSettings();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _notesController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  /// Load the auto-approval time from system settings
  Future<void> _loadAutoApprovalSettings() async {
    try {
      print('🔍 Loading auto-approval settings...');

      // Get configured auto-approval time from system settings
      _autoApprovalMinutes = await NotificationService.getAutoApprovalMinutes();
      print('✅ Loaded auto-approval time: $_autoApprovalMinutes minutes');

      // Now load the ticket finish time
      await _loadTicketFinishTime();

      if (mounted) {
        setState(() {
          _isLoadingTime = false;
        });
        _startCountdownTimer();
      }
    } catch (e) {
      print('❌ Error loading auto-approval settings: $e');
      _autoApprovalMinutes = 1440; // Default to 24 hours on error
      await _loadTicketFinishTime();

      if (mounted) {
        setState(() {
          _isLoadingTime = false;
        });
        _startCountdownTimer();
      }
    }
  }

  /// Load the exact time when ticket was changed to prefinished
  Future<void> _loadTicketFinishTime() async {
    try {
      print(
          '🔍 Loading ticket finish time for ticket: ${widget.ticket.ticketNumber}');

      // Get the time when ticket status was changed to prefinished
      final activityLog = await supabase
          .from('activity_logs')
          .select('created_at, new_values, old_values')
          .eq('record_id', widget.ticket.id)
          .eq('table_name', 'tickets')
          .eq('action', 'UPDATE')
          .order('created_at', ascending: false)
          .limit(20);

      print('📋 Found ${activityLog.length} activity logs');

      // Find the most recent status change from inprogress to prefinished
      for (final log in activityLog) {
        try {
          final newValues = log['new_values'] as Map<String, dynamic>?;
          final oldValues = log['old_values'] as Map<String, dynamic>?;

          if (newValues != null &&
              oldValues != null &&
              newValues['status'] == 'prefinished' &&
              oldValues['status'] == 'inprogress') {
            _ticketFinishedAt = DateTime.parse(log['created_at']);
            print('✅ Found prefinished time: $_ticketFinishedAt');
            print(
                '⏰ Auto-close time: ${_ticketFinishedAt!.add(Duration(minutes: _autoApprovalMinutes))}');
            break;
          }
        } catch (e) {
          print('⚠️ Error parsing activity log entry: $e');
          continue;
        }
      }

      // Fallback to ticket updated_at if no activity log found
      if (_ticketFinishedAt == null) {
        print(
            '⚠️ No activity log found, using ticket updated_at: ${widget.ticket.updatedAt}');
        _ticketFinishedAt = widget.ticket.updatedAt;
      }

      if (mounted) {
        _calculateRemainingTime();
      }
    } catch (e) {
      print('❌ Error loading ticket finish time: $e');
      _ticketFinishedAt = widget.ticket.updatedAt;
      if (mounted) {
        _calculateRemainingTime();
      }
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateRemainingTime();
        setState(() {});
      }
    });
  }

  void _calculateRemainingTime() {
    if (_ticketFinishedAt == null) {
      _remainingTime = null;
      return;
    }

    // Calculate auto-close time based on CONFIGURED minutes
    final autoCloseTime =
        _ticketFinishedAt!.add(Duration(minutes: _autoApprovalMinutes));
    final now = DateTime.now();

    if (now.isBefore(autoCloseTime)) {
      _remainingTime = autoCloseTime.difference(now);

      // Show warning when 20% of time remains or less than 2 minutes
      final twentyPercent =
          Duration(minutes: (_autoApprovalMinutes * 0.2).ceil());
      final warningThreshold = twentyPercent.inMinutes < 2
          ? const Duration(minutes: 2)
          : twentyPercent;

      if (_remainingTime! <= warningThreshold &&
          _remainingTime!.inSeconds % 30 == 0) {
        _showAutoCloseWarning();
      }
    } else {
      _remainingTime = Duration.zero;
      if (_remainingTime!.inSeconds % 5 == 0) {
        _showAutoCloseWarning();
      }
    }
  }

  void _showAutoCloseWarning() {
    if (!mounted) return;

    final l10n = AppLocalizations.safeOf(context);
    final isExpired =
        _remainingTime != null && _remainingTime! == Duration.zero;
    final isUrgent = _remainingTime != null && _remainingTime!.inMinutes < 2;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isExpired
              ? l10n.timeExpiredAutoApprovalNow
              : isUrgent
                  ? '${l10n.urgentAutoApprovalIn} ${_formatRemainingTime()}!'
                  : '${l10n.warningAutoApprovalIn} ${_formatRemainingTime()}',
        ),
        backgroundColor: isExpired || isUrgent ? Colors.red : Colors.orange,
        duration: Duration(
          seconds: isExpired
              ? 15
              : isUrgent
                  ? 10
                  : 5,
        ),
      ),
    );
  }

  String _formatRemainingTime() {
    final l10n = AppLocalizations.safeOf(context);

    if (_remainingTime == null) return l10n.calculating;
    if (_remainingTime!.isNegative || _remainingTime! == Duration.zero) {
      return l10n.expiredAutoClosingNow;
    }

    final days = _remainingTime!.inDays;
    final hours = _remainingTime!.inHours % 24;
    final minutes = _remainingTime!.inMinutes % 60;
    final seconds = _remainingTime!.inSeconds % 60;

    if (days > 0) {
      return '${days}${l10n.day}${days > 1 ? l10n.days : ''} ${hours}${l10n.hour} ${minutes}${l10n.minute}';
    } else if (hours > 0) {
      return '${hours}${l10n.hour} ${minutes}${l10n.minute} ${seconds}${l10n.seconds}';
    } else if (minutes > 0) {
      return '${minutes}${l10n.minute} ${seconds}${l10n.seconds}';
    } else {
      return '${seconds}${l10n.seconds}';
    }
  }

  String _formatTotalAutoApprovalTime() {
    final l10n = AppLocalizations.safeOf(context);

    if (_autoApprovalMinutes >= 1440) {
      final days = _autoApprovalMinutes ~/ 1440;
      final hours = (_autoApprovalMinutes % 1440) ~/ 60;
      final minutes = _autoApprovalMinutes % 60;

      String result = '$days ${days > 1 ? l10n.days : l10n.day}';
      if (hours > 0) result += ' $hours ${hours > 1 ? l10n.hours : l10n.hour}';
      if (minutes > 0)
        result += ' $minutes ${minutes > 1 ? l10n.minutes : l10n.minute}';
      return result;
    } else if (_autoApprovalMinutes >= 60) {
      final hours = _autoApprovalMinutes ~/ 60;
      final minutes = _autoApprovalMinutes % 60;

      String result = '$hours ${hours > 1 ? l10n.hours : l10n.hour}';
      if (minutes > 0)
        result += ' $minutes ${minutes > 1 ? l10n.minutes : l10n.minute}';
      return result;
    } else {
      return '$_autoApprovalMinutes ${_autoApprovalMinutes > 1 ? l10n.minutes : l10n.minute}';
    }
  }

  Color _getTimerColor() {
    if (_remainingTime == null || _isLoadingTime) return Colors.blue;

    if (_remainingTime! == Duration.zero) {
      return Colors.red; // Expired
    }

    final percentageRemaining =
        _remainingTime!.inMinutes / _autoApprovalMinutes;

    if (percentageRemaining <= 0.1 || _remainingTime!.inMinutes < 2) {
      return Colors.red; // Critical
    } else if (percentageRemaining <= 0.25 || _remainingTime!.inMinutes < 5) {
      return Colors.orange; // Warning
    } else {
      return Colors.blue; // Normal
    }
  }

  Future<void> _submitApproval() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_isApproved && _notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseAddApprovalNotes)),
      );
      return;
    }

    if (!_isApproved && _rejectionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseProvideRejectionReason)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.from('ticket_approvals').insert({
        'ticket_id': widget.ticket.id,
        'approved_by': widget.currentUser.id,
        'is_approved': _isApproved,
        'notes': _isApproved ? _notesController.text.trim() : null,
        'rejection_reason':
            !_isApproved ? _rejectionReasonController.text.trim() : null,
      });

      final newStatus = _isApproved
          ? TicketStatus.closed.value
          : TicketStatus.inprogress.value;

      await supabase.from('tickets').update({
        'status': newStatus,
      }).eq('id', widget.ticket.id);

      await NotificationService.notifyTicketApproved(
        ticketId: widget.ticket.id,
        ticketCreatorId: widget.ticket.createdBy,
        approvedByUserId: widget.currentUser.id,
        ticketNumber: widget.ticket.ticketNumber,
        isApproved: _isApproved,
        rejectionReason:
            !_isApproved ? _rejectionReasonController.text.trim() : null,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onApprovalSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isApproved
                  ? l10n.ticketApprovedAndClosed
                  : l10n.ticketReturnedForMoreWork,
            ),
            backgroundColor: _isApproved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorSubmittingApproval}: $e')),
        );
      }
    }
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, Color timerColor) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ticket info
        Text(
          '${l10n.ticket}: ${widget.ticket.ticketNumber}',
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),

        // Auto-close timer warning
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                timerColor.withOpacity(0.15),
                timerColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: timerColor.withOpacity(0.4), width: 2),
          ),
          child: _isLoadingTime
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _remainingTime != null &&
                                  _remainingTime! == Duration.zero
                              ? Icons.warning
                              : Icons.schedule,
                          color: timerColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _remainingTime != null &&
                                    _remainingTime! == Duration.zero
                                ? l10n.timeExpired
                                : l10n.autoApprovalCountdown,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: timerColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.timeRemaining,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatRemainingTime(),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: timerColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l10n.totalTime,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTotalAutoApprovalTime(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_remainingTime != null &&
                        _ticketFinishedAt != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _remainingTime! == Duration.zero
                              ? 0.0
                              : (_remainingTime!.inSeconds /
                                      (_autoApprovalMinutes * 60))
                                  .clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(timerColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // Approval/Rejection Toggle
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.yourDecision}:',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(l10n.approve,
                          style: const TextStyle(fontSize: 13)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      groupValue: _isApproved,
                      onChanged: (value) =>
                          setState(() => _isApproved = value!),
                      activeColor: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(l10n.requestChanges,
                          style: const TextStyle(fontSize: 13)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      groupValue: _isApproved,
                      onChanged: (value) =>
                          setState(() => _isApproved = value!),
                      activeColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Input fields
        if (_isApproved) ...[
          Text(
            '${l10n.approvalNotes}:',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: l10n.approvalNotesLabel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.workMeetsExpectations,
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
            maxLines: 4,
          ),
        ] else ...[
          Text(
            '${l10n.changesNeeded}:',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rejectionReasonController,
            decoration: InputDecoration(
              labelText: l10n.explainChanges,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.whatNeedsImprovement,
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
            maxLines: 4,
          ),
        ],
        const SizedBox(height: 12),

        // Information box
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isApproved
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isApproved
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isApproved ? Icons.check_circle : Icons.edit,
                    color:
                        _isApproved ? Colors.green[700] : Colors.orange[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isApproved ? l10n.approval : l10n.requestChanges,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isApproved
                          ? Colors.green[700]
                          : Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isApproved
                    ? '• ${l10n.ticketWillBeClosed}\n• ${l10n.noFurtherWork}'
                    : '• ${l10n.returnsToInProgress}\n• ${l10n.adminSeesFeedback}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, AppLocalizations l10n) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: _isLoading ? null : _submitApproval,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isApproved ? Colors.green : Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isApproved ? l10n.approve : l10n.requestChanges,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final timerColor = _getTimerColor();

    if (widget.fullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.reviewCompletedWork),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildContent(context, l10n, timerColor),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActions(context, l10n),
            ),
          ),
        ),
      );
    }

    return OptimizedDialog(
      title: l10n.reviewCompletedWork,
      width: isMobile ? null : MediaQuery.of(context).size.width * 0.6,
      height: isMobile
          ? MediaQuery.of(context).size.height * 0.85
          : MediaQuery.of(context).size.height * 0.7,
      contentPadding: const EdgeInsets.all(12),
      isScrollable: true,
      child: _buildContent(context, l10n, timerColor),
      actions: _buildActions(context, l10n),
    );
  }
}

class ImageGalleryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const ImageGalleryViewer({
    Key? key,
    required this.images,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  // PhotoView controllers per page so we can programmatically zoom
  late final List<PhotoViewController> _photoControllers;
  late final List<PhotoViewScaleStateController> _scaleStateControllers;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _photoControllers = List.generate(
      widget.images.length,
      (_) => PhotoViewController(),
    );

    _scaleStateControllers = List.generate(
      widget.images.length,
      (_) => PhotoViewScaleStateController(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _photoControllers) {
      c.dispose();
    }
    for (final s in _scaleStateControllers) {
      s.dispose();
    }
    super.dispose();
  }

  void _toggleUI() => setState(() => _showUI = !_showUI);

  void _next() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _zoomIn() {
    final controller = _photoControllers[_currentIndex];
    final newScale = (controller.scale ?? 1.0) * 1.3;
    controller.scale = newScale.clamp(0.2, 5.0);
  }

  void _zoomOut() {
    final controller = _photoControllers[_currentIndex];
    final newScale = (controller.scale ?? 1.0) / 1.3;
    controller.scale = newScale.clamp(0.2, 5.0);
  }

  String _formatFileSize(dynamic bytes) {
    if (bytes == null) return 'Unknown';
    try {
      final b = int.tryParse(bytes.toString()) ?? 0;
      if (b < 1024) return '${b} B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Unknown';
    }
  }

  // Replace this with your supabase call or URL builder
  String getImageUrl(Map<String, dynamic> image) {
    try {
      // keeping original style: supabase.storage.from('attachments').getPublicUrl(...)
      // If `supabase` is not in scope, change this function accordingly.
      final path = image['file_path']?.toString() ?? '';
      // Example placeholder fallback
      if (path.isEmpty) return '';
      return supabase.storage.from('attachments').getPublicUrl(path);
    } catch (_) {
      return image['file_path']?.toString() ?? '';
    }
  }

  // Keyboard navigation for web/desktop
  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _next();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previous();
      } else if (event.logicalKey == LogicalKeyboardKey.add ||
          event.logicalKey == LogicalKeyboardKey.equal) {
        _zoomIn();
      } else if (event.logicalKey == LogicalKeyboardKey.minus) {
        _zoomOut();
      }
    }
  }

  void _shareImage() {
    final l10n = AppLocalizations.safeOf(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.shareNotImplemented)),
    );
  }

  void _showImageInfo() {
    final l10n = AppLocalizations.safeOf(context);
    final currentImage = widget.images[_currentIndex];
    DateTime? createdAt;
    if (currentImage['created_at'] != null) {
      try {
        createdAt = DateTime.parse(currentImage['created_at'].toString());
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(l10n.imageDetails),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(l10n.name, currentImage['file_name'] ?? l10n.unknown),
            const SizedBox(height: 8),
            _infoRow(
                l10n.size, _formatFileSize(currentImage['file_size'] ?? 0)),
            const SizedBox(height: 8),
            _infoRow(l10n.type, currentImage['mime_type'] ?? l10n.unknown),
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                l10n.uploaded,
                DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final media = MediaQuery.of(context);
    final isSmallHeight = media.size.height < 500;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RawKeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKey: kIsWeb || !defaultTargetPlatform.toString().contains('android')
              ? _onKey
              : (_) {},
          child: Stack(
            children: [
              // PhotoView gallery
              GestureDetector(
                onTap: _toggleUI,
                child: PhotoViewGallery.builder(
                  pageController: _pageController,
                  itemCount: widget.images.length,
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (context, index) {
                    final image = widget.images[index];
                    final imageUrl = getImageUrl(image);

                    return PhotoViewGalleryPageOptions(
                      imageProvider:
                          imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                      controller: _photoControllers[index],
                      scaleStateController: _scaleStateControllers[index],
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained * 0.2,
                      maxScale: PhotoViewComputedScale.covered * 5.0,
                      heroAttributes: PhotoViewHeroAttributes(
                        tag: image['id'] ?? '$index',
                      ),
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image,
                                color: Colors.white54, size: 80),
                            const SizedBox(height: 12),
                            Text(
                              l10n.failedToLoadImage,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              image['file_name'] ?? l10n.unknownFile,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  loadingBuilder: (context, event) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            value: event == null
                                ? null
                                : (event.cumulativeBytesLoaded /
                                    (event.expectedTotalBytes ?? 1)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.loadingImage,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.black),
                  scrollDirection: Axis.horizontal,
                ),
              ),

              // Top bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                top: _showUI ? 0 : -80,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: 56,
                    child: Row(
                      children: [
                        _roundIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_currentIndex + 1} / ${widget.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _roundIconButton(
                          icon: Icons.share,
                          onTap: _shareImage,
                        ),
                        const SizedBox(width: 8),
                        _roundIconButton(
                          icon: Icons.info_outline,
                          onTap: _showImageInfo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom panel (thumbnail + controls) - same as before
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                bottom: _showUI ? 0 : -160,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.images[_currentIndex]['file_name'] ??
                                      l10n.unknown,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _roundIconButton(
                              icon: Icons.zoom_out_map,
                              onTap: () {
                                _scaleStateControllers[_currentIndex]
                                    .scaleState = PhotoViewScaleState.initial;
                                _photoControllers[_currentIndex].scale =
                                    (PhotoViewComputedScale.contained * 1)
                                        as double?;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Thumbnails - same as before
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.images.length,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            itemBuilder: (ctx, idx) {
                              final img = widget.images[idx];
                              final url = getImageUrl(img);
                              final isSelected = idx == _currentIndex;

                              return GestureDetector(
                                onTap: () => _pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOut,
                                ),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    color: Colors.grey[900],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: url.isNotEmpty
                                        ? Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              color: Colors.grey[800],
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.white54,
                                                size: 20,
                                              ),
                                            ),
                                          )
                                        : Container(color: Colors.grey[800]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Left / right navigation
              if (_showUI) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 60,
                    child: Center(
                      child: IconButton(
                        iconSize: 34,
                        color: Colors.white70,
                        onPressed: _previous,
                        icon: const Icon(Icons.chevron_left),
                        tooltip: l10n.previous,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 60,
                    child: Center(
                      child: IconButton(
                        iconSize: 34,
                        color: Colors.white70,
                        onPressed: _next,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: l10n.next,
                      ),
                    ),
                  ),
                ),

                // Zoom controls
                Positioned(
                  right: 14,
                  bottom: isSmallHeight ? 110 : 180,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        mini: true,
                        onPressed: _zoomIn,
                        child: const Icon(Icons.zoom_in),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        mini: true,
                        onPressed: _zoomOut,
                        child: const Icon(Icons.zoom_out),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style:
                TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class AssignTicketDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onTicketAssigned;

  const AssignTicketDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onTicketAssigned,
  });

  @override
  State<AssignTicketDialog> createState() => _AssignTicketDialogState();
}

class _AssignTicketDialogState extends State<AssignTicketDialog> {
  List<AdminWithNatureOfWork> _admins = [];
  String? _selectedAdminId;
  bool _isLoading = false;
  bool _loadingAdmins = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    try {
      setState(() => _loadingAdmins = true);

      // If ticket has nature of work, get sorted list with matching admins first
      if (widget.ticket.natureOfWorkId != null) {
        final response = await supabase.rpc(
          'get_recommended_admins',
          params: {
            'p_department_id': widget.ticket.targetDepartmentId,
            'p_nature_of_work_id': widget.ticket.natureOfWorkId,
          },
        );

        setState(() {
          _admins = (response as List)
              .map((json) => AdminWithNatureOfWork.fromJson(json))
              .toList();
          _loadingAdmins = false;
        });
      } else {
        // No nature of work - load all admins alphabetically
        final response = await supabase
            .from('users')
            .select('id, full_name, email')
            .eq('department_id', widget.ticket.targetDepartmentId)
            .eq('user_type', 'admin')
            .eq('is_active', true)
            .order('full_name');

        setState(() {
          _admins = (response as List)
              .map((json) => AdminWithNatureOfWork(
                    adminId: json['id'],
                    fullName: json['full_name'],
                    email: json['email'],
                    matchingNatureOfWork: false,
                    natureOfWorkNames: [],
                  ))
              .toList();
          _loadingAdmins = false;
        });
      }
    } catch (e) {
      print('Error loading admins: $e');
      setState(() => _loadingAdmins = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading admins: $e')),
        );
      }
    }
  }

  Future<void> _assignTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_selectedAdminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectAdmin)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await TicketService.assignTicket(
        widget.ticket.id,
        _selectedAdminId!,
      );

      if (success) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pop(context);
          widget.onTicketAssigned();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.ticketAssignedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorAssigningTicket}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return OptimizedDialog(
      title: '${l10n.assignTicket} ${widget.ticket.ticketNumber}',
      contentPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.ticket.natureOfWorkId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.matchingAdminsShownFirst,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_loadingAdmins)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_admins.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(l10n.noAvailableAdminsFound),
            )
          else
            ..._admins.map((admin) {
              final isSelected = _selectedAdminId == admin.adminId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: admin.matchingNatureOfWork
                      ? Colors.green.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue
                        : admin.matchingNatureOfWork
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: RadioListTile<String>(
                  value: admin.adminId,
                  groupValue: _selectedAdminId,
                  onChanged: (value) {
                    setState(() => _selectedAdminId = value);
                  },
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  dense: true,
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              admin.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (admin.matchingNatureOfWork)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l10n.match,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: admin.natureOfWorkNames.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: admin.natureOfWorkNames
                                .map((name) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _assignTicket,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.assign),
        ),
      ],
    );
  }
}

class FinishTicketDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onTicketFinished;
  final bool isUnderSupervision; // NEW PARAMETER

  const FinishTicketDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onTicketFinished,
    this.isUnderSupervision = false, // NEW PARAMETER WITH DEFAULT
  });

  @override
  State<FinishTicketDialog> createState() => _FinishTicketDialogState();
}

class _FinishTicketDialogState extends State<FinishTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<XFile> _attachments = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _attachments.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<List<String>> _uploadAttachments() async {
    final List<String> uploadedPaths = [];

    for (final file in _attachments) {
      try {
        final bytes = await file.readAsBytes();
        final fileExt = file.path.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUser.id}.$fileExt';
        final filePath = 'ticket_reports/${widget.ticket.id}/$fileName';

        await supabase.storage.from('attachments').uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$fileExt',
                upsert: false,
              ),
            );

        uploadedPaths.add(filePath);
      } catch (e) {
        print('Error uploading file: $e');
      }
    }

    return uploadedPaths;
  }

  Future<void> _submitReport() async {
    final l10n = AppLocalizations.safeOf(context);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final attachmentPaths = await _uploadAttachments();

      final success = widget.isUnderSupervision
          ? await TicketService.markTicketUnderSupervision(
              ticketId: widget.ticket.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              attachmentPaths:
                  attachmentPaths.isNotEmpty ? attachmentPaths : null,
            )
          : await TicketService.markTicketFinished(
              ticketId: widget.ticket.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              attachmentPaths:
                  attachmentPaths.isNotEmpty ? attachmentPaths : null,
            );

      if (success && mounted) {
        Navigator.pop(context);

        final message = widget.isUnderSupervision
            ? l10n.ticketMarkedUnderSupervision
            : l10n.workReportSubmittedSuccess;

        final color =
            widget.isUnderSupervision ? Colors.deepPurple : Colors.purple;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            duration: const Duration(seconds: 4),
          ),
        );

        widget.onTicketFinished();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSubmitReport),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return OptimizedDialog(
      title: widget.isUnderSupervision
          ? l10n.markUnderSupervision
          : l10n.markTicketFinished,
      contentPadding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.isUnderSupervision
                    ? Colors.deepPurple.withOpacity(0.1)
                    : Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isUnderSupervision
                      ? Colors.deepPurple.withOpacity(0.3)
                      : Colors.purple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: widget.isUnderSupervision
                        ? Colors.deepPurple
                        : Colors.purple,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isUnderSupervision
                          ? l10n.autoApprovalAfterMonitoring
                          : l10n.creatorWillReviewWork,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // Title field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '${l10n.reportTitle} *',
                hintText: l10n.briefSummary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.required;
                }
                return null;
              },
              maxLength: 255,
            ),
            const SizedBox(height: 12),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '${l10n.description} *',
                hintText: l10n.workPerformed,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.required;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Attachments section
            Row(
              children: [
                Text(
                  l10n.attachments,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(l10n.add, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),

            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  itemBuilder: (context, index) {
                    final file = _attachments[index];
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                const Expanded(
                                  child: Center(
                                    child:
                                        Icon(Icons.image, color: Colors.blue),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    file.name,
                                    style: const TextStyle(fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: GestureDetector(
                              onTap: () => _removeAttachment(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                widget.isUnderSupervision ? Colors.deepPurple : Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.isUnderSupervision ? l10n.markSupervised : l10n.submit,
                  style: const TextStyle(fontSize: 13),
                ),
        ),
      ],
    );
  }
}

// New dialog for marking tickets as wrong info
class WrongInfoDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onWrongInfoSubmitted;

  const WrongInfoDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onWrongInfoSubmitted,
  });

  @override
  State<WrongInfoDialog> createState() => _WrongInfoDialogState();
}

class _WrongInfoDialogState extends State<WrongInfoDialog> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitWrongInfo() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseProvideFeedback)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.from('ticket_approvals').insert({
        'ticket_id': widget.ticket.id,
        'approved_by': widget.currentUser.id,
        'is_approved': false,
        'rejection_reason': 'WRONG INFO: ${_feedbackController.text.trim()}',
      });

      await TicketService.updateTicket(widget.ticket.id, {
        'status': TicketStatus.wrongInfo.value,
      });

      await NotificationService.createAndSendNotification(
        userId: widget.ticket.createdBy,
        type: 'wrong_info_marked',
        title: 'Ticket Marked as Wrong Information',
        message:
            'Your ticket ${widget.ticket.ticketNumber} has been marked as having incorrect information. Please review and create a corrected ticket.',
        ticketId: widget.ticket.id,
        additionalData: {
          'ticket_number': widget.ticket.ticketNumber,
          'feedback': _feedbackController.text.trim(),
          'marked_by': widget.currentUser.id,
        },
      );

      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context);
        widget.onWrongInfoSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ticketMarkedWrongInformation)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorMarkingWrongInfo}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return OptimizedDialog(
      title: l10n.markAsWrongInformation,
      contentPadding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.ticket}: ${widget.ticket.ticketNumber}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.provideFeedbackIncorrect,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _feedbackController,
            decoration: InputDecoration(
              labelText: '${l10n.feedback} *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.explainWhatNeedsCorrected,
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
            maxLines: 5,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitWrongInfo,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l10n.markAsWrongInfo,
                  style: const TextStyle(fontSize: 13),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}

class StatusReversalDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final List<TicketStatus> availableStatuses;
  final VoidCallback onStatusChanged;

  const StatusReversalDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.availableStatuses,
    required this.onStatusChanged,
  });

  @override
  State<StatusReversalDialog> createState() => _StatusReversalDialogState();
}

class _StatusReversalDialogState extends State<StatusReversalDialog> {
  TicketStatus? _selectedStatus;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  String _getStatusDescription(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return 'Move back to pending - Waiting for assignment';
      case TicketStatus.inprogress:
        return 'Move to in-progress - Active work status';
      case TicketStatus.prefinished:
        return 'Move to pre-finished - Awaiting approval';
      case TicketStatus.closed:
        return 'Mark as closed - Work completed';
      case TicketStatus.wrongInfo:
        return 'Mark as wrong info - Incorrect information';
      case TicketStatus.deleted:
        return 'Mark as deleted - Remove from active tickets';
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.inprogress:
        return Colors.blue;
      case TicketStatus.prefinished:
        return Colors.amber;
      case TicketStatus.closed:
        return Colors.green;
      case TicketStatus.wrongInfo:
        return Colors.red;
      case TicketStatus.deleted:
        return Colors.grey;
    }
  }

  bool _requiresAdditionalAction(TicketStatus newStatus) {
    // Some status changes might require additional actions
    return newStatus == TicketStatus.inprogress &&
        widget.ticket.assignedTo == null;
  }

  Future<void> _changeStatus() async {
    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a status')),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide a reason for the status change')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = <String, dynamic>{
        'status': _selectedStatus!.value,
      };

      // Handle specific status change requirements
      if (_selectedStatus == TicketStatus.inprogress &&
          widget.ticket.assignedTo == null) {
        // Auto-assign to current user if moving to in-progress and no one is assigned
        updateData['assigned_to'] = widget.currentUser.id;
      }

      // Update the ticket status
      await supabase
          .from('tickets')
          .update(updateData)
          .eq('id', widget.ticket.id);

      // Create a record of the status change
      await supabase.from('ticket_approvals').insert({
        'ticket_id': widget.ticket.id,
        'approved_by': widget.currentUser.id,
        'is_approved': null, // This is a status change, not an approval
        'notes':
            'Status changed from ${widget.ticket.status.value} to ${_selectedStatus!.value}',
        'rejection_reason': 'STATUS CHANGE: ${_reasonController.text.trim()}',
      });

      // Send notifications based on the new status
      await _sendStatusChangeNotifications();

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onStatusChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ticket status changed to ${_selectedStatus!.value.replaceAll('_', ' ')}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing status: $e')),
        );
      }
    }
  }

  Future<void> _sendStatusChangeNotifications() async {
    try {
      String notificationTitle = 'Ticket Status Changed';
      String notificationBody =
          'Ticket ${widget.ticket.ticketNumber} status changed to ${_selectedStatus!.value.replaceAll('_', ' ')}';

      // // Notify ticket creator
      // if (widget.ticket.createdBy != widget.currentUser.id) {
      //   await NotificationService.createNotification(
      //     widget.ticket.createdBy,
      //     notificationTitle,
      //     notificationBody,
      //     widget.ticket.id,
      //   );
      // }

      // // Notify assigned admin if different from current user
      // if (widget.ticket.assignedTo != null &&
      //     widget.ticket.assignedTo != widget.currentUser.id) {
      //   await NotificationService.createNotification(
      //     widget.ticket.assignedTo!,
      //     notificationTitle,
      //     notificationBody,
      //     widget.ticket.id,
      //   );
      // }

      // Notify super admins of the department
      final superAdmins = await supabase
          .from('users')
          .select('id')
          .eq('user_type', 'super_admin')
          .eq('department_id', widget.ticket.targetDepartmentId)
          .eq('is_active', true);

      // for (final superAdmin in superAdmins) {
      //   if (superAdmin['id'] != widget.currentUser.id) {
      //     await NotificationService.createNotification(
      //       superAdmin['id'],
      //       notificationTitle,
      //       '$notificationBody by ${widget.currentUser.fullName}',
      //       widget.ticket.id,
      //     );
      //   }
      // }
    } catch (e) {
      print('Error sending status change notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Change Ticket Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Current status info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.ticket.status)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.ticket.status.value
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(widget.ticket.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status selection
            const Text(
              'Select New Status:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...widget.availableStatuses.map((status) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: RadioListTile<TicketStatus>(
                            title: Text(
                              status.value.replaceAll('_', ' ').toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              _getStatusDescription(status),
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: status,
                            groupValue: _selectedStatus,
                            onChanged: (value) =>
                                setState(() => _selectedStatus = value),
                            activeColor: _getStatusColor(status),
                            secondary: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: _getStatusColor(status)),
                              ),
                            ),
                          ),
                        )),

                    const SizedBox(height: 16),

                    // Reason input
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Status Change *',
                        border: OutlineInputBorder(),
                        hintText: 'Explain why you are changing the status...',
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Warning for specific status changes
                    if (_selectedStatus != null &&
                        _requiresAdditionalAction(_selectedStatus!)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'This will auto-assign the ticket to you since no one is currently assigned.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changeStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedStatus != null
                          ? _getStatusColor(_selectedStatus!)
                          : null,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Change Status'),
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

// Replace CreateTicketDialog in tickets.dart
class CreateTicketDialog extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;
  final TicketModel? prefillFromTicket;

  const CreateTicketDialog({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
    this.prefillFromTicket,
  });

  @override
  State<CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _customProblemController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _customModelController = TextEditingController();
  final _otherNatureOfWorkController = TextEditingController();
  final _otherPlaceController = TextEditingController();
  final _otherProblemTitleController = TextEditingController();
  final _otherModelNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedPlaceId;
  String? _selectedProblemTitleId;
  String? _selectedModelNumberId;
  String? _selectedNatureOfWorkId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<PlaceModel> _places = [];
  List<Map<String, dynamic>> _problemTitles = [];
  List<Map<String, dynamic>> _parts = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];

  bool _isLoading = false;
  bool _isLoadingData = true; // ADD THIS
  bool _useOtherNatureOfWork = false;
  bool _useOtherPlace = false;
  bool _useOtherProblemTitle = false;
  bool _useOtherModelNumber = false;
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _selectedPlaceId = widget.currentUser.placeId;
    _initializeDialog(); // CHANGE THIS
  }

  // ADD THIS METHOD
  Future<void> _initializeDialog() async {
    await _loadData();

    if (widget.prefillFromTicket != null) {
      await _prefillFromWrongInfoTicket();
    }

    setState(() {
      _isLoadingData = false;
    });
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      final placesResponse = await supabase.from('places').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
        _places = placesResponse
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
        _useOtherNatureOfWork = false;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadProblemTitles(String departmentId) async {
    try {
      final response = await supabase
          .from('problem_titles')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _problemTitles = response;
      });
    } catch (e) {
      print('Error loading problem titles: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  // CHANGE THIS METHOD TO ASYNC AND ADD AWAIT
  Future<void> _prefillFromWrongInfoTicket() async {
    final ticket = widget.prefillFromTicket!;

    _titleController.text = ticket.title;
    _descriptionController.text = ticket.description;
    _locationController.text = ticket.location ?? '';
    _selectedDepartmentId = ticket.targetDepartmentId;
    _selectedPlaceId = ticket.placeId;
    _selectedPriority = ticket.priority;
    _highPriorityController.text = ticket.highPriorityExplain ?? '';
    _customModelController.text = ticket.customModelNumber ?? '';
    _customProblemController.text = ticket.customProblemTitle ?? '';

    if (ticket.customProblemTitle != null) {
      _useOtherProblemTitle = true;
    }
    if (ticket.customModelNumber != null) {
      _useOtherModelNumber = true;
    }

    // LOAD RELATED DATA BEFORE SETTING STATE
    if (_selectedDepartmentId != null) {
      await _loadProblemTitles(_selectedDepartmentId!);
      await _loadParts(_selectedDepartmentId!);
      await _loadNatureOfWorkForDepartment(_selectedDepartmentId!);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowedExtensions: null,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      print('Error picking files: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      print('Error uploading files: $e');
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDepartmentId == null ||
        (_selectedPlaceId == null && !_useOtherPlace)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if (!_useOtherNatureOfWork && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectNatureOfWork)),
      );
      return;
    }

    if (_useOtherNatureOfWork &&
        _otherNatureOfWorkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSpecifyOtherNatureOfWork)),
      );
      return;
    }

    if (_useOtherPlace && _otherPlaceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSpecifyOtherPlace)),
      );
      return;
    }

    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        'place_id': _useOtherPlace ? null : _selectedPlaceId,
        'other_place':
            _useOtherPlace ? _otherPlaceController.text.trim() : null,
        'location': _locationController.text.isNotEmpty
            ? _locationController.text.trim()
            : null,
        'nature_of_work_id':
            _useOtherNatureOfWork ? null : _selectedNatureOfWorkId,
        'other_nature_of_work': _useOtherNatureOfWork
            ? _otherNatureOfWorkController.text.trim()
            : null,
        'problem_title_id':
            _useOtherProblemTitle ? null : _selectedProblemTitleId,
        'other_problem_title': _useOtherProblemTitle
            ? _otherProblemTitleController.text.trim()
            : null,
        'custom_problem_title': null,
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'model_number_id': _useOtherModelNumber ? null : _selectedModelNumberId,
        'other_model_number': _useOtherModelNumber
            ? _otherModelNumberController.text.trim()
            : null,
        'custom_model_number': null,
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final successMessage = _selectedFiles.isNotEmpty
            ? '${l10n.ticket} #$ticketNumber ${l10n.ticketCreatedSuccessfullyWith} ${_selectedFiles.length} ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}'
            : '${l10n.ticket} #$ticketNumber ${l10n.ticketCreatedSuccessfully}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedCreateTicket}: $e')),
        );
      }
      print('Error creating ticket: $e');
    }
  }

  Widget _buildFileAttachmentSection() {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachmentsSection,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image),
              label: Text(l10n.images),
            ),
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.files),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFiles.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(
                                        file.bytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedFiles.length} ${_selectedFiles.length != 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // ADD LOADING STATE CHECK
    if (_isLoadingData) {
      return OptimizedDialog(
        title: widget.prefillFromTicket != null
            ? l10n.createCorrectedTicket
            : l10n.createNewTicket,
        width: isMobile ? null : MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.95,
        contentPadding: const EdgeInsets.all(16),
        isScrollable: true,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.loading,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [],
      );
    }

    return OptimizedDialog(
      title: widget.prefillFromTicket != null
          ? l10n.createCorrectedTicket
          : l10n.createNewTicket,
      width: isMobile ? null : MediaQuery.of(context).size.width * 0.7,
      height: MediaQuery.of(context).size.height * 0.95,
      contentPadding: const EdgeInsets.all(16),
      isScrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.prefillFromTicket != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.creatingCorrectedTicketFrom} ${widget.prefillFromTicket!.ticketNumber}. ${l10n.pleaseReviewAndUpdate}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Title
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.titleRequired,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.briefDescriptionSubtask,
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.descriptionRequired,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.detailedDescriptionTodo,
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          // Phone Number
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: l10n.phoneNumberRequired,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.contactPhoneNumber,
              prefixIcon: const Icon(Icons.phone),
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Department Dropdown with Search
          SearchableDropdown<String>(
            labelText: l10n.targetDepartmentRequired,
            hintText: l10n.selectDepartmentSubtask,
            value: _selectedDepartmentId,
            items: _departments
                .map((dept) => DropdownMenuItem(
                      value: dept.id,
                      child: Text(dept.localizedName(lang)),
                    ))
                .toList(),
            getLabel: (id) {
              try {
                return _departments.firstWhere((d) => d.id == id).localizedName(lang);
              } catch (e) {
                return l10n.unknown;
              }
            },
            onChanged: (value) {
              setState(() {
                _selectedDepartmentId = value;
                _selectedProblemTitleId = null;
                _selectedModelNumberId = null;
                _selectedNatureOfWorkId = null;
                _problemTitles.clear();
                _parts.clear();
                _natureOfWorkList.clear();
              });
              if (value != null) {
                _loadProblemTitles(value);
                _loadParts(value);
                _loadNatureOfWorkForDepartment(value);
              }
            },
          ),
          const SizedBox(height: 16),

          // Nature of Work Section
          if (_selectedDepartmentId != null) ...[
            Text(
              l10n.natureOfWorkRequired,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_useOtherNatureOfWork) ...[
              TextField(
                controller: _otherNatureOfWorkController,
                decoration: InputDecoration(
                  labelText: l10n.specifyNatureOfWork,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: l10n.describeNatureOfWork,
                  contentPadding: const EdgeInsets.all(12),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _useOtherNatureOfWork = false;
                        _otherNatureOfWorkController.clear();
                      });
                    },
                  ),
                ),
              ),
            ] else if (_natureOfWorkList.isNotEmpty) ...[
              SearchableDropdown<String>(
                labelText: l10n.natureOfWork,
                hintText: l10n.selectNatureOfWork,
                value: _selectedNatureOfWorkId,
                items: _natureOfWorkList
                    .map((now) => DropdownMenuItem(
                          value: now.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(now.localizedName(lang)),
                              if (now.description != null)
                                Text(
                                  now.description!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ))
                    .toList(),
                getLabel: (id) {
                  try {
                    return _natureOfWorkList.firstWhere((n) => n.id == id).localizedName(lang);
                  } catch (e) {
                    return l10n.unknown;
                  }
                },
                showOtherOption: true,
                onOtherSelected: () {
                  setState(() {
                    _useOtherNatureOfWork = true;
                    _selectedNatureOfWorkId = null;
                  });
                },
                onChanged: (value) {
                  setState(() => _selectedNatureOfWorkId = value);
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.noNatureWorkAvailableClickBelow,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _useOtherNatureOfWork = true;
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.specifyOther),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Place Dropdown with Search and Other Option
          if (_useOtherPlace) ...[
            TextField(
              controller: _otherPlaceController,
              decoration: InputDecoration(
                labelText: l10n.specifyPlace,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: l10n.enterPlaceName,
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _useOtherPlace = false;
                      _otherPlaceController.clear();
                    });
                  },
                ),
              ),
            ),
          ] else ...[
            SearchableDropdown<String>(
              labelText: '${l10n.place} *',
              hintText: l10n.selectPlace,
              value: _selectedPlaceId,
              items: _places
                  .map((place) => DropdownMenuItem(
                        value: place.id,
                        child: Text(place.localizedName(lang)),
                      ))
                  .toList(),
              getLabel: (id) {
                try {
                  return _places.firstWhere((p) => p.id == id).localizedName(lang);
                } catch (e) {
                  return l10n.unknown;
                }
              },
              showOtherOption: true,
              onOtherSelected: () {
                setState(() {
                  _useOtherPlace = true;
                  _selectedPlaceId = null;
                });
              },
              onChanged: (value) {
                setState(() => _selectedPlaceId = value);
              },
            ),
          ],
          const SizedBox(height: 16),

          // Specific Location
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: l10n.specificLocation,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.specificLocationHint,
              prefixIcon: const Icon(Icons.location_on),
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Problem Title with Search and Other Option
          if (_problemTitles.isNotEmpty || _useOtherProblemTitle) ...[
            Text(
              l10n.problemTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_useOtherProblemTitle) ...[
              TextField(
                controller: _otherProblemTitleController,
                decoration: InputDecoration(
                  labelText: l10n.specifyProblemTitle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: l10n.describeProblem,
                  contentPadding: const EdgeInsets.all(12),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _useOtherProblemTitle = false;
                        _otherProblemTitleController.clear();
                      });
                    },
                  ),
                ),
              ),
            ] else ...[
              SearchableDropdown<String>(
                labelText: l10n.problemTitle,
                hintText: l10n.selectProblemType,
                value: _selectedProblemTitleId,
                items: _problemTitles
                    .map((problem) => DropdownMenuItem(
                          value: problem['id'] as String,
                          child: Text(problem['title'] as String),
                        ))
                    .toList(),
                getLabel: (id) {
                  try {
                    return _problemTitles
                        .firstWhere((p) => p['id'] == id)['title'] as String;
                  } catch (e) {
                    return l10n.unknown;
                  }
                },
                showOtherOption: true,
                onOtherSelected: () {
                  setState(() {
                    _useOtherProblemTitle = true;
                    _selectedProblemTitleId = null;
                  });
                },
                onChanged: (value) {
                  setState(() => _selectedProblemTitleId = value);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Priority Dropdown
          SearchableDropdown<PriorityType>(
            labelText: l10n.priorityRequired,
            value: _selectedPriority,
            items: PriorityType.values
                .map((priority) => DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            priority == PriorityType.urgent
                                ? Icons.emergency
                                : priority == PriorityType.high
                                    ? Icons.priority_high
                                    : priority == PriorityType.medium
                                        ? Icons.remove
                                        : Icons.low_priority,
                            color: priority == PriorityType.urgent
                                ? Colors.purple
                                : priority == PriorityType.high
                                    ? Colors.red
                                    : priority == PriorityType.medium
                                        ? Colors.orange
                                        : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(_getPriorityText(priority, l10n).toUpperCase()),
                        ],
                      ),
                    ))
                .toList(),
            getLabel: (priority) =>
                _getPriorityText(priority, l10n).toUpperCase(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedPriority = value);
              }
            },
          ),
          const SizedBox(height: 16),

          // High Priority Explanation
          if (_selectedPriority == PriorityType.high ||
              _selectedPriority == PriorityType.urgent) ...[
            TextField(
              controller: _highPriorityController,
              decoration: InputDecoration(
                labelText: l10n.highPriorityExplanationRequired,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: l10n.explainHighUrgentPriority,
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
          ],

          // Model Number with Search and Other Option
          if (_parts.isNotEmpty || _useOtherModelNumber) ...[
            Text(
              l10n.modelNumber,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_useOtherModelNumber) ...[
              TextField(
                controller: _otherModelNumberController,
                decoration: InputDecoration(
                  labelText: l10n.specifyModelNumber,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: l10n.enterModelNumber,
                  contentPadding: const EdgeInsets.all(12),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _useOtherModelNumber = false;
                        _otherModelNumberController.clear();
                      });
                    },
                  ),
                ),
              ),
            ] else ...[
              SearchableDropdown<String>(
                labelText: l10n.modelNumber,
                hintText: l10n.selectDevicePart,
                value: _selectedModelNumberId,
                items: _parts
                    .map((part) => DropdownMenuItem(
                          value: part['id'] as String,
                          child: Text(
                            '${part['model_number']} - ${part['name']}',
                          ),
                        ))
                    .toList(),
                getLabel: (id) {
                  try {
                    final part = _parts.firstWhere((p) => p['id'] == id);
                    return '${part['model_number']} - ${part['name']}';
                  } catch (e) {
                    return l10n.unknown;
                  }
                },
                showOtherOption: true,
                onOtherSelected: () {
                  setState(() {
                    _useOtherModelNumber = true;
                    _selectedModelNumberId = null;
                  });
                },
                onChanged: (value) {
                  setState(() => _selectedModelNumberId = value);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],

          // File Attachments Section
          _buildFileAttachmentSection(),
          const SizedBox(height: 16),

          // Information Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      l10n.ticketInformation,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${l10n.makeSureAllRequiredFieldsFilled}\n'
                  '• ${l10n.provideAccuratePhoneNumber}\n'
                  '• ${l10n.addDetailedDescription}\n'
                  '• ${l10n.attachRelevantImages}\n'
                  '• ${l10n.useOtherOptionIfNotInList}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploadingFiles)
              ? null
              : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: (_isLoading || _isUploadingFiles) ? null : _createTicket,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: (_isLoading || _isUploadingFiles)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFiles ? l10n.uploading : l10n.creating,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                )
              : Text(
                  l10n.createTicket,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _customProblemController.dispose();
    _highPriorityController.dispose();
    _customModelController.dispose();
    _otherNatureOfWorkController.dispose();
    _otherPlaceController.dispose();
    _otherProblemTitleController.dispose();
    _otherModelNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }
}

// Add this new dialog for ticket approval/rejection

class TicketApprovalDialog extends StatefulWidget {
  final TicketModel ticket;
  final UserModel currentUser;
  final VoidCallback onApprovalSubmitted;

  const TicketApprovalDialog({
    super.key,
    required this.ticket,
    required this.currentUser,
    required this.onApprovalSubmitted,
  });

  @override
  State<TicketApprovalDialog> createState() => _TicketApprovalDialogState();
}

class _TicketApprovalDialogState extends State<TicketApprovalDialog> {
  final _notesController = TextEditingController();
  final _rejectionReasonController = TextEditingController();
  bool _isApproved = true;
  bool _isLoading = false;
  Map<String, dynamic>? _ticketReport;

  @override
  void initState() {
    super.initState();
    _loadTicketReport();
  }

  Future<void> _loadTicketReport() async {
    try {
      final response = await supabase
          .from('ticket_reports')
          .select('*, ticket_report_attachments(*)')
          .eq('ticket_id', widget.ticket.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        setState(() => _ticketReport = response.first);
      }
    } catch (e) {
      print('Error loading ticket report: $e');
    }
  }

  Future<void> _submitApproval() async {
    if (_isApproved && _notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add notes for approval')),
      );
      return;
    }

    if (!_isApproved && _rejectionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for rejection')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create approval record
      await supabase.from('ticket_approvals').insert({
        'ticket_id': widget.ticket.id,
        'approved_by': widget.currentUser.id,
        'is_approved': _isApproved,
        'notes': _isApproved ? _notesController.text.trim() : null,
        'rejection_reason':
            !_isApproved ? _rejectionReasonController.text.trim() : null,
      });

      // Update ticket status
      final newStatus = _isApproved
          ? TicketStatus.closed.value
          : TicketStatus.inprogress.value;
      await supabase.from('tickets').update({
        'status': newStatus,
      }).eq('id', widget.ticket.id);

      // Send notification to assigned admin
      // if (widget.ticket.assignedTo != null) {
      //   await NotificationService.createNotification(
      //     widget.ticket.assignedTo!,
      //     'Ticket ${_isApproved ? 'Approved' : 'Rejected'}',
      //     'Ticket ${widget.ticket.ticketNumber} has been ${_isApproved ? 'approved and closed' : 'rejected and returned to in-progress'}',
      //     widget.ticket.id,
      //   );
      // }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onApprovalSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Ticket ${_isApproved ? 'approved' : 'rejected'} successfully')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting approval: $e')),
        );
      }
    }
  }

// Replace the build method in _TicketApprovalDialogState
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return OptimizedDialog(
      title: 'Review Ticket: ${widget.ticket.ticketNumber}',
      width: isMobile ? null : MediaQuery.of(context).size.width * 0.7,
      height: isMobile
          ? MediaQuery.of(context).size.height * 0.9
          : MediaQuery.of(context).size.height * 0.8,
      contentPadding: const EdgeInsets.all(16),
      isScrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show ticket report
          if (_ticketReport != null) ...[
            const Text(
              'Admin Report:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Title: ${_ticketReport!['title']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Description: ${_ticketReport!['description']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submitted: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_ticketReport!['created_at']))}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (_ticketReport!['ticket_report_attachments']?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Attachments: ${_ticketReport!['ticket_report_attachments'].length} file(s)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Approval/Rejection Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Decision:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Approve',
                            style: TextStyle(fontSize: 13)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        groupValue: _isApproved,
                        onChanged: (value) =>
                            setState(() => _isApproved = value!),
                        activeColor: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Reject & Return',
                            style: TextStyle(fontSize: 13)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        groupValue: _isApproved,
                        onChanged: (value) =>
                            setState(() => _isApproved = value!),
                        activeColor: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Approval notes
          if (_isApproved) ...[
            const Text(
              'Approval Notes:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Add your approval notes *',
                border: OutlineInputBorder(),
                hintText: 'Describe what was fixed and confirm the solution...',
                contentPadding: EdgeInsets.all(12),
                isDense: true,
              ),
              maxLines: 4,
            ),
          ],

          // Rejection reason
          if (!_isApproved) ...[
            const Text(
              'Rejection Reason:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Explain why you are rejecting this solution *',
                border: OutlineInputBorder(),
                hintText:
                    'Describe what is wrong or what still needs to be fixed...',
                contentPadding: EdgeInsets.all(12),
                isDense: true,
              ),
              maxLines: 4,
            ),
          ],

          const SizedBox(height: 16),

          // Information box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isApproved
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isApproved
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isApproved ? Icons.check_circle : Icons.warning,
                      color:
                          _isApproved ? Colors.green[700] : Colors.orange[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isApproved
                          ? 'Approval Information'
                          : 'Rejection Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isApproved
                            ? Colors.green[700]
                            : Colors.orange[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isApproved
                      ? '• The ticket will be marked as closed\n'
                          '• The admin will be notified of approval\n'
                          '• No further work can be done on this ticket'
                      : '• The ticket will return to in-progress status\n'
                          '• The admin will see your rejection reason\n'
                          '• The admin can continue working on the ticket',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitApproval,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isApproved ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isApproved ? 'Approve & Close' : 'Reject & Return',
                  style: const TextStyle(fontSize: 13),
                ),
        ),
      ],
    );
  }
}

class ParentTicketIndicator extends StatefulWidget {
  final TicketModel subticket;

  const ParentTicketIndicator({super.key, required this.subticket});

  @override
  State<ParentTicketIndicator> createState() => _ParentTicketIndicatorState();
}

class _ParentTicketIndicatorState extends State<ParentTicketIndicator> {
  TicketModel? _parentTicket;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.subticket.parentTicketId != null) {
      _loadParentTicket();
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing operations
    super.dispose();
  }

  Future<void> _loadParentTicket() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final parentTicket =
          await TicketService.getParentTicket(widget.subticket.id);

      if (mounted) {
        setState(() {
          _parentTicket = parentTicket;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading parent ticket: $e');
      if (mounted) {
        setState(() {
          _parentTicket = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subticket.parentTicketId == null) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading parent ticket...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    if (_parentTicket == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                'SUBTICKET OF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_parentTicket!.ticketNumber} - ${_parentTicket!.title}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_parentTicket!.status)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _parentTicket!.status.value.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(_parentTicket!.status),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(_parentTicket!.priority)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _parentTicket!.priority.value.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getPriorityColor(_parentTicket!.priority),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.inprogress:
        return Colors.blue;
      case TicketStatus.prefinished:
        return Colors.amber;
      case TicketStatus.closed:
        return Colors.green;
      case TicketStatus.wrongInfo:
        return Colors.red;
      case TicketStatus.deleted:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(PriorityType priority) {
    switch (priority) {
      case PriorityType.low:
        return Colors.green;
      case PriorityType.medium:
        return Colors.orange;
      case PriorityType.high:
        return Colors.red;
      case PriorityType.urgent:
        return Colors.purple;
    }
  }
}

// REPLACE the entire ITSolutionTicketScreen class

class ITSolutionTicketScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;

  const ITSolutionTicketScreen({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });

  @override
  State<ITSolutionTicketScreen> createState() => _ITSolutionTicketScreenState();
}

class _ITSolutionTicketScreenState extends State<ITSolutionTicketScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();

  PriorityType _selectedPriority = PriorityType.medium;
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;

  String? _itDepartmentId = '6c9672fb-fce3-4118-a460-cee9e9c6e874';

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.itSolutionTicket,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ITSolutionTicketDialogContent(
                titleController: _titleController,
                descriptionController: _descriptionController,
                highPriorityController: _highPriorityController,
                phoneController: _phoneController,
                selectedPriority: _selectedPriority,
                selectedFiles: _selectedFiles,
                onPriorityChanged: (value) {
                  setState(() => _selectedPriority = value);
                },
                onPickImages: _pickImages,
                onPickFiles: _pickFiles,
                onRemoveFile: _removeFile,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : _createTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isUploadingFiles)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isUploadingFiles
                                    ? l10n.uploading + '...'
                                    : l10n.creating + '...',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.createTicket,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    // Basic validation - only title and description required
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.title}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.description}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // High priority validation
    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseExplainHighPriority),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Phone validation
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // IT Department validation
    if (_itDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.error),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _itDepartmentId,
        'other_nature_of_work': 'Other',
        'other_place': 'Other',
        'location': null,
        'other_problem_title': 'Other',
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'other_model_number': 'Other',
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      print('📋 Creating IT ticket with data: $ticketData');

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.itSolutionTicket} #$ticketNumber ${l10n.subticketCreatedSuccessfully}$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating IT ticket: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

// ADD this new widget for content reuse
class ITSolutionTicketDialogContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController highPriorityController;
  final TextEditingController phoneController;
  final PriorityType selectedPriority;
  final List<PlatformFile> selectedFiles;
  final Function(PriorityType) onPriorityChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const ITSolutionTicketDialogContent({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.highPriorityController,
    required this.phoneController,
    required this.selectedPriority,
    required this.selectedFiles,
    required this.onPriorityChanged,
    required this.onPickImages,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: '${l10n.title} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: l10n.briefDescriptionSubtask,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Description
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: '${l10n.description} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: l10n.detailedDescriptionTodo,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 10),

        // Priority Dropdown
        DropdownButtonFormField<PriorityType>(
          value: selectedPriority,
          decoration: InputDecoration(
            labelText: '${l10n.priority} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          items: PriorityType.values.map((priority) {
            return DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Icon(
                    priority == PriorityType.urgent
                        ? Icons.emergency
                        : priority == PriorityType.high
                            ? Icons.priority_high
                            : priority == PriorityType.medium
                                ? Icons.remove
                                : Icons.low_priority,
                    color: priority == PriorityType.urgent
                        ? Colors.purple
                        : priority == PriorityType.high
                            ? Colors.red
                            : priority == PriorityType.medium
                                ? Colors.orange
                                : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPriorityText(priority, l10n).toUpperCase(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onPriorityChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),

        // High Priority Explanation
        if (selectedPriority == PriorityType.high ||
            selectedPriority == PriorityType.urgent) ...[
          TextField(
            controller: highPriorityController,
            decoration: InputDecoration(
              labelText: '${l10n.highPriorityExplanation} *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: l10n.explainWhyUrgent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
        ],

        // File Attachments Section
        _buildFileAttachmentSection(
          selectedFiles,
          onPickImages,
          onPickFiles,
          onRemoveFile,
          l10n,
        ),
        const SizedBox(height: 10),

        // Information Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.itSolutionTicket,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• ${l10n.itSolutionTicket}\n'
                '• ${l10n.briefDescriptionSubtask}\n'
                '• ${l10n.detailedDescriptionTodo}\n'
                '• ${l10n.explainWhyUrgent}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  Widget _buildFileAttachmentSection(
    List<PlatformFile> files,
    VoidCallback pickImages,
    VoidCallback pickFiles,
    Function(int) removeFile,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachments,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: pickImages,
              icon: const Icon(Icons.image, size: 18, color: Colors.blue),
              label:
                  Text(l10n.images, style: const TextStyle(color: Colors.blue)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            TextButton.icon(
              onPressed: pickFiles,
              icon: const Icon(Icons.attach_file, size: 18, color: Colors.blue),
              label:
                  Text(l10n.files, style: const TextStyle(color: Colors.blue)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (files.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(file.bytes!,
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${files.length} ${files.length > 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class PlacesMaintenanceTicketScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;

  const PlacesMaintenanceTicketScreen({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });

  @override
  State<PlacesMaintenanceTicketScreen> createState() =>
      _PlacesMaintenanceTicketScreenState();
}

class _PlacesMaintenanceTicketScreenState
    extends State<PlacesMaintenanceTicketScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customProblemController = TextEditingController();
  final _customModelController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedPlaceId;
  String? _selectedNatureOfWorkId;
  String? _selectedProblemTitleId;
  String? _selectedModelNumberId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<PlaceModel> _places = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];
  List<Map<String, dynamic>> _problemTitles = [];
  List<Map<String, dynamic>> _parts = [];

  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _useCustomProblem = false;
  bool _useCustomModel = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';

    if (widget.currentUser.userType == UserType.user ||
        widget.currentUser.userType == UserType.superUser) {
      _selectedPlaceId = widget.currentUser.placeId;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      List<PlaceModel> places;
      if (widget.currentUser.userType == UserType.branchAdmin) {
        places = await BranchAdminService.getBranchAdminPlaces(widget.currentUser.id);
      } else {
        final placesResponse = await supabase.from('places').select();
        places = placesResponse
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
      }
      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
        _places = places;
        if (widget.currentUser.userType == UserType.branchAdmin &&
            places.length == 1) {
          _selectedPlaceId = places.first.id;
        }
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadProblemTitles(String departmentId) async {
    try {
      final response = await supabase
          .from('problem_titles')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _problemTitles = response;
        _selectedProblemTitleId = null;
      });
    } catch (e) {
      print('Error loading problem titles: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
        _selectedModelNumberId = null;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  bool _canSelectPlace() {
    return widget.currentUser.userType == UserType.admin ||
        widget.currentUser.userType == UserType.superAdmin ||
        widget.currentUser.userType == UserType.systemAdmin ||
        widget.currentUser.userType == UserType.branchAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.placesMaintenanceTicket,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PlacesMaintenanceTicketContent(
                titleController: _titleController,
                descriptionController: _descriptionController,
                locationController: _locationController,
                highPriorityController: _highPriorityController,
                phoneController: _phoneController,
                customProblemController: _customProblemController,
                customModelController: _customModelController,
                selectedDepartmentId: _selectedDepartmentId,
                selectedPlaceId: _selectedPlaceId,
                selectedNatureOfWorkId: _selectedNatureOfWorkId,
                selectedProblemTitleId: _selectedProblemTitleId,
                selectedModelNumberId: _selectedModelNumberId,
                selectedPriority: _selectedPriority,
                departments: _departments,
                places: _places,
                natureOfWorkList: _natureOfWorkList,
                problemTitles: _problemTitles,
                parts: _parts,
                selectedFiles: _selectedFiles,
                useCustomProblem: _useCustomProblem,
                useCustomModel: _useCustomModel,
                canSelectPlace: _canSelectPlace(),
                onDepartmentChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedNatureOfWorkId = null;
                    _selectedProblemTitleId = null;
                    _selectedModelNumberId = null;
                    _natureOfWorkList.clear();
                    _problemTitles.clear();
                    _parts.clear();
                  });
                  if (value != null) {
                    _loadNatureOfWorkForDepartment(value);
                    _loadProblemTitles(value);
                    _loadParts(value);
                  }
                },
                onPlaceChanged: (value) {
                  setState(() => _selectedPlaceId = value);
                },
                onNatureOfWorkChanged: (value) {
                  setState(() => _selectedNatureOfWorkId = value);
                },
                onProblemTitleChanged: (value) {
                  setState(() => _selectedProblemTitleId = value);
                },
                onModelNumberChanged: (value) {
                  setState(() => _selectedModelNumberId = value);
                },
                onPriorityChanged: (value) {
                  setState(() => _selectedPriority = value);
                },
                onUseCustomProblemChanged: (value) {
                  setState(() {
                    _useCustomProblem = value;
                    if (_useCustomProblem) {
                      _selectedProblemTitleId = null;
                    } else {
                      _customProblemController.clear();
                    }
                  });
                },
                onUseCustomModelChanged: (value) {
                  setState(() {
                    _useCustomModel = value;
                    if (_useCustomModel) {
                      _selectedModelNumberId = null;
                    } else {
                      _customModelController.clear();
                    }
                  });
                },
                onPickImages: _pickImages,
                onPickFiles: _pickFiles,
                onRemoveFile: _removeFile,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : _createTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isUploadingFiles)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isUploadingFiles
                                    ? l10n.uploading + '...'
                                    : l10n.creating + '...',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.createTicket,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    // Basic validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.title}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.description}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${l10n.pleaseFillAllRequired} - ${l10n.targetDepartment}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Nature of Work validation - only if list is NOT empty
    if (_natureOfWorkList.isNotEmpty && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.natureOfWork}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.place}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate high priority explanation
    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseExplainHighPriority),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate phone number
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Problem title validation - Only if problemTitles exist
    if (_problemTitles.isNotEmpty) {
      if (!_useCustomProblem && _selectedProblemTitleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseSelectProblemOrCustom),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_useCustomProblem && _customProblemController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseEnterCustomProblem),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        // AUTO-SET: If nature of work list is empty, send "Other", otherwise send selected
        'nature_of_work_id':
            _natureOfWorkList.isNotEmpty ? _selectedNatureOfWorkId : null,
        'other_nature_of_work': _natureOfWorkList.isEmpty ? 'Other' : null,
        'place_id': _selectedPlaceId,
        'location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        // AUTO-SET: If problem titles list is empty, send "Other", otherwise send selected/custom
        'problem_title_id': (_problemTitles.isNotEmpty && !_useCustomProblem)
            ? _selectedProblemTitleId
            : null,
        'other_problem_title': _problemTitles.isEmpty
            ? 'Other'
            : (_useCustomProblem ? _customProblemController.text.trim() : null),
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        // AUTO-SET: If parts list is empty, send "Other", otherwise send selected/custom
        'model_number_id': (_parts.isNotEmpty && !_useCustomModel)
            ? _selectedModelNumberId
            : null,
        'other_model_number': _parts.isEmpty
            ? 'Other'
            : (_useCustomModel ? _customModelController.text.trim() : null),
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      print('📋 Creating place ticket with data: $ticketData');

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.placesMaintenanceTicket} #$ticketNumber ${l10n.subticketCreatedSuccessfully}$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating place ticket: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    _customProblemController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}

// PlacesMaintenanceTicketContent - Full Updated Method
class PlacesMaintenanceTicketContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TextEditingController highPriorityController;
  final TextEditingController phoneController;
  final TextEditingController customProblemController;
  final TextEditingController customModelController;
  final String? selectedDepartmentId;
  final String? selectedPlaceId;
  final String? selectedNatureOfWorkId;
  final String? selectedProblemTitleId;
  final String? selectedModelNumberId;
  final PriorityType selectedPriority;
  final List<DepartmentModel> departments;
  final List<PlaceModel> places;
  final List<NatureOfWorkModel> natureOfWorkList;
  final List<Map<String, dynamic>> problemTitles;
  final List<Map<String, dynamic>> parts;
  final List<PlatformFile> selectedFiles;
  final bool useCustomProblem;
  final bool useCustomModel;
  final bool canSelectPlace;
  final Function(String?) onDepartmentChanged;
  final Function(String?) onPlaceChanged;
  final Function(String?) onNatureOfWorkChanged;
  final Function(String?) onProblemTitleChanged;
  final Function(String?) onModelNumberChanged;
  final Function(PriorityType) onPriorityChanged;
  final Function(bool) onUseCustomProblemChanged;
  final Function(bool) onUseCustomModelChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const PlacesMaintenanceTicketContent({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.locationController,
    required this.highPriorityController,
    required this.phoneController,
    required this.customProblemController,
    required this.customModelController,
    required this.selectedDepartmentId,
    required this.selectedPlaceId,
    required this.selectedNatureOfWorkId,
    required this.selectedProblemTitleId,
    required this.selectedModelNumberId,
    required this.selectedPriority,
    required this.departments,
    required this.places,
    required this.natureOfWorkList,
    required this.problemTitles,
    required this.parts,
    required this.selectedFiles,
    required this.useCustomProblem,
    required this.useCustomModel,
    required this.canSelectPlace,
    required this.onDepartmentChanged,
    required this.onPlaceChanged,
    required this.onNatureOfWorkChanged,
    required this.onProblemTitleChanged,
    required this.onModelNumberChanged,
    required this.onPriorityChanged,
    required this.onUseCustomProblemChanged,
    required this.onUseCustomModelChanged,
    required this.onPickImages,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  String _getPlaceName(
      String? placeId, List<PlaceModel> places, AppLocalizations l10n) {
    if (placeId == null) return l10n.unknown;
    try {
      return places.firstWhere((p) => p.id == placeId).name;
    } catch (e) {
      return l10n.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.titleRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: l10n.placesBriefDescription,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: l10n.descriptionRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: l10n.placesDetailedDescription,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 10),

        // Department Dropdown
        SearchableDropdown<String>(
          labelText: l10n.targetDepartmentRequired,
          hintText: l10n.selectDepartmentSubtask,
          value: selectedDepartmentId,
          items: departments
              .map((dept) => DropdownMenuItem(
                    value: dept.id,
                    child: Text(dept.localizedName(lang)),
                  ))
              .toList(),
          getLabel: (id) => departments.firstWhere((d) => d.id == id).localizedName(lang),
          onChanged: onDepartmentChanged,
        ),
        const SizedBox(height: 10),

        // Nature of Work Section
        if (selectedDepartmentId != null) ...[
          Text(
            l10n.natureOfWorkRequired,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (natureOfWorkList.isNotEmpty) ...[
            SearchableDropdown<String>(
              labelText: l10n.natureOfWork,
              hintText: l10n.selectNatureOfWork,
              value: selectedNatureOfWorkId,
              items: natureOfWorkList
                  .map((now) => DropdownMenuItem(
                        value: now.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(now.localizedName(lang)),
                            if (now.description != null)
                              Text(
                                now.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
              getLabel: (id) =>
                  natureOfWorkList.firstWhere((n) => n.id == id).localizedName(lang),
              onChanged: onNatureOfWorkChanged,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                l10n.noNatureWorkForDept,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        if (canSelectPlace) ...[
          SearchableDropdown<String>(
            labelText: '${l10n.place} *',
            hintText: l10n.selectPlace,
            value: selectedPlaceId,
            items: places
                .map((place) => DropdownMenuItem(
                      value: place.id,
                      child: Text(place.localizedName(lang)),
                    ))
                .toList(),
            getLabel: (id) {
              try {
                return places.firstWhere((p) => p.id == id).localizedName(lang);
              } catch (e) {
                return l10n.unknown; // Return 'Unknown' if place not found
              }
            },
            onChanged: onPlaceChanged,
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.placeInfo}: ${_getPlaceName(selectedPlaceId, places, l10n)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Specific Location
        TextField(
          controller: locationController,
          decoration: InputDecoration(
            labelText: l10n.specificLocation,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: l10n.specificLocationHint,
            prefixIcon: const Icon(Icons.location_on, color: Colors.green),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Problem Title Section
        if (problemTitles.isEmpty || useCustomProblem) ...[
          TextField(
            controller: customProblemController,
            decoration: InputDecoration(
              labelText: '${l10n.problemTitle} *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.describeProblem,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
              suffixIcon: useCustomProblem
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => onUseCustomProblemChanged(false),
                    )
                  : null,
            ),
          ),
        ] else ...[
          SearchableDropdown<String>(
            labelText: '${l10n.problemTitle} *',
            hintText: l10n.selectProblemType,
            value: selectedProblemTitleId,
            items: problemTitles
                .map((problem) => DropdownMenuItem(
                      value: problem['id'] as String,
                      child: Text(problem['title'] as String),
                    ))
                .toList(),
            getLabel: (id) =>
                problemTitles.firstWhere((p) => p['id'] == id)['title'],
            showOtherOption: true,
            onOtherSelected: () => onUseCustomProblemChanged(true),
            onChanged: onProblemTitleChanged,
          ),
        ],
        const SizedBox(height: 10),

        // Priority Dropdown
        DropdownButtonFormField<PriorityType>(
          value: selectedPriority,
          decoration: InputDecoration(
            labelText: l10n.priorityRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          items: PriorityType.values.map((priority) {
            return DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Icon(
                    priority == PriorityType.urgent
                        ? Icons.emergency
                        : priority == PriorityType.high
                            ? Icons.priority_high
                            : priority == PriorityType.medium
                                ? Icons.remove
                                : Icons.low_priority,
                    color: priority == PriorityType.urgent
                        ? Colors.purple
                        : priority == PriorityType.high
                            ? Colors.red
                            : priority == PriorityType.medium
                                ? Colors.orange
                                : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_getPriorityText(priority, l10n).toUpperCase(),
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onPriorityChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),

        // High Priority Explanation
        if (selectedPriority == PriorityType.high ||
            selectedPriority == PriorityType.urgent) ...[
          TextField(
            controller: highPriorityController,
            decoration: InputDecoration(
              labelText: l10n.highPriorityExplanationRequired,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: l10n.explainHighUrgentPriority,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
        ],

        // Model Number Section
        if (parts.isNotEmpty) ...[
          Text(
            l10n.modelNumberOptional,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: useCustomModel,
                onChanged: (value) => onUseCustomModelChanged(value ?? false),
                activeColor: Colors.green,
              ),
              Text(l10n.enterCustomModel, style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          if (useCustomModel) ...[
            TextField(
              controller: customModelController,
              decoration: InputDecoration(
                labelText: l10n.customModelNumber,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: l10n.enterModelNumber,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
                ),
              ),
            ),
          ] else ...[
            SearchableDropdown<String>(
              labelText: l10n.modelNumber,
              hintText: l10n.selectDevicePart,
              value: selectedModelNumberId,
              items: parts
                  .map((part) => DropdownMenuItem(
                        value: part['id'] as String,
                        child: Text(
                          '${part['model_number']} - ${part['name']}',
                        ),
                      ))
                  .toList(),
              getLabel: (id) {
                final part = parts.firstWhere((p) => p['id'] == id);
                return '${part['model_number']} - ${part['name']}';
              },
              onChanged: onModelNumberChanged,
            ),
          ],
          const SizedBox(height: 10),
        ],

        // File Attachments Section
        _buildFileAttachmentSection(
          selectedFiles,
          onPickImages,
          onPickFiles,
          onRemoveFile,
          l10n,
        ),
        const SizedBox(height: 10),

        // Information Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.placesTicketInfo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• ${l10n.fillRequiredFields}\n'
                '• ${l10n.provideAccurateLocation}\n'
                '• ${l10n.addPhotosIfPossible}\n'
                '• ${l10n.notifiedWhenWorkBegins}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  Widget _buildFileAttachmentSection(
    List<PlatformFile> files,
    VoidCallback pickImages,
    VoidCallback pickFiles,
    Function(int) removeFile,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachmentsSection,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: pickImages,
              icon: const Icon(Icons.image, size: 18, color: Colors.green),
              label: Text(l10n.images,
                  style: const TextStyle(color: Colors.green)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            TextButton.icon(
              onPressed: pickFiles,
              icon:
                  const Icon(Icons.attach_file, size: 18, color: Colors.green),
              label:
                  Text(l10n.files, style: const TextStyle(color: Colors.green)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (files.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(file.bytes!,
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${files.length} ${files.length != 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
// ADD this new file: individuals_maintenance_ticket_screen.dart

class IndividualsMaintenanceTicketScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;

  const IndividualsMaintenanceTicketScreen({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });

  @override
  State<IndividualsMaintenanceTicketScreen> createState() =>
      _IndividualsMaintenanceTicketScreenState();
}

class _IndividualsMaintenanceTicketScreenState
    extends State<IndividualsMaintenanceTicketScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customProblemController = TextEditingController();
  final _customModelController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedNatureOfWorkId;
  String? _selectedProblemTitleId;
  String? _selectedModelNumberId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];
  List<Map<String, dynamic>> _problemTitles = [];
  List<Map<String, dynamic>> _parts = [];

  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _useCustomProblem = false;
  bool _useCustomModel = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadProblemTitles(String departmentId) async {
    try {
      final response = await supabase
          .from('problem_titles')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _problemTitles = response;
        _selectedProblemTitleId = null;
      });
    } catch (e) {
      print('Error loading problem titles: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
        _selectedModelNumberId = null;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.individualsMaintenanceTicket,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: IndividualsMaintenanceTicketContent(
                titleController: _titleController,
                descriptionController: _descriptionController,
                locationController: _locationController,
                highPriorityController: _highPriorityController,
                phoneController: _phoneController,
                customProblemController: _customProblemController,
                customModelController: _customModelController,
                selectedDepartmentId: _selectedDepartmentId,
                selectedNatureOfWorkId: _selectedNatureOfWorkId,
                selectedProblemTitleId: _selectedProblemTitleId,
                selectedModelNumberId: _selectedModelNumberId,
                selectedPriority: _selectedPriority,
                departments: _departments,
                natureOfWorkList: _natureOfWorkList,
                problemTitles: _problemTitles,
                parts: _parts,
                selectedFiles: _selectedFiles,
                useCustomProblem: _useCustomProblem,
                useCustomModel: _useCustomModel,
                onDepartmentChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedNatureOfWorkId = null;
                    _selectedProblemTitleId = null;
                    _selectedModelNumberId = null;
                    _natureOfWorkList.clear();
                    _problemTitles.clear();
                    _parts.clear();
                  });
                  if (value != null) {
                    _loadNatureOfWorkForDepartment(value);
                    _loadProblemTitles(value);
                    _loadParts(value);
                  }
                },
                onNatureOfWorkChanged: (value) {
                  setState(() => _selectedNatureOfWorkId = value);
                },
                onProblemTitleChanged: (value) {
                  setState(() => _selectedProblemTitleId = value);
                },
                onModelNumberChanged: (value) {
                  setState(() => _selectedModelNumberId = value);
                },
                onPriorityChanged: (value) {
                  setState(() => _selectedPriority = value);
                },
                onUseCustomProblemChanged: (value) {
                  setState(() {
                    _useCustomProblem = value;
                    if (_useCustomProblem) {
                      _selectedProblemTitleId = null;
                    } else {
                      _customProblemController.clear();
                    }
                  });
                },
                onUseCustomModelChanged: (value) {
                  setState(() {
                    _useCustomModel = value;
                    if (_useCustomModel) {
                      _selectedModelNumberId = null;
                    } else {
                      _customModelController.clear();
                    }
                  });
                },
                onPickImages: _pickImages,
                onPickFiles: _pickFiles,
                onRemoveFile: _removeFile,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : _createTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isUploadingFiles)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isUploadingFiles
                                    ? l10n.uploading + '...'
                                    : l10n.creating + '...',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.createTicket,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    // Basic validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.title}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.description}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${l10n.pleaseFillAllRequired} - ${l10n.targetDepartment}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Nature of Work validation - only if list is NOT empty
    if (_natureOfWorkList.isNotEmpty && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.natureOfWork}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // High priority validation
    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseExplainHighPriority),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Phone validation
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Problem title validation - Only if problemTitles exist
    if (_problemTitles.isNotEmpty) {
      if (!_useCustomProblem && _selectedProblemTitleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseSelectProblemOrCustom),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_useCustomProblem && _customProblemController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseEnterCustomProblem),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        // AUTO-SET: If nature of work list is empty, send "Other", otherwise send selected
        'nature_of_work_id':
            _natureOfWorkList.isNotEmpty ? _selectedNatureOfWorkId : null,
        'other_nature_of_work': _natureOfWorkList.isEmpty ? 'Other' : null,
        'other_place': 'Other',
        'location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        // AUTO-SET: If problem titles list is empty, send "Other", otherwise send selected/custom
        'problem_title_id': (_problemTitles.isNotEmpty && !_useCustomProblem)
            ? _selectedProblemTitleId
            : null,
        'other_problem_title': _problemTitles.isEmpty
            ? 'Other'
            : (_useCustomProblem ? _customProblemController.text.trim() : null),
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        // AUTO-SET: If parts list is empty, send "Other", otherwise send selected/custom
        'model_number_id': (_parts.isNotEmpty && !_useCustomModel)
            ? _selectedModelNumberId
            : null,
        'other_model_number': _parts.isEmpty
            ? 'Other'
            : (_useCustomModel ? _customModelController.text.trim() : null),
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      print('📋 Creating individuals ticket with data: $ticketData');

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.individualsMaintenanceTicket} #$ticketNumber ${l10n.subticketCreatedSuccessfully}$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating individuals ticket: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    _customProblemController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}

// IndividualsMaintenanceTicketContent - Full Updated Method
class IndividualsMaintenanceTicketContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TextEditingController highPriorityController;
  final TextEditingController phoneController;
  final TextEditingController customProblemController;
  final TextEditingController customModelController;
  final String? selectedDepartmentId;
  final String? selectedNatureOfWorkId;
  final String? selectedProblemTitleId;
  final String? selectedModelNumberId;
  final PriorityType selectedPriority;
  final List<DepartmentModel> departments;
  final List<NatureOfWorkModel> natureOfWorkList;
  final List<Map<String, dynamic>> problemTitles;
  final List<Map<String, dynamic>> parts;
  final List<PlatformFile> selectedFiles;
  final bool useCustomProblem;
  final bool useCustomModel;
  final Function(String?) onDepartmentChanged;
  final Function(String?) onNatureOfWorkChanged;
  final Function(String?) onProblemTitleChanged;
  final Function(String?) onModelNumberChanged;
  final Function(PriorityType) onPriorityChanged;
  final Function(bool) onUseCustomProblemChanged;
  final Function(bool) onUseCustomModelChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const IndividualsMaintenanceTicketContent({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.locationController,
    required this.highPriorityController,
    required this.phoneController,
    required this.customProblemController,
    required this.customModelController,
    required this.selectedDepartmentId,
    required this.selectedNatureOfWorkId,
    required this.selectedProblemTitleId,
    required this.selectedModelNumberId,
    required this.selectedPriority,
    required this.departments,
    required this.natureOfWorkList,
    required this.problemTitles,
    required this.parts,
    required this.selectedFiles,
    required this.useCustomProblem,
    required this.useCustomModel,
    required this.onDepartmentChanged,
    required this.onNatureOfWorkChanged,
    required this.onProblemTitleChanged,
    required this.onModelNumberChanged,
    required this.onPriorityChanged,
    required this.onUseCustomProblemChanged,
    required this.onUseCustomModelChanged,
    required this.onPickImages,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.titleRequired,
            hintText: l10n.individualsBriefDescription,
            filled: true,
            fillColor: Colors.grey.shade50,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: l10n.descriptionRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: l10n.individualsDetailedDescription,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 10),

        // Department Dropdown
        SearchableDropdown<String>(
          labelText: l10n.targetDepartmentRequired,
          hintText: l10n.selectDepartmentSubtask,
          value: selectedDepartmentId,
          items: departments
              .map((dept) => DropdownMenuItem(
                    value: dept.id,
                    child: Text(dept.localizedName(lang)),
                  ))
              .toList(),
          getLabel: (id) => departments.firstWhere((d) => d.id == id).localizedName(lang),
          onChanged: onDepartmentChanged,
        ),
        const SizedBox(height: 10),

        // Nature of Work Section
        if (selectedDepartmentId != null) ...[
          Text(
            l10n.natureOfWorkRequired,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (natureOfWorkList.isNotEmpty) ...[
            SearchableDropdown<String>(
              labelText: l10n.natureOfWork,
              hintText: l10n.selectNatureOfWork,
              value: selectedNatureOfWorkId,
              items: natureOfWorkList
                  .map((now) => DropdownMenuItem(
                        value: now.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(now.localizedName(lang)),
                            if (now.description != null)
                              Text(
                                now.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
              getLabel: (id) =>
                  natureOfWorkList.firstWhere((n) => n.id == id).localizedName(lang),
              onChanged: onNatureOfWorkChanged,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                l10n.noNatureWorkForDept,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        // Place Info (Read-only - always "Other")
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.placeIndividualInfo,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Specific Location (Optional)
        TextField(
          controller: locationController,
          decoration: InputDecoration(
            labelText: l10n.specificLocationOptional,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: l10n.whereIndividualLocated,
            prefixIcon: const Icon(Icons.location_on, color: Colors.purple),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Problem Title Section
        if (problemTitles.isEmpty || useCustomProblem) ...[
          TextField(
            controller: customProblemController,
            decoration: InputDecoration(
              labelText: '${l10n.problemTitle} *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: l10n.describeProblem,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
              suffixIcon: useCustomProblem
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => onUseCustomProblemChanged(false),
                    )
                  : null,
            ),
          ),
        ] else ...[
          SearchableDropdown<String>(
            labelText: '${l10n.problemTitle} *',
            hintText: l10n.selectProblemType,
            value: selectedProblemTitleId,
            items: problemTitles
                .map((problem) => DropdownMenuItem(
                      value: problem['id'] as String,
                      child: Text(problem['title'] as String),
                    ))
                .toList(),
            getLabel: (id) =>
                problemTitles.firstWhere((p) => p['id'] == id)['title'],
            showOtherOption: true,
            onOtherSelected: () => onUseCustomProblemChanged(true),
            onChanged: onProblemTitleChanged,
          ),
        ],
        const SizedBox(height: 10),

        // Priority Dropdown
        DropdownButtonFormField<PriorityType>(
          value: selectedPriority,
          decoration: InputDecoration(
            labelText: l10n.priorityRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          items: PriorityType.values.map((priority) {
            return DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Icon(
                    priority == PriorityType.urgent
                        ? Icons.emergency
                        : priority == PriorityType.high
                            ? Icons.priority_high
                            : priority == PriorityType.medium
                                ? Icons.remove
                                : Icons.low_priority,
                    color: priority == PriorityType.urgent
                        ? Colors.purple
                        : priority == PriorityType.high
                            ? Colors.red
                            : priority == PriorityType.medium
                                ? Colors.orange
                                : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_getPriorityText(priority, l10n).toUpperCase(),
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onPriorityChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),

        // High Priority Explanation
        if (selectedPriority == PriorityType.high ||
            selectedPriority == PriorityType.urgent) ...[
          TextField(
            controller: highPriorityController,
            decoration: InputDecoration(
              labelText: l10n.highPriorityExplanationRequired,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: l10n.explainHighUrgentPriority,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
        ],

        // Model Number Section
        if (parts.isNotEmpty) ...[
          Text(
            l10n.modelNumberOptional,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: useCustomModel,
                onChanged: (value) => onUseCustomModelChanged(value ?? false),
                activeColor: Colors.purple,
              ),
              Text(l10n.enterCustomModel, style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          if (useCustomModel) ...[
            TextField(
              controller: customModelController,
              decoration: InputDecoration(
                labelText: l10n.customModelNumber,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: l10n.enterModelNumber,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
                ),
              ),
            ),
          ] else ...[
            SearchableDropdown<String>(
              labelText: l10n.modelNumber,
              hintText: l10n.selectDevicePart,
              value: selectedModelNumberId,
              items: parts
                  .map((part) => DropdownMenuItem(
                        value: part['id'] as String,
                        child: Text(
                          '${part['model_number']} - ${part['name']}',
                        ),
                      ))
                  .toList(),
              getLabel: (id) {
                final part = parts.firstWhere((p) => p['id'] == id);
                return '${part['model_number']} - ${part['name']}';
              },
              onChanged: onModelNumberChanged,
            ),
          ],
          const SizedBox(height: 10),
        ],

        // File Attachments Section
        _buildFileAttachmentSection(
          selectedFiles,
          onPickImages,
          onPickFiles,
          onRemoveFile,
          l10n,
        ),
        const SizedBox(height: 10),

        // Information Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.purple, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.individualsTicketInfo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• ${l10n.forIssuesRelatedIndividuals}\n'
                '• ${l10n.fillRequiredFields}\n'
                '• ${l10n.addPhotosDocuments}\n'
                '• ${l10n.trackTicketStatus}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  Widget _buildFileAttachmentSection(
    List<PlatformFile> files,
    VoidCallback pickImages,
    VoidCallback pickFiles,
    Function(int) removeFile,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachmentsSection,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: pickImages,
              icon: const Icon(Icons.image, size: 18, color: Colors.purple),
              label: Text(l10n.images,
                  style: const TextStyle(color: Colors.purple)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            TextButton.icon(
              onPressed: pickFiles,
              icon:
                  const Icon(Icons.attach_file, size: 18, color: Colors.purple),
              label: Text(l10n.files,
                  style: const TextStyle(color: Colors.purple)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (files.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(file.bytes!,
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${files.length} ${files.length != 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class RequestsTicketScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;

  const RequestsTicketScreen({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
  });

  @override
  State<RequestsTicketScreen> createState() => _RequestsTicketScreenState();
}

class _RequestsTicketScreenState extends State<RequestsTicketScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customModelController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedNatureOfWorkId;
  String? _selectedModelNumberId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];
  List<Map<String, dynamic>> _parts = [];

  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;
  bool _useCustomModel = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
        _selectedModelNumberId = null;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.requestsTicket,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RequestsTicketContent(
                titleController: _titleController,
                descriptionController: _descriptionController,
                locationController: _locationController,
                highPriorityController: _highPriorityController,
                phoneController: _phoneController,
                customModelController: _customModelController,
                selectedDepartmentId: _selectedDepartmentId,
                selectedNatureOfWorkId: _selectedNatureOfWorkId,
                selectedModelNumberId: _selectedModelNumberId,
                selectedPriority: _selectedPriority,
                departments: _departments,
                natureOfWorkList: _natureOfWorkList,
                parts: _parts,
                selectedFiles: _selectedFiles,
                useCustomModel: _useCustomModel,
                onDepartmentChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedNatureOfWorkId = null;
                    _selectedModelNumberId = null;
                    _natureOfWorkList.clear();
                    _parts.clear();
                  });
                  if (value != null) {
                    _loadNatureOfWorkForDepartment(value);
                    _loadParts(value);
                  }
                },
                onNatureOfWorkChanged: (value) {
                  setState(() => _selectedNatureOfWorkId = value);
                },
                onModelNumberChanged: (value) {
                  setState(() => _selectedModelNumberId = value);
                },
                onPriorityChanged: (value) {
                  setState(() => _selectedPriority = value);
                },
                onUseCustomModelChanged: (value) {
                  setState(() {
                    _useCustomModel = value;
                    if (_useCustomModel) {
                      _selectedModelNumberId = null;
                    } else {
                      _customModelController.clear();
                    }
                  });
                },
                onPickImages: _pickImages,
                onPickFiles: _pickFiles,
                onRemoveFile: _removeFile,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : _createTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isUploadingFiles)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isUploadingFiles
                                    ? l10n.uploading + '...'
                                    : l10n.creating + '...',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.createRequest,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    // Basic required fields validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.title}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.description}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${l10n.pleaseFillAllRequired} - ${l10n.targetDepartment}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Nature of work validation - only if list is not empty
    if (_natureOfWorkList.isNotEmpty && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.pleaseFillAllRequired} - ${l10n.natureOfWork}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // High priority explanation validation
    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseExplainHighPriority),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Phone number validation
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,

        // Nature of Work - auto-set "Other" if list empty
        'nature_of_work_id':
            _natureOfWorkList.isNotEmpty ? _selectedNatureOfWorkId : null,
        'other_nature_of_work': _natureOfWorkList.isEmpty ? 'Other' : null,

        'other_place': 'Other',
        'location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        'other_problem_title': 'Other',
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,

        // Model Number - auto-set "Other" if list empty
        'model_number_id': (_parts.isNotEmpty && !_useCustomModel)
            ? _selectedModelNumberId
            : null,
        'other_model_number': _parts.isEmpty
            ? 'Other'
            : (_useCustomModel ? _customModelController.text.trim() : null),

        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      print('📋 Creating request ticket with data: $ticketData');

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.requestsTicket} #$ticketNumber ${l10n.subticketCreatedSuccessfully}$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating request ticket: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedCreateTicket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}

// RequestsTicketContent - Full Updated Method
class RequestsTicketContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TextEditingController highPriorityController;
  final TextEditingController phoneController;
  final TextEditingController customModelController;
  final String? selectedDepartmentId;
  final String? selectedNatureOfWorkId;
  final String? selectedModelNumberId;
  final PriorityType selectedPriority;
  final List<DepartmentModel> departments;
  final List<NatureOfWorkModel> natureOfWorkList;
  final List<Map<String, dynamic>> parts;
  final List<PlatformFile> selectedFiles;
  final bool useCustomModel;
  final Function(String?) onDepartmentChanged;
  final Function(String?) onNatureOfWorkChanged;
  final Function(String?) onModelNumberChanged;
  final Function(PriorityType) onPriorityChanged;
  final Function(bool) onUseCustomModelChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const RequestsTicketContent({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.locationController,
    required this.highPriorityController,
    required this.phoneController,
    required this.customModelController,
    required this.selectedDepartmentId,
    required this.selectedNatureOfWorkId,
    required this.selectedModelNumberId,
    required this.selectedPriority,
    required this.departments,
    required this.natureOfWorkList,
    required this.parts,
    required this.selectedFiles,
    required this.useCustomModel,
    required this.onDepartmentChanged,
    required this.onNatureOfWorkChanged,
    required this.onModelNumberChanged,
    required this.onPriorityChanged,
    required this.onUseCustomModelChanged,
    required this.onPickImages,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.requestTitle,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: l10n.whatAreYouRequesting,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: l10n.requestDescription,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: l10n.detailedRequestDescription,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 10),

        // Department Dropdown
        SearchableDropdown<String>(
          labelText: l10n.targetDepartmentRequired,
          hintText: l10n.selectDepartmentHandleRequest,
          value: selectedDepartmentId,
          items: departments
              .map((dept) => DropdownMenuItem(
                    value: dept.id,
                    child: Text(dept.localizedName(lang)),
                  ))
              .toList(),
          getLabel: (id) => departments.firstWhere((d) => d.id == id).localizedName(lang),
          onChanged: onDepartmentChanged,
        ),
        const SizedBox(height: 10),

        // Nature of Work Section
        if (selectedDepartmentId != null) ...[
          Text(
            l10n.natureOfWorkRequired,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (natureOfWorkList.isNotEmpty) ...[
            SearchableDropdown<String>(
              labelText: l10n.natureOfWork,
              hintText: l10n.selectNatureOfWork,
              value: selectedNatureOfWorkId,
              items: natureOfWorkList
                  .map((now) => DropdownMenuItem(
                        value: now.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(now.localizedName(lang)),
                            if (now.description != null)
                              Text(
                                now.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
              getLabel: (id) =>
                  natureOfWorkList.firstWhere((n) => n.id == id).localizedName(lang),
              onChanged: onNatureOfWorkChanged,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                l10n.noNatureWorkForDept,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],

        // Specific Location (Optional)
        TextField(
          controller: locationController,
          decoration: InputDecoration(
            labelText: l10n.specificLocationOptional,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: l10n.whereItemsDelivered,
            prefixIcon: const Icon(Icons.location_on, color: Colors.teal),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Priority Dropdown
        DropdownButtonFormField<PriorityType>(
          value: selectedPriority,
          decoration: InputDecoration(
            labelText: l10n.priorityRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          items: PriorityType.values.map((priority) {
            return DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Icon(
                    priority == PriorityType.urgent
                        ? Icons.emergency
                        : priority == PriorityType.high
                            ? Icons.priority_high
                            : priority == PriorityType.medium
                                ? Icons.remove
                                : Icons.low_priority,
                    color: priority == PriorityType.urgent
                        ? Colors.purple
                        : priority == PriorityType.high
                            ? Colors.red
                            : priority == PriorityType.medium
                                ? Colors.orange
                                : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_getPriorityText(priority, l10n).toUpperCase(),
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onPriorityChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),

        // High Priority Explanation
        if (selectedPriority == PriorityType.high ||
            selectedPriority == PriorityType.urgent) ...[
          TextField(
            controller: highPriorityController,
            decoration: InputDecoration(
              labelText: l10n.highPriorityExplanationRequired,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: l10n.explainHighUrgentPriority,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
        ],

        // Model Number Section
        if (parts.isNotEmpty) ...[
          Text(
            l10n.modelNumberOptional,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: useCustomModel,
                onChanged: (value) => onUseCustomModelChanged(value ?? false),
                activeColor: Colors.teal,
              ),
              Text(l10n.enterCustomModel, style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          if (useCustomModel) ...[
            TextField(
              controller: customModelController,
              decoration: InputDecoration(
                labelText: l10n.customModelNumber,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: l10n.enterModelNumber,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
                ),
              ),
            ),
          ] else ...[
            SearchableDropdown<String>(
              labelText: l10n.modelNumber,
              hintText: l10n.selectDevicePart,
              value: selectedModelNumberId,
              items: parts
                  .map((part) => DropdownMenuItem(
                        value: part['id'] as String,
                        child: Text(
                          '${part['model_number']} - ${part['name']}',
                        ),
                      ))
                  .toList(),
              getLabel: (id) {
                final part = parts.firstWhere((p) => p['id'] == id);
                return '${part['model_number']} - ${part['name']}';
              },
              onChanged: onModelNumberChanged,
            ),
          ],
          const SizedBox(height: 10),
        ],

        // File Attachments Section
        _buildFileAttachmentSection(
          selectedFiles,
          onPickImages,
          onPickFiles,
          onRemoveFile,
          l10n,
        ),
        const SizedBox(height: 10),

        // Information Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.teal, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.requestsTicketInfo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• ${l10n.useForRequestingItems}\n'
                '• ${l10n.commonlyUsedInterDept}\n'
                '• ${l10n.canBeUsedSubtickets}\n'
                '• ${l10n.trackRequestStatus}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  Widget _buildFileAttachmentSection(
    List<PlatformFile> files,
    VoidCallback pickImages,
    VoidCallback pickFiles,
    Function(int) removeFile,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachmentsSection,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: pickImages,
              icon: const Icon(Icons.image, size: 18, color: Colors.teal),
              label:
                  Text(l10n.images, style: const TextStyle(color: Colors.teal)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            TextButton.icon(
              onPressed: pickFiles,
              icon: const Icon(Icons.attach_file, size: 18, color: Colors.teal),
              label:
                  Text(l10n.files, style: const TextStyle(color: Colors.teal)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (files.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(file.bytes!,
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${files.length} ${files.length != 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class CreateTicketScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onTicketCreated;
  final TicketModel? prefillFromTicket;

  const CreateTicketScreen({
    super.key,
    required this.currentUser,
    required this.onTicketCreated,
    this.prefillFromTicket,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _customProblemController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _customModelController = TextEditingController();
  final _otherNatureOfWorkController = TextEditingController();
  final _otherPlaceController = TextEditingController();
  final _otherProblemTitleController = TextEditingController();
  final _otherModelNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedPlaceId;
  String? _selectedProblemTitleId;
  String? _selectedModelNumberId;
  String? _selectedNatureOfWorkId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<PlaceModel> _places = [];
  List<Map<String, dynamic>> _problemTitles = [];
  List<Map<String, dynamic>> _parts = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];

  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _useOtherNatureOfWork = false;
  bool _useOtherPlace = false;
  bool _useOtherProblemTitle = false;
  bool _useOtherModelNumber = false;
  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _selectedPlaceId = widget.currentUser.placeId;
    _initializeDialog();
  }

  Future<void> _initializeDialog() async {
    await _loadData();

    if (widget.prefillFromTicket != null) {
      await _prefillFromWrongInfoTicket();
    }

    setState(() {
      _isLoadingData = false;
    });
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();
      final placesResponse = await supabase.from('places').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
        _places = placesResponse
            .map<PlaceModel>((json) => PlaceModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
        _useOtherNatureOfWork = false;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _loadProblemTitles(String departmentId) async {
    try {
      final response = await supabase
          .from('problem_titles')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _problemTitles = response;
      });
    } catch (e) {
      print('Error loading problem titles: $e');
    }
  }

  Future<void> _loadParts(String departmentId) async {
    try {
      final response = await supabase
          .from('parts')
          .select()
          .eq('department_id', departmentId);
      setState(() {
        _parts = response;
      });
    } catch (e) {
      print('Error loading parts: $e');
    }
  }

  Future<void> _prefillFromWrongInfoTicket() async {
    final ticket = widget.prefillFromTicket!;

    _titleController.text = ticket.title;
    _descriptionController.text = ticket.description;
    _locationController.text = ticket.location ?? '';
    _selectedDepartmentId = ticket.targetDepartmentId;
    _selectedPlaceId = ticket.placeId;
    _selectedPriority = ticket.priority;
    _highPriorityController.text = ticket.highPriorityExplain ?? '';
    _customModelController.text = ticket.customModelNumber ?? '';
    _customProblemController.text = ticket.customProblemTitle ?? '';

    if (ticket.customProblemTitle != null) {
      _useOtherProblemTitle = true;
    }
    if (ticket.customModelNumber != null) {
      _useOtherModelNumber = true;
    }

    if (_selectedDepartmentId != null) {
      await _loadProblemTitles(_selectedDepartmentId!);
      await _loadParts(_selectedDepartmentId!);
      await _loadNatureOfWorkForDepartment(_selectedDepartmentId!);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowedExtensions: null,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      print('Error picking files: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      if (mounted) {
        final l10n = AppLocalizations.safeOf(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      print('Error uploading files: $e');
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTicket() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDepartmentId == null ||
        (_selectedPlaceId == null && !_useOtherPlace)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if (!_useOtherNatureOfWork && _selectedNatureOfWorkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectNatureOfWork)),
      );
      return;
    }

    if (_useOtherNatureOfWork &&
        _otherNatureOfWorkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSpecifyOtherNatureOfWork)),
      );
      return;
    }

    if (_useOtherPlace && _otherPlaceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSpecifyOtherPlace)),
      );
      return;
    }

    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        'place_id': _useOtherPlace ? null : _selectedPlaceId,
        'other_place':
            _useOtherPlace ? _otherPlaceController.text.trim() : null,
        'location': _locationController.text.isNotEmpty
            ? _locationController.text.trim()
            : null,
        'nature_of_work_id':
            _useOtherNatureOfWork ? null : _selectedNatureOfWorkId,
        'other_nature_of_work': _useOtherNatureOfWork
            ? _otherNatureOfWorkController.text.trim()
            : null,
        'problem_title_id':
            _useOtherProblemTitle ? null : _selectedProblemTitleId,
        'other_problem_title': _useOtherProblemTitle
            ? _otherProblemTitleController.text.trim()
            : null,
        'custom_problem_title': null,
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'model_number_id': _useOtherModelNumber ? null : _selectedModelNumberId,
        'other_model_number': _useOtherModelNumber
            ? _otherModelNumberController.text.trim()
            : null,
        'custom_model_number': null,
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created ticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onTicketCreated();

        final successMessage = _selectedFiles.isNotEmpty
            ? '${l10n.ticket} #$ticketNumber ${l10n.ticketCreatedSuccessfullyWith} ${_selectedFiles.length} ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}'
            : '${l10n.ticket} #$ticketNumber ${l10n.ticketCreatedSuccessfully}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedCreateTicket}: $e')),
        );
      }
      print('Error creating ticket: $e');
    }
  }

  Widget _buildFileAttachmentSection() {
    final l10n = AppLocalizations.safeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachmentsSection,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image),
              label: Text(l10n.images),
            ),
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.files),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFiles.isNotEmpty) ...[
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(
                                        file.bytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedFiles.length} ${_selectedFiles.length != 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.prefillFromTicket != null
                ? l10n.createCorrectedTicket
                : l10n.createNewTicket,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.loading,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.prefillFromTicket != null
              ? l10n.createCorrectedTicket
              : l10n.createNewTicket,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.prefillFromTicket != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${l10n.creatingCorrectedTicketFrom} ${widget.prefillFromTicket!.ticketNumber}. ${l10n.pleaseReviewAndUpdate}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: l10n.titleRequired,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: l10n.briefDescriptionSubtask,
                      contentPadding: const EdgeInsets.all(12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.descriptionRequired,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: l10n.detailedDescriptionTodo,
                      contentPadding: const EdgeInsets.all(12),
                      isDense: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),

                  // Phone Number
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumberRequired,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: l10n.contactPhoneNumber,
                      prefixIcon: const Icon(Icons.phone),
                      contentPadding: const EdgeInsets.all(12),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Department Dropdown with Search
                  SearchableDropdown<String>(
                    labelText: l10n.targetDepartmentRequired,
                    hintText: l10n.selectDepartmentSubtask,
                    value: _selectedDepartmentId,
                    items: _departments
                        .map((dept) => DropdownMenuItem(
                              value: dept.id,
                              child: Text(dept.localizedName(lang)),
                            ))
                        .toList(),
                    getLabel: (id) {
                      try {
                        return _departments.firstWhere((d) => d.id == id).localizedName(lang);
                      } catch (e) {
                        return l10n.unknown;
                      }
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedDepartmentId = value;
                        _selectedProblemTitleId = null;
                        _selectedModelNumberId = null;
                        _selectedNatureOfWorkId = null;
                        _problemTitles.clear();
                        _parts.clear();
                        _natureOfWorkList.clear();
                      });
                      if (value != null) {
                        _loadProblemTitles(value);
                        _loadParts(value);
                        _loadNatureOfWorkForDepartment(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nature of Work Section
                  if (_selectedDepartmentId != null) ...[
                    Text(
                      l10n.natureOfWorkRequired,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_useOtherNatureOfWork) ...[
                      TextField(
                        controller: _otherNatureOfWorkController,
                        decoration: InputDecoration(
                          labelText: l10n.specifyNatureOfWork,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: l10n.describeNatureOfWork,
                          contentPadding: const EdgeInsets.all(12),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _useOtherNatureOfWork = false;
                                _otherNatureOfWorkController.clear();
                              });
                            },
                          ),
                        ),
                      ),
                    ] else if (_natureOfWorkList.isNotEmpty) ...[
                      SearchableDropdown<String>(
                        labelText: l10n.natureOfWork,
                        hintText: l10n.selectNatureOfWork,
                        value: _selectedNatureOfWorkId,
                        items: _natureOfWorkList
                            .map((now) => DropdownMenuItem(
                                  value: now.id,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(now.localizedName(lang)),
                                      if (now.description != null)
                                        Text(
                                          now.description!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        getLabel: (id) {
                          try {
                            return _natureOfWorkList
                                .firstWhere((n) => n.id == id)
                                .localizedName(lang);
                          } catch (e) {
                            return l10n.unknown;
                          }
                        },
                        showOtherOption: true,
                        onOtherSelected: () {
                          setState(() {
                            _useOtherNatureOfWork = true;
                            _selectedNatureOfWorkId = null;
                          });
                        },
                        onChanged: (value) {
                          setState(() => _selectedNatureOfWorkId = value);
                        },
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.noNatureWorkAvailableClickBelow,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _useOtherNatureOfWork = true;
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.specifyOther),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Place Dropdown with Search and Other Option
                  if (_useOtherPlace) ...[
                    TextField(
                      controller: _otherPlaceController,
                      decoration: InputDecoration(
                        labelText: l10n.specifyPlace,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: l10n.enterPlaceName,
                        contentPadding: const EdgeInsets.all(12),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _useOtherPlace = false;
                              _otherPlaceController.clear();
                            });
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    SearchableDropdown<String>(
                      labelText: '${l10n.place} *',
                      hintText: l10n.selectPlace,
                      value: _selectedPlaceId,
                      items: _places
                          .map((place) => DropdownMenuItem(
                                value: place.id,
                                child: Text(place.localizedName(lang)),
                              ))
                          .toList(),
                      getLabel: (id) {
                        try {
                          return _places.firstWhere((p) => p.id == id).localizedName(lang);
                        } catch (e) {
                          return l10n.unknown;
                        }
                      },
                      showOtherOption: true,
                      onOtherSelected: () {
                        setState(() {
                          _useOtherPlace = true;
                          _selectedPlaceId = null;
                        });
                      },
                      onChanged: (value) {
                        setState(() => _selectedPlaceId = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Specific Location
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: l10n.specificLocation,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: l10n.specificLocationHint,
                      prefixIcon: const Icon(Icons.location_on),
                      contentPadding: const EdgeInsets.all(12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Problem Title with Search and Other Option
                  if (_problemTitles.isNotEmpty || _useOtherProblemTitle) ...[
                    Text(
                      l10n.problemTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_useOtherProblemTitle) ...[
                      TextField(
                        controller: _otherProblemTitleController,
                        decoration: InputDecoration(
                          labelText: l10n.specifyProblemTitle,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: l10n.describeProblem,
                          contentPadding: const EdgeInsets.all(12),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _useOtherProblemTitle = false;
                                _otherProblemTitleController.clear();
                              });
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      SearchableDropdown<String>(
                        labelText: l10n.problemTitle,
                        hintText: l10n.selectProblemType,
                        value: _selectedProblemTitleId,
                        items: _problemTitles
                            .map((problem) => DropdownMenuItem(
                                  value: problem['id'] as String,
                                  child: Text(problem['title'] as String),
                                ))
                            .toList(),
                        getLabel: (id) {
                          try {
                            return _problemTitles.firstWhere(
                                (p) => p['id'] == id)['title'] as String;
                          } catch (e) {
                            return l10n.unknown;
                          }
                        },
                        showOtherOption: true,
                        onOtherSelected: () {
                          setState(() {
                            _useOtherProblemTitle = true;
                            _selectedProblemTitleId = null;
                          });
                        },
                        onChanged: (value) {
                          setState(() => _selectedProblemTitleId = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Priority Dropdown
                  SearchableDropdown<PriorityType>(
                    labelText: l10n.priorityRequired,
                    value: _selectedPriority,
                    items: PriorityType.values
                        .map((priority) => DropdownMenuItem(
                              value: priority,
                              child: Row(
                                children: [
                                  Icon(
                                    priority == PriorityType.urgent
                                        ? Icons.emergency
                                        : priority == PriorityType.high
                                            ? Icons.priority_high
                                            : priority == PriorityType.medium
                                                ? Icons.remove
                                                : Icons.low_priority,
                                    color: priority == PriorityType.urgent
                                        ? Colors.purple
                                        : priority == PriorityType.high
                                            ? Colors.red
                                            : priority == PriorityType.medium
                                                ? Colors.orange
                                                : Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_getPriorityText(priority, l10n)
                                      .toUpperCase()),
                                ],
                              ),
                            ))
                        .toList(),
                    getLabel: (priority) =>
                        _getPriorityText(priority, l10n).toUpperCase(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPriority = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // High Priority Explanation
                  if (_selectedPriority == PriorityType.high ||
                      _selectedPriority == PriorityType.urgent) ...[
                    TextField(
                      controller: _highPriorityController,
                      decoration: InputDecoration(
                        labelText: l10n.highPriorityExplanationRequired,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: l10n.explainHighUrgentPriority,
                        contentPadding: const EdgeInsets.all(12),
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Model Number with Search and Other Option
                  if (_parts.isNotEmpty || _useOtherModelNumber) ...[
                    Text(
                      l10n.modelNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_useOtherModelNumber) ...[
                      TextField(
                        controller: _otherModelNumberController,
                        decoration: InputDecoration(
                          labelText: l10n.specifyModelNumber,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: l10n.enterModelNumber,
                          contentPadding: const EdgeInsets.all(12),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _useOtherModelNumber = false;
                                _otherModelNumberController.clear();
                              });
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      SearchableDropdown<String>(
                        labelText: l10n.modelNumber,
                        hintText: l10n.selectDevicePart,
                        value: _selectedModelNumberId,
                        items: _parts
                            .map((part) => DropdownMenuItem(
                                  value: part['id'] as String,
                                  child: Text(
                                    '${part['model_number']} - ${part['name']}',
                                  ),
                                ))
                            .toList(),
                        getLabel: (id) {
                          try {
                            final part =
                                _parts.firstWhere((p) => p['id'] == id);
                            return '${part['model_number']} - ${part['name']}';
                          } catch (e) {
                            return l10n.unknown;
                          }
                        },
                        showOtherOption: true,
                        onOtherSelected: () {
                          setState(() {
                            _useOtherModelNumber = true;
                            _selectedModelNumberId = null;
                          });
                        },
                        onChanged: (value) {
                          setState(() => _selectedModelNumberId = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // File Attachments Section
                  _buildFileAttachmentSection(),
                  const SizedBox(height: 16),

                  // Information Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info,
                                color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              l10n.ticketInformation,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${l10n.makeSureAllRequiredFieldsFilled}\n'
                          '• ${l10n.provideAccuratePhoneNumber}\n'
                          '• ${l10n.addDetailedDescription}\n'
                          '• ${l10n.attachRelevantImages}\n'
                          '• ${l10n.useOtherOptionIfNotInList}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : _createTicket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isUploadingFiles)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isUploadingFiles
                                    ? l10n.uploading
                                    : l10n.creating,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.createTicket,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _customProblemController.dispose();
    _highPriorityController.dispose();
    _customModelController.dispose();
    _otherNatureOfWorkController.dispose();
    _otherPlaceController.dispose();
    _otherProblemTitleController.dispose();
    _otherModelNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class CreateSubticketDialog extends StatefulWidget {
  final TicketModel parentTicket;
  final UserModel currentUser;
  final VoidCallback onSubticketCreated;

  const CreateSubticketDialog({
    super.key,
    required this.parentTicket,
    required this.currentUser,
    required this.onSubticketCreated,
  });

  @override
  State<CreateSubticketDialog> createState() => _CreateSubticketDialogState();
}

class _CreateSubticketDialogState extends State<CreateSubticketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedNatureOfWorkId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];

  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createSubticket() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDepartmentId == null ||
        (_selectedNatureOfWorkId == null && _natureOfWorkList.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        'nature_of_work_id': _selectedNatureOfWorkId,
        'parent_ticket_id': widget.parentTicket.id,
        if (widget.parentTicket.placeId != null)
          'place_id': widget.parentTicket.placeId,
        'other_place': 'Other',
        'other_problem_title': 'Other',
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'other_model_number': 'Other',
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created subticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      // Add activity log to parent ticket timeline
      try {
        await supabase.from('activity_logs').insert({
          'table_name': 'tickets',
          'record_id': widget.parentTicket.id,
          'action': 'subticket_created',
          'new_values': {
            'subticket_id': ticketId,
            'subticket_number': ticketNumber,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
          },
          'user_id': widget.currentUser.id,
        });
      } catch (e) {
        debugPrint('⚠️ Could not write subticket activity log: $e');
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onSubticketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.subticketCreatedSuccessfully} #$ticketNumber$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedToCreateSubticket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return OptimizedDialog(
      title: l10n.createSubticket,
      width: isMobile
          ? MediaQuery.of(context).size.width * 0.95
          : MediaQuery.of(context).size.width * 0.6,
      contentPadding: const EdgeInsets.all(16),
      child: CreateSubticketContent(
        titleController: _titleController,
        descriptionController: _descriptionController,
        highPriorityController: _highPriorityController,
        phoneController: _phoneController,
        selectedDepartmentId: _selectedDepartmentId,
        selectedNatureOfWorkId: _selectedNatureOfWorkId,
        selectedPriority: _selectedPriority,
        departments: _departments,
        natureOfWorkList: _natureOfWorkList,
        selectedFiles: _selectedFiles,
        parentTicket: widget.parentTicket,
        onDepartmentChanged: (value) {
          setState(() {
            _selectedDepartmentId = value;
            _selectedNatureOfWorkId = null;
            _natureOfWorkList.clear();
          });
          if (value != null) {
            _loadNatureOfWorkForDepartment(value);
          }
        },
        onNatureOfWorkChanged: (value) {
          setState(() => _selectedNatureOfWorkId = value);
        },
        onPriorityChanged: (value) {
          setState(() => _selectedPriority = value);
        },
        onPickImages: _pickImages,
        onPickFiles: _pickFiles,
        onRemoveFile: _removeFile,
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploadingFiles)
              ? null
              : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            l10n.cancel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed:
              (_isLoading || _isUploadingFiles) ? null : _createSubticket,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: (_isLoading || _isUploadingFiles)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingFiles ? l10n.uploading : l10n.creating,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.createSubticket,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

// Reusable Content Widget
class CreateSubticketContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController highPriorityController;
  final TextEditingController phoneController;
  final String? selectedDepartmentId;
  final String? selectedNatureOfWorkId;
  final PriorityType selectedPriority;
  final List<DepartmentModel> departments;
  final List<NatureOfWorkModel> natureOfWorkList;
  final List<PlatformFile> selectedFiles;
  final TicketModel parentTicket;
  final Function(String?) onDepartmentChanged;
  final Function(String?) onNatureOfWorkChanged;
  final Function(PriorityType) onPriorityChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;

  const CreateSubticketContent({
    Key? key,
    required this.titleController,
    required this.descriptionController,
    required this.highPriorityController,
    required this.phoneController,
    required this.selectedDepartmentId,
    required this.selectedNatureOfWorkId,
    required this.selectedPriority,
    required this.departments,
    required this.natureOfWorkList,
    required this.selectedFiles,
    required this.parentTicket,
    required this.onDepartmentChanged,
    required this.onNatureOfWorkChanged,
    required this.onPriorityChanged,
    required this.onPickImages,
    required this.onPickFiles,
    required this.onRemoveFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent Ticket Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree,
                      color: Colors.deepPurple[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.parentTicket,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${parentTicket.ticketNumber} - ${parentTicket.title}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Title
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: '${l10n.subticketTitle} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: l10n.briefDescriptionSubtask,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: '${l10n.description} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: l10n.detailedDescriptionTodo,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 10),

        // Department Dropdown
        SearchableDropdown<String>(
          labelText: '${l10n.targetDepartment} *',
          hintText: l10n.selectDepartmentSubtask,
          value: selectedDepartmentId,
          items: departments
              .map((dept) => DropdownMenuItem(
                    value: dept.id,
                    child: Text(dept.localizedName(lang)),
                  ))
              .toList(),
          getLabel: (id) => departments.firstWhere((d) => d.id == id).localizedName(lang),
          onChanged: onDepartmentChanged,
        ),
        const SizedBox(height: 10),

        // Nature of Work Section
        if (selectedDepartmentId != null) ...[
          Text(
            '${l10n.natureOfWork} *',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (natureOfWorkList.isNotEmpty) ...[
            SearchableDropdown<String>(
              labelText: l10n.natureOfWork,
              hintText: l10n.selectNatureOfWork,
              value: selectedNatureOfWorkId,
              items: natureOfWorkList
                  .map((now) => DropdownMenuItem(
                        value: now.id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(now.localizedName(lang)),
                            if (now.description != null)
                              Text(
                                now.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
              getLabel: (id) =>
                  natureOfWorkList.firstWhere((n) => n.id == id).localizedName(lang),
              onChanged: onNatureOfWorkChanged,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                l10n.noNatureOfWorkAvailable,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        // Priority Dropdown
        DropdownButtonFormField<PriorityType>(
          value: selectedPriority,
          decoration: InputDecoration(
            labelText: '${l10n.priority} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
            ),
          ),
          items: PriorityType.values.map((priority) {
            return DropdownMenuItem(
              value: priority,
              child: Row(
                children: [
                  Icon(
                    priority == PriorityType.urgent
                        ? Icons.emergency
                        : priority == PriorityType.high
                            ? Icons.priority_high
                            : priority == PriorityType.medium
                                ? Icons.remove
                                : Icons.low_priority,
                    color: priority == PriorityType.urgent
                        ? Colors.purple
                        : priority == PriorityType.high
                            ? Colors.red
                            : priority == PriorityType.medium
                                ? Colors.orange
                                : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPriorityText(priority, l10n).toUpperCase(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onPriorityChanged(value);
            }
          },
        ),
        const SizedBox(height: 10),

        // High Priority Explanation
        if (selectedPriority == PriorityType.high ||
            selectedPriority == PriorityType.urgent) ...[
          TextField(
            controller: highPriorityController,
            decoration: InputDecoration(
              labelText: '${l10n.highPriorityExplanation} *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: l10n.explainWhyUrgent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFF16936), width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
        ],

        // File Attachments Section
        _buildFileAttachmentSection(
          selectedFiles,
          onPickImages,
          onPickFiles,
          onRemoveFile,
          l10n,
        ),
        const SizedBox(height: 10),

        // Information Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.deepPurple, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.subticketInformation,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• ${l10n.subticketWillBeLinked}\n'
                '• ${l10n.canBeAssignedDifferentDept}\n'
                '• ${l10n.helpsBreakDownTasks}\n'
                '• ${l10n.parentCanTrackSubtickets}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Helper method for priority text
  String _getPriorityText(PriorityType priority, AppLocalizations l10n) {
    switch (priority) {
      case PriorityType.low:
        return l10n.low;
      case PriorityType.medium:
        return l10n.medium;
      case PriorityType.high:
        return l10n.high;
      case PriorityType.urgent:
        return l10n.urgent;
    }
  }

  Widget _buildFileAttachmentSection(
    List<PlatformFile> files,
    VoidCallback pickImages,
    VoidCallback pickFiles,
    Function(int) removeFile,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.attachments,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: pickImages,
              icon: const Icon(Icons.image, size: 18, color: Colors.deepPurple),
              label: Text(l10n.images,
                  style: const TextStyle(color: Colors.deepPurple)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            TextButton.icon(
              onPressed: pickFiles,
              icon: const Icon(Icons.attach_file,
                  size: 18, color: Colors.deepPurple),
              label: Text(l10n.files,
                  style: const TextStyle(color: Colors.deepPurple)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (files.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isImage = ['jpg', 'jpeg', 'png', 'gif']
                    .contains(file.extension?.toLowerCase());

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            child: isImage
                                ? (file.bytes != null
                                    ? Image.memory(file.bytes!,
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 32))
                                : Icon(
                                    _getFileIcon(file.extension),
                                    size: 32,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => removeFile(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Icon(Icons.delete,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${files.length} ${files.length > 1 ? l10n.filesSelected : l10n.file}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                l10n.noFilesSelected,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class CreateSubticketScreen extends StatefulWidget {
  final TicketModel parentTicket;
  final UserModel currentUser;
  final VoidCallback onSubticketCreated;

  const CreateSubticketScreen({
    super.key,
    required this.parentTicket,
    required this.currentUser,
    required this.onSubticketCreated,
  });

  @override
  State<CreateSubticketScreen> createState() => _CreateSubticketScreenState();
}

class _CreateSubticketScreenState extends State<CreateSubticketScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _highPriorityController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedNatureOfWorkId;
  PriorityType _selectedPriority = PriorityType.medium;

  List<DepartmentModel> _departments = [];
  List<NatureOfWorkModel> _natureOfWorkList = [];

  List<PlatformFile> _selectedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentUser.phone ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departmentsResponse = await supabase.from('departments').select();

      setState(() {
        _departments = departmentsResponse
            .map<DepartmentModel>((json) => DepartmentModel.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadNatureOfWorkForDepartment(String departmentId) async {
    try {
      final response = await supabase
          .from('nature_of_work')
          .select()
          .eq('department_id', departmentId)
          .eq('is_active', true)
          .order('name');

      setState(() {
        _natureOfWorkList = response
            .map<NatureOfWorkModel>((json) => NatureOfWorkModel.fromJson(json))
            .toList();
        _selectedNatureOfWorkId = null;
      });
    } catch (e) {
      print('Error loading nature of work: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.safeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.createSubticket,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CreateSubticketContent(
                titleController: _titleController,
                descriptionController: _descriptionController,
                highPriorityController: _highPriorityController,
                phoneController: _phoneController,
                selectedDepartmentId: _selectedDepartmentId,
                selectedNatureOfWorkId: _selectedNatureOfWorkId,
                selectedPriority: _selectedPriority,
                departments: _departments,
                natureOfWorkList: _natureOfWorkList,
                selectedFiles: _selectedFiles,
                parentTicket: widget.parentTicket,
                onDepartmentChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                    _selectedNatureOfWorkId = null;
                    _natureOfWorkList.clear();
                  });
                  if (value != null) {
                    _loadNatureOfWorkForDepartment(value);
                  }
                },
                onNatureOfWorkChanged: (value) {
                  setState(() => _selectedNatureOfWorkId = value);
                },
                onPriorityChanged: (value) {
                  setState(() => _selectedPriority = value);
                },
                onPickImages: _pickImages,
                onPickFiles: _pickFiles,
                onRemoveFile: _removeFile,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isUploadingFiles)
                        ? null
                        : _createSubticket,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isUploadingFiles)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isUploadingFiles
                                    ? l10n.uploading
                                    : l10n.creating,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_tree, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.createSubticket,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingFiles}: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.safeOf(context);

    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        List<PlatformFile> imageFiles = [];
        for (XFile image in images) {
          final bytes = await image.readAsBytes();
          imageFiles.add(PlatformFile(
            name: image.name,
            size: bytes.length,
            bytes: bytes,
            path: image.path,
          ));
        }

        setState(() {
          _selectedFiles.addAll(imageFiles);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorPickingImages}: $e')),
      );
    }
  }

  Future<void> _createSubticket() async {
    final l10n = AppLocalizations.safeOf(context);

    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDepartmentId == null ||
        (_selectedNatureOfWorkId == null && _natureOfWorkList.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllRequired)),
      );
      return;
    }

    if ((_selectedPriority == PriorityType.high ||
            _selectedPriority == PriorityType.urgent) &&
        _highPriorityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseExplainHighPriority)),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterPhoneNumber)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ticketData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'target_department_id': _selectedDepartmentId,
        'nature_of_work_id': _selectedNatureOfWorkId,
        'parent_ticket_id': widget.parentTicket.id,
        if (widget.parentTicket.placeId != null)
          'place_id': widget.parentTicket.placeId,
        'other_place': 'Other',
        'other_problem_title': 'Other',
        'priority': _selectedPriority.value,
        'high_priority_explain': (_selectedPriority == PriorityType.high ||
                _selectedPriority == PriorityType.urgent)
            ? _highPriorityController.text.trim()
            : null,
        'other_model_number': 'Other',
        'created_by': widget.currentUser.id,
        'creator_phone': _phoneController.text.trim(),
      };

      final success = await TicketService.createTicket(ticketData);

      if (!success) {
        throw Exception('TicketService.createTicket returned false');
      }

      final recentTickets = await supabase
          .from('tickets')
          .select('id, ticket_number')
          .eq('created_by', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentTickets.isEmpty) {
        throw Exception('Could not find the created subticket for file upload');
      }

      final ticketId = recentTickets.first['id'];
      final ticketNumber = recentTickets.first['ticket_number'];

      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles(ticketId);
      }

      // Add activity log to parent ticket timeline
      try {
        await supabase.from('activity_logs').insert({
          'table_name': 'tickets',
          'record_id': widget.parentTicket.id,
          'action': 'subticket_created',
          'new_values': {
            'subticket_id': ticketId,
            'subticket_number': ticketNumber,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
          },
          'user_id': widget.currentUser.id,
        });
      } catch (e) {
        debugPrint('⚠️ Could not write subticket activity log: $e');
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
        widget.onSubticketCreated();

        final attachmentText = _selectedFiles.isEmpty
            ? ''
            : ' ${_selectedFiles.length > 1 ? l10n.withAttachments : l10n.withAttachment}';

        final successMessage =
            '${l10n.subticketCreatedSuccessfully} #$ticketNumber$attachmentText';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${l10n.failedToCreateSubticket}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles(String ticketId) async {
    if (_selectedFiles.isEmpty) return [];

    setState(() => _isUploadingFiles = true);

    List<String> uploadedFilePaths = [];

    try {
      for (PlatformFile file in _selectedFiles) {
        if (file.bytes != null) {
          final uuid = const Uuid();
          final fileExtension = file.name.split('.').last;
          final fileName = '${uuid.v4()}.$fileExtension';
          final filePath = 'ticket_attachments/$ticketId/$fileName';

          await supabase.storage.from('attachments').uploadBinary(
                filePath,
                file.bytes!,
                fileOptions: FileOptions(
                  contentType: _getMimeType(file.name),
                ),
              );

          await supabase.from('ticket_attachments').insert({
            'ticket_id': ticketId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'mime_type': _getMimeType(file.name),
            'uploaded_by': widget.currentUser.id,
          });

          uploadedFilePaths.add(filePath);
        }
      }
    } catch (e) {
      throw e;
    } finally {
      setState(() => _isUploadingFiles = false);
    }

    return uploadedFilePaths;
  }

  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _highPriorityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
