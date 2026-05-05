import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_text/pdf_text.dart';
import 'repositories/firestore_repository.dart';
import 'models/packing_slip_item.dart';
import 'models/purchase_order.dart';
import 'models/app_user.dart';
import 'models/delivery.dart';
import 'models/material.dart' as model;
import 'ocr_tesseract_stub.dart'
    if (dart.library.html) 'ocr_tesseract_web.dart';

enum DocumentType { packingSlip, payOrder }

class ScanPage extends StatefulWidget {
  final AppUser? currentUser;
  const ScanPage({super.key, this.currentUser});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  String _recognizedText = '';
  bool _isProcessing = false;
  DocumentType _selectedDocumentType = DocumentType.packingSlip;
  final FirestoreRepository _repository = FirestoreRepository();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Form controllers for packing slip
  final TextEditingController _packingSlipDescriptionController = TextEditingController();
  final TextEditingController _packingSlipQuantityController = TextEditingController();
  final TextEditingController _packingSlipUnitController = TextEditingController(text: 'unit');
  String? _selectedDeliveryId;

  // Form controllers for pay order
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _poExpectedDateController = TextEditingController();
  final TextEditingController _poItemDescriptionController = TextEditingController();
  final TextEditingController _poItemQuantityController = TextEditingController();
  final TextEditingController _poItemCostController = TextEditingController();
  String? _selectedMaterialId;

