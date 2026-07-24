import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

/// Lets the user crop [bytes] before it's uploaded. Used for images added
/// while designing a custom complaint form's welcome/closing screens.
///
/// Shown via [showDialog] rather than as a full-screen route: the crop
/// widget scales the image to cover its viewport, so keeping that viewport
/// a bounded, roughly-square box (instead of the whole phone screen) avoids
/// forcing an excessive zoom on tall/narrow screens.
class CcImageCropScreen extends StatefulWidget {
  final Uint8List bytes;

  const CcImageCropScreen({super.key, required this.bytes});

  @override
  State<CcImageCropScreen> createState() => _CcImageCropScreenState();
}

class _CcAspectPreset {
  final String label;
  final double? ratio;
  const _CcAspectPreset(this.label, this.ratio);
}

const _kAspectPresets = [
  _CcAspectPreset('Free', null),
  _CcAspectPreset('1:1', 1.0),
  _CcAspectPreset('4:3', 4 / 3),
  _CcAspectPreset('16:9', 16 / 9),
];

class _CcImageCropScreenState extends State<CcImageCropScreen> {
  final _controller = CropController();
  bool _cropping = false;
  int _selectedPreset = 0;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.pop(context, croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr ? 'تعذر قص الصورة' : 'Could not crop the image'),
        ));
    }
  }

  Widget _cornerDot(double size, EdgeAlignment edgeAlignment) {
    const visibleSize = 18.0;
    return Center(
      child: Container(
        width: visibleSize,
        height: visibleSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width < 560 ? screenSize.width * 0.92 : 480.0;
    final cropAreaHeight = (screenSize.height * 0.55).clamp(300.0, 440.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isAr ? 'قص الصورة' : 'Crop image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[850],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr ? 'اسحب الزوايا لضبط منطقة القص' : 'Drag the corners to adjust the crop area',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close, size: 18, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

            // Bounded crop area — keeps the viewport close to a typical
            // photo's aspect ratio so the cover-fit crop doesn't over-zoom.
            SizedBox(
              height: cropAreaHeight,
              child: ColoredBox(
                color: Colors.grey.shade900,
                child: Stack(
                  children: [
                    Crop(
                      image: widget.bytes,
                      controller: _controller,
                      onCropped: _onCropped,
                      interactive: true,
                      baseColor: Colors.grey.shade900,
                      maskColor: Colors.black.withOpacity(0.65),
                      cornerDotBuilder: (size, edgeAlignment) => _cornerDot(size, edgeAlignment),
                      progressIndicator: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    if (_cropping)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withOpacity(0.45),
                          child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Aspect ratio presets
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    isAr ? 'النسبة' : 'Aspect',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: List.generate(_kAspectPresets.length, (i) {
                        final preset = _kAspectPresets[i];
                        final isSelected = _selectedPreset == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              setState(() => _selectedPreset = i);
                              _controller.aspectRatio = preset.ratio;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                preset.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.primary : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, widget.bytes),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                    child: Text(isAr ? 'استخدام الأصلية' : 'Use original'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _cropping
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _controller.crop();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _cropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isAr ? 'تم' : 'Done', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
