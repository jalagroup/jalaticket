import 'dart:typed_data';
import 'package:jalasupport/models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:jalasupport/complaint_service.dart';
import 'package:intl/intl.dart';

class ComplaintPDFGenerator {
  static Future<Uint8List> generateCheckReportPDF(
    ComplaintTicketModel complaint,
    ComplaintCheckModel check,
  ) async {
    final pdf = pw.Document();

    // Get all attachments for this complaint
    final attachments =
        await ComplaintService.getComplaintAttachmentsWithUrls(complaint.id);

    // First page - Report details
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'QUALITY COMPLAINT CHECK REPORT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Complaint #: ${complaint.complaintNumber}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Complaint Information
              _buildSectionTitle('Complaint Information'),
              pw.SizedBox(height: 10),
              _buildInfoRow('Complainant Name', complaint.complainantName),
              _buildInfoRow('Receiver', complaint.complaintReceiver),
              _buildInfoRow('Location', complaint.location),
              _buildInfoRow('Mobile Number', complaint.mobileNumber),
              if (complaint.phoneNumber != null)
                _buildInfoRow('Phone Number', complaint.phoneNumber!),
              _buildInfoRow('Item', complaint.itemName ?? 'N/A'),
              if (complaint.batchNumber != null)
                _buildInfoRow('Batch Number', complaint.batchNumber!),
              if (complaint.quantity != null)
                _buildInfoRow('Quantity', complaint.quantity.toString()),
              if (complaint.produceDate != null)
                _buildInfoRow('Produce Date',
                    DateFormat('dd/MM/yyyy').format(complaint.produceDate!)),
              if (complaint.expiredDate != null)
                _buildInfoRow('Expired Date',
                    DateFormat('dd/MM/yyyy').format(complaint.expiredDate!)),
              _buildInfoRow(
                  'Complaint Type', complaint.complaintType.displayName),
              _buildInfoRow('Date', complaint.formattedDate),
              pw.SizedBox(height: 20),

              // Description
              _buildSectionTitle('Complaint Description'),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                child: pw.Text(
                  complaint.description,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 20),

              // Check Details
              _buildSectionTitle('Check Details'),
              pw.SizedBox(height: 10),
              _buildInfoRow(
                'Complaint Check',
                check.complaintCheck ? 'VALID' : 'INVALID',
                valueColor:
                    check.complaintCheck ? PdfColors.green : PdfColors.red,
              ),
              _buildInfoRow('Checker', check.checkerName),
              _buildInfoRow('Check Date', check.formattedCheckDate),
              pw.SizedBox(height: 10),

              // Report
              _buildSectionTitle('Check Report'),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                child: pw.Text(
                  check.report,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 10),

              // Therapeutic Procedure
              if (check.therapeuticProcedure != null &&
                  check.therapeuticProcedure!.isNotEmpty) ...[
                _buildSectionTitle('Therapeutic Procedure'),
                pw.SizedBox(height: 10),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Text(
                    check.therapeuticProcedure!,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              pw.Spacer(),

              // Signatures Section
              pw.SizedBox(height: 30),
              _buildSectionTitle('Signatures'),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSignatureBox('Checker\n${check.checkerName}'),
                  _buildSignatureBox('Quality Control\nManager'),
                  _buildSignatureBox('Sales\nManager'),
                ],
              ),
              pw.SizedBox(height: 10),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black),
                  ),
                ),
                child: pw.Text(
                  'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Add image attachments pages
    final imageAttachments =
        attachments.where((a) => a['is_image'] == true).toList();

    if (imageAttachments.isNotEmpty) {
      // Add a separator page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 2),
                    ),
                    child: pw.Text(
                      'COMPLAINT ATTACHMENTS',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Total Images: ${imageAttachments.length}',
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Add each image on a separate page
      for (var i = 0; i < imageAttachments.length; i++) {
        final attachment = imageAttachments[i];
        try {
          // Download image bytes
          final imageBytes = await ComplaintService.downloadImageBytes(
              attachment['file_path']);

          if (imageBytes != null) {
            final image = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Image header
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey300,
                          border: pw.Border.all(color: PdfColors.black),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Attachment ${i + 1} of ${imageAttachments.length}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'File: ${attachment['file_name']}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Type: ${attachment['attachment_type']}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Uploaded: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(attachment['created_at']))}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 20),

                      // Image
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(
                            image,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),

                      // Footer
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: PdfColors.black),
                          ),
                        ),
                        child: pw.Text(
                          'Complaint #: ${complaint.complaintNumber}',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }
        } catch (e) {
          print('Error adding image to PDF: $e');
          // Add error page
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Icon(
                        const pw.IconData(0xe3b3),
                        size: 64,
                        color: PdfColors.red,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        'Failed to load image',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'File: ${attachment['file_name']}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }
    }

    return pdf.save();
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value, {
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureBox(String label) {
    return pw.Container(
      width: 150,
      height: 80,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.black),
              ),
            ),
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> downloadAndPrintPDF(
    ComplaintTicketModel complaint,
    ComplaintCheckModel check,
  ) async {
    final pdfBytes = await generateCheckReportPDF(complaint, check);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
}