  bool _showReviewForm = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _controller = CameraController(cameras![0], ResolutionPreset.medium);
      await _controller!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  Future<void> _captureAndRecognize() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera OCR is not supported on web. Please use image upload on a supported mobile platform.')),
      );
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing image...')),
    );

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in image.')),
        );
        setState(() {
          _recognizedText = 'No text found in image.';
          _isProcessing = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image processed! Found ${recognizedText.text.length} characters.')),
        );
        _parseAndShowReviewForm(recognizedText.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
      setState(() {
        _recognizedText = 'Error recognizing text: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImageAndRecognize() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing image...')),
      );

      setState(() {
        _isProcessing = true;
      });

      try {
        String recognizedText;

        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          if (bytes.isEmpty) {
            throw Exception('Image data is unavailable on web.');
          }
          recognizedText = await recognizeImageBytesWeb(bytes);
        } else {
          final inputImage = InputImage.fromFilePath(pickedFile.path);
          final textRecognizer = TextRecognizer();
          final result = await textRecognizer.processImage(inputImage);
          await textRecognizer.close();
          recognizedText = result.text;
        }

        if (recognizedText.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image.')),
          );
          setState(() {
            _recognizedText = 'No text found in image.';
            _isProcessing = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image processed! Found ${recognizedText.length} characters.')),
          );
          _parseAndShowReviewForm(recognizedText);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
        setState(() {
          _recognizedText = 'Error recognizing text: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickPdfAndExtractText() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing PDF...')),
      );

      setState(() {
        _isProcessing = true;
      });

      try {
        final file = result.files.first;
        String text;

        if (kIsWeb) {
          // For web, show a helpful message since PDF text extraction is complex
          throw Exception(
            'PDF text extraction on web is not currently supported. '
            'Please use the camera or upload an image instead for OCR processing.'
          );
        } else {
          // Use pdf_text for native platforms
          if (file.path == null) {
            throw Exception('File path is null. PDF extraction requires a local file path.');
          }
          final pdfDoc = await PDFDoc.fromPath(file.path!);
          text = await pdfDoc.text;
        }

        if (text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in PDF. It might be image-based.')),
          );
          setState(() {
            _recognizedText = 'No text found in PDF. The PDF might be image-based or corrupted.';
            _isProcessing = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF processed successfully! Found ${text.length} characters.')),
          );
          _parseAndShowReviewForm(text);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing PDF: $e')),
        );
        setState(() {
          _recognizedText = 'Error extracting text from PDF: $e';
          _isProcessing = false;
        });
      }
    }
  }

  void _parseAndShowReviewForm(String text) {
    if (_selectedDocumentType == DocumentType.packingSlip) {
      _parsePackingSlip(text);
    } else {
      _parsePurchaseOrder(text);
    }

    setState(() {
      _recognizedText = text;
      _showReviewForm = true;
      _isProcessing = false;
    });
  }

  void _parsePackingSlip(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();

    // Look for quantity patterns
    final quantityPatterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:qty|quantity|pcs|pieces|units?|ea|each)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*x\s', caseSensitive: false), // e.g., "2 x "
      RegExp(r'^\s*(\d+(?:\.\d+)?)\s', caseSensitive: false), // quantity at start of line
    ];

    for (final pattern in quantityPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        _packingSlipQuantityController.text = match.group(1)!;
        break;
      }
    }

    // Look for unit patterns
    final unitPatterns = [
      RegExp(r'(?:qty|quantity|pcs|pieces|units?|ea|each|box|case|pack)\s*(\w+)', caseSensitive: false),
      RegExp(r'(\w+)\s*(?:qty|quantity|pcs|pieces|units?|ea|each)', caseSensitive: false),
    ];

    for (final pattern in unitPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final unit = match.group(1)!.toLowerCase();
        if (['box', 'case', 'pack', 'pallet', 'piece', 'unit', 'ea', 'each'].contains(unit)) {
          _packingSlipUnitController.text = unit;
          break;
        }
      }
    }

    // Extract description - look for the most descriptive line
    String bestDescription = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length > bestDescription.length &&
          !RegExp(r'^\d+$').hasMatch(trimmed) && // not just numbers
          !RegExp(r'^(qty|quantity|total|subtotal|date|packing|slip)', caseSensitive: false).hasMatch(trimmed)) {
        bestDescription = trimmed;
      }
    }

    if (bestDescription.isNotEmpty) {
      _packingSlipDescriptionController.text = bestDescription;
    } else if (lines.isNotEmpty) {
      _packingSlipDescriptionController.text = lines.first.trim();
    }
  }

  void _parsePurchaseOrder(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();

    // PO Number patterns
    final poPatterns = [
      RegExp(r'PO\s*#?\s*:?\s*([A-Z0-9\-]+)', caseSensitive: false),
      RegExp(r'Purchase\s+Order\s*#?\s*:?\s*([A-Z0-9\-]+)', caseSensitive: false),
      RegExp(r'Order\s*#?\s*:?\s*([A-Z0-9\-]+)', caseSensitive: false),
      RegExp(r'#\s*([A-Z0-9\-]+)', caseSensitive: false),
    ];

    for (final pattern in poPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        _poNumberController.text = match.group(1)!;
        break;
      }
    }

    // Date patterns for expected delivery
    final datePatterns = [
      RegExp(r'(?:delivery|ship|expected)\s+date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        _poExpectedDateController.text = match.group(1)!;
        break;
      }
    }

    // Quantity patterns
    final quantityPatterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:qty|quantity|pcs|pieces|units?|ea|each)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*x\s', caseSensitive: false),
      RegExp(r'^\s*(\d+(?:\.\d+)?)\s', caseSensitive: false),
    ];

    for (final pattern in quantityPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        _poItemQuantityController.text = match.group(1)!;
        break;
      }
    }

    // Cost/price patterns
    final costPatterns = [
      RegExp(r'\$?\s*(\d+(?:\.\d+)?)\s*(?:each|per|cost|price)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:each|per|cost|price)', caseSensitive: false),
      RegExp(r'\$?\s*(\d+(?:\.\d+)?)\s*$', caseSensitive: false), // price at end of line
    ];

    for (final pattern in costPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        _poItemCostController.text = match.group(1)!;
        break;
      }
    }

    // Extract item description - look for descriptive lines
    String bestDescription = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length > bestDescription.length &&
          trimmed.length > 10 && // reasonably long
          !RegExp(r'^\d+$').hasMatch(trimmed) && // not just numbers
          !RegExp(r'^(po|purchase|order|date|total|subtotal|tax|shipping|qty|quantity|price|cost)', caseSensitive: false).hasMatch(trimmed)) {
        bestDescription = trimmed;
      }
    }

    if (bestDescription.isNotEmpty) {
      _poItemDescriptionController.text = bestDescription;
    } else if (lines.isNotEmpty) {
      // Fallback to first non-header line
      for (final line in lines) {
        if (!RegExp(r'^(po|purchase|order|date|total|subtotal|tax|shipping)', caseSensitive: false).hasMatch(line.trim())) {
          _poItemDescriptionController.text = line.trim();
          break;
        }
      }
    }
  }

  Future<void> _savePackingSlipItem() async {
    if (widget.currentUser == null) return;

    final deliveryId = _selectedDeliveryId ?? 'unassigned';
    final quantity = double.tryParse(_packingSlipQuantityController.text) ?? 0.0;
    final confidenceScore = quantity > 0 && _packingSlipDescriptionController.text.isNotEmpty
        ? 0.85
        : 0.55;

    try {
      final item = PackingSlipItem(
        packingSlipItemId: '', // Will be set by Firestore
        deliveryId: deliveryId,
        rawDescription: _packingSlipDescriptionController.text,
        quantityListed: quantity,
        unitOfMeasure: _packingSlipUnitController.text,
        parsedConfidenceScore: confidenceScore,
        isManuallyVerified: confidenceScore >= 0.75,
      );

      await _repository.savePackingSlipItem(item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Packing slip item saved successfully')),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    }
  }

  Future<void> _savePurchaseOrder() async {
    if (widget.currentUser == null) return;

    try {
      final expectedDate = DateTime.tryParse(_poExpectedDateController.text) ?? DateTime.now().add(const Duration(days: 7));

      final po = PurchaseOrder(
        poId: '',
        poNumber: _poNumberController.text,
        orderDate: DateTime.now(),
        expectedDeliveryDate: expectedDate,
        status: PurchaseOrderStatus.pending,
      );

      final poId = await _repository.createPurchaseOrder(po);

      // Create PO item if either a material ID is selected or a description is available
      if (_selectedMaterialId != null || _poItemDescriptionController.text.trim().isNotEmpty) {
        final materialIdFallback = _selectedMaterialId ?? _poItemDescriptionController.text.trim();
        final poItem = PurchaseOrderItem(
          poItemId: '',
          poId: poId,
          materialId: materialIdFallback,
          quantityOrdered: double.tryParse(_poItemQuantityController.text) ?? 0.0,
          unitCost: double.tryParse(_poItemCostController.text) ?? 0.0,
        );
        await _repository.createPurchaseOrderItem(poItem);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase order saved successfully')),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving purchase order: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _showReviewForm = false;
      _recognizedText = '';
      _packingSlipDescriptionController.clear();
      _packingSlipQuantityController.clear();
      _packingSlipUnitController.text = 'unit';
      _poNumberController.clear();
      _poExpectedDateController.clear();
      _poItemDescriptionController.clear();
      _poItemQuantityController.clear();
      _poItemCostController.clear();
      _selectedDeliveryId = null;
      _selectedMaterialId = null;
    });
  }

  void _saveForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedDocumentType == DocumentType.packingSlip) {
        _savePackingSlipItem();
      } else {
        _savePurchaseOrder();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Documents'),
        actions: [
          if (!_showReviewForm)
            DropdownButton<DocumentType>(
              value: _selectedDocumentType,
              onChanged: (DocumentType? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDocumentType = newValue;
                  });
                }
              },
              items: DocumentType.values.map((DocumentType type) {
                return DropdownMenuItem<DocumentType>(
                  value: type,
                  child: Text(type == DocumentType.packingSlip ? 'Packing Slip' : 'Pay Order'),
                );
              }).toList(),
            ),
        ],
      ),
      body: SafeArea(
        child: _showReviewForm ? _buildReviewForm() : _buildScanInterface(),
      ),
    );
  }

  Widget _buildScanInterface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Camera preview section
            if (_isCameraInitialized && _controller != null)
              SizedBox(
                height: constraints.maxHeight * 0.6, // Use 60% of available height
                width: double.infinity,
                child: CameraPreview(_controller!),
              )
            else
              SizedBox(
                height: constraints.maxHeight * 0.6,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Control section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Document Type: ${_selectedDocumentType == DocumentType.packingSlip ? 'Packing Slip' : 'Pay Order'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _captureAndRecognize,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Picture'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickImageAndRecognize,
                          icon: const Icon(Icons.photo),
                          label: const Text('Pick Image'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickPdfAndExtractText,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Pick PDF'),
                        ),
                      ],
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Web supports JPG image OCR via Tesseract.js, but PDF upload is still not supported. Use image upload for OCR on web or mobile for PDF.',
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_isProcessing)
                      const CircularProgressIndicator()
                    else if (_recognizedText.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _recognizedText,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedDocumentType == DocumentType.packingSlip
                            ? Icons.inventory
                            : Icons.receipt,
                        size: 28,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Review ${_selectedDocumentType == DocumentType.packingSlip ? 'Packing Slip' : 'Purchase Order'} Data',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scanned Text Preview:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recognizedText.length > 200
                              ? '${_recognizedText.substring(0, 200)}...'
                              : _recognizedText,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _selectedDocumentType == DocumentType.packingSlip
                      ? _buildPackingSlipForm()
                      : _buildPayOrderForm(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveForm,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPackingSlipForm() {
    return Column(
      children: [
        TextFormField(
          controller: _packingSlipDescriptionController,
          decoration: const InputDecoration(
            labelText: 'Item Description *',
            border: OutlineInputBorder(),
            hintText: 'Enter the item description',
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Description is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _packingSlipQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 25',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Quantity is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _packingSlipUnitController.text.isNotEmpty ? _packingSlipUnitController.text : 'unit',
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: ['unit', 'piece', 'box', 'case', 'pack', 'pallet', 'ea', 'each']
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _packingSlipUnitController.text = value;
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Text(
            'Note: Delivery selection will be available in the next update. For now, items are saved with a temporary delivery placeholder.',
            style: TextStyle(color: Colors.blue, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPayOrderForm() {
    return Column(
      children: [
        TextFormField(
          controller: _poNumberController,
          decoration: const InputDecoration(
            labelText: 'PO Number *',
            border: OutlineInputBorder(),
            hintText: 'e.g., PO-2024-001',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'PO Number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _poExpectedDateController,
          decoration: const InputDecoration(
            labelText: 'Expected Delivery Date',
            border: OutlineInputBorder(),
            hintText: 'YYYY-MM-DD or MM/DD/YYYY',
          ),
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              // Basic date validation
              if (!RegExp(r'^\d{1,4}[-/]\d{1,2}[-/]\d{1,4}$').hasMatch(value)) {
                return 'Enter date in format YYYY-MM-DD or MM/DD/YYYY';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<model.Material>>(
          stream: _repository.streamAllMaterials(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Error loading materials: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }

            final materials = snapshot.data!;
            return DropdownButtonFormField<String>(
              value: _selectedMaterialId,
              decoration: const InputDecoration(
                labelText: 'Select Material',
                border: OutlineInputBorder(),
              ),
              items: materials.map((material) {
                final label = '${material.name} (${material.partNumber ?? material.unitOfMeasure})';
                return DropdownMenuItem(
                  value: material.materialId,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMaterialId = value;
                  if (value != null) {
                    final selected = materials.firstWhere((m) => m.materialId == value);
                    if (_poItemCostController.text.trim().isEmpty) {
                      _poItemCostController.text = selected.unitCost.toStringAsFixed(2);
                    }
                  }
                });
              },
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _poItemDescriptionController,
          decoration: const InputDecoration(
            labelText: 'Item Description *',
            border: OutlineInputBorder(),
            hintText: 'Enter the item description',
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Item description is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _poItemQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 100',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Quantity is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _poItemCostController,
                decoration: const InputDecoration(
                  labelText: 'Unit Cost',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 25.50',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Enter a valid cost';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Text(
            'Note: Material selection will be available in the next update. For now, scanned item descriptions will be used as a fallback for material identifiers.',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
      ],
    );
  }
}