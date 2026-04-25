import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/app_colors.dart';
import '../services/app_settings.dart';
import '../widgets/theme_aware.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/translate_text.dart';

class DiseaseScannerScreen extends StatefulWidget {
  const DiseaseScannerScreen({super.key});

  @override
  State<DiseaseScannerScreen> createState() => _DiseaseScannerScreenState();
}

class _DiseaseScannerScreenState extends State<DiseaseScannerScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  
  bool _isScanning = false;
  bool _scanComplete = false;
  
  String _detectedDisease = '';
  String _recommendedTreatment = '';
  double _confidenceScore = 0.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final s = AppSettings.instance;
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        
        setState(() {
          _imageBytes = bytes;
          _isScanning = true;
          _scanComplete = false;
          _detectedDisease = s.translate('analyzing');
          _confidenceScore = 0.0;
        });

        try {
          const String geminiKey = 'AIzaSyCGLvKvohePi86VRRCJgRHF9sIZGhnLTOg';
          final models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash-lite'];
          final String base64Image = base64Encode(bytes);
          bool success = false;

          for (var modelName in models) {
            try {
              final String url = 'https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent?key=$geminiKey';
              
              final Map<String, dynamic> requestBody = {
                "contents": [{
                  "parts": [
                    {"text": 'Analyze this rice plant leaf image. Identify the disease if any. '
                             'Return the result in JSON format ONLY with these keys: "disease" (name of the disease or "Healthy"), '
                             '"treatment" (one concise, professional, and actionable treatment advice), '
                             'and "confidence" (a decimal number between 0.0 and 1.0 representing your certainty). '
                             'If it is a disease, provide specific agricultural steps to cure it.'},
                    {
                      "inline_data": {
                        "mime_type": "image/jpeg",
                        "data": base64Image
                      }
                    }
                  ]
                }]
              };

              final response = await http.post(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(requestBody),
              ).timeout(const Duration(seconds: 40));

              if (response.statusCode == 200) {
                final Map<String, dynamic> data = json.decode(response.body);
                final String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
                
                if (text != null && text.isNotEmpty) {
                  // Extract JSON from potentially markdown-wrapped response
                  String cleanJson = text;
                  if (text.contains('```json')) {
                    cleanJson = text.split('```json')[1].split('```')[0].trim();
                  } else if (text.contains('```')) {
                    cleanJson = text.split('```')[1].split('```')[0].trim();
                  }
                  
                  final result = json.decode(cleanJson);
                  _detectedDisease = result['disease'] ?? 'Unknown';
                  _recommendedTreatment = result['treatment'] ?? '';
                  _confidenceScore = (result['confidence'] as num?)?.toDouble() ?? 0.99;
                  
                  if (_detectedDisease.toLowerCase() != 'healthy') {
                     await _logToHistoryAndNotifyWithData(_detectedDisease, _recommendedTreatment, _confidenceScore);
                  }
                  success = true;
                  break; // Exit model loop
                }
              }
            } catch (e) {
              debugPrint("Model $modelName failed: $e");
              continue; // Try next model
            }
          }

          if (!success) {
            _detectedDisease = "AI Analysis Unavailable";
            _confidenceScore = 0.0;
          }
        } catch(e) {
          debugPrint("Gemini Exception: $e");
          _detectedDisease = "Connection Failed";
          _confidenceScore = 0.0;
        }
        
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanComplete = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hardware Error: $e')));
      }
    }
  }

  Future<void> _logToHistoryAndNotifyWithData(String disease, String treatmentEn, double confidence) async {
    if (user == null) return;
    final s = AppSettings.instance;
    
    // Use Gemini treatment as base
    String actionParamsEn = treatmentEn;
    String actionParamsBn = s.isBengali ? await s.translateAsync(treatmentEn) : treatmentEn;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('disease_history').add({
         'disease': disease,
         'confidence': confidence,
         'action': actionParamsEn,
         'actionBn': actionParamsBn,
         'timestamp': FieldValue.serverTimestamp(),
      });
      
      final title = s.isBengali ? '🌾 স্বাস্থ্য পরীক্ষা: $disease' : '🌾 Health Scan: $disease';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .add({
         'title': title,
         'body': s.isBengali ? actionParamsBn : actionParamsEn,
         'type': 'health',
         'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!kIsWeb) {
       final titleNotif = s.isBengali ? '🌱 পরীক্ষার ফলাফল: $disease' : '🌱 Scan Result: $disease';
       final bodyNotif = s.isBengali ? 'বিস্তারিত দেখুন।' : 'Tap to View.';
       await NotificationService.showNotification(
         id: DateTime.now().millisecondsSinceEpoch % 100000,
         title: titleNotif,
         body: bodyNotif,
       );
    }
  }




  void _showHistoryDrawer() {
    if (user == null) return;
    final s = AppSettings.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: AppColors.secondaryText.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(s.isBengali ? 'ফসলের চিকিৎসার ইতিহাস' : 'Crop Medical History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('disease_history')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppColors.accent));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text(s.isBengali ? 'এখনও কোনো রেকর্ড পাওয়া যায়নি।' : 'No scans have been recorded yet.', style: TextStyle(color: AppColors.secondaryText, fontSize: 16)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        final ts = data['timestamp'] as Timestamp?;
                        final dateStr = ts != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(ts.toDate()) : (s.isBengali ? 'যোগ হচ্ছে...' : 'Logging...');
                        
                        String dName = data['disease'] ?? 'Unknown';
                        double conf = (data['confidence'] as num?)?.toDouble() ?? 0.0;
                        bool healthy = dName.toLowerCase().contains('healthy');
                        String action = s.isBengali ? (data['actionBn'] ?? data['action'] ?? '') : (data['action'] ?? '');
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.glassFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.glassBorder, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 1)],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: TranslateText(dName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: healthy ? Colors.green : Colors.redAccent))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${(conf * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.close_rounded, color: Colors.red.withOpacity(0.5), size: 20),
                                      onPressed: () => FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user!.uid)
                                          .collection('disease_history')
                                          .doc(doc.id)
                                          .delete(),
                                      tooltip: s.isBengali ? 'মুছে ফেলুন' : 'Delete',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TranslateText(action, style: TextStyle(fontSize: 13, color: AppColors.primaryText)),
                                const SizedBox(height: 12),
                                Text(s.translatePrice(dateStr), style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildGlassBox({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    final s = AppSettings.instance;
    bool isHealthy = _detectedDisease.toLowerCase().contains('healthy');
    Color activeColor = _confidenceScore == 0.0 ? Colors.orange : (isHealthy ? Colors.green : Colors.redAccent);
    IconData activeIcon = _confidenceScore == 0.0 ? Icons.error_outline : (isHealthy ? Icons.verified_user_rounded : Icons.warning_amber_rounded);
    String severityStr = _confidenceScore == 0.0 
        ? (s.isBengali ? 'বিশ্লেষণ ব্যর্থ হয়েছে' : 'Analysis Failed') 
        : (isHealthy ? (s.isBengali ? 'সুস্থ গাছ' : 'Clear diagnosis') : (s.isBengali ? 'রোগ পাওয়া গেছে!' : 'Infection Detected!'));

    return _buildGlassBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: activeColor.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(activeIcon, color: activeColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(severityStr, style: TextStyle(color: activeColor, fontWeight: FontWeight.bold)),
                    TranslateText(
                      _detectedDisease.isEmpty ? (s.isBengali ? 'অজানা' : 'Unknown') : _detectedDisease, 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryText)
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.translate('confidence') + ':', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryText)),
              Text('${s.translatePrice((_confidenceScore * 100).toStringAsFixed(1))}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.indigoAccent)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _confidenceScore,
              minHeight: 12,
              backgroundColor: Colors.black12,
              color: Colors.indigoAccent,
            ),
          ),
          const SizedBox(height: 24),
          Text(s.translate('treatment'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
          const SizedBox(height: 8),
          TranslateText(
            _confidenceScore == 0.0 
               ? (_detectedDisease.contains('Neural') 
                   ? (s.isBengali ? 'সার্ভার প্রস্তুত হচ্ছে। অনুগ্রহ করে ৩০ সেকেন্ড পর আবার চেষ্টা করুন।' : 'Neural network is waking up. Please try again in 30 seconds!')
                   : (s.isBengali ? 'সার্ভারের সাথে সংযোগ স্থাপন করা যাচ্ছে না। আপনার ইন্টারনেট চেক করুন।' : 'Could not connect to the analysis server. Please check your internet.'))
               : _recommendedTreatment, 
            style: TextStyle(fontSize: 14, color: AppColors.primaryText)
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.translate('disease_scanner'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.appBarText)),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appBarText),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 28),
            onPressed: _showHistoryDrawer,
            tooltip: s.isBengali ? 'ইতিহাস দেখুন' : 'View Scan History',
          ),
          const AppMenuButton(),
        ],
      ),
      body: ThemeAware(
        builder: (context) => Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder, width: 2),
                        image: _imageBytes != null 
                          ? DecorationImage(
                              image: MemoryImage(_imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_imageBytes == null)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.document_scanner_rounded, size: 80, color: AppColors.secondaryText.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text(s.isBengali ? 'পাতা পাওয়া যায়নি' : 'No Leaf Detected', style: TextStyle(fontSize: 18, color: AppColors.primaryText, fontWeight: FontWeight.bold)),
                                Text(s.isBengali ? 'ফ্রেমের মাঝখানে পাতাটি রাখুন' : 'Frame a single leaf clearly', style: TextStyle(color: AppColors.secondaryText)),
                              ],
                            ),
                            
                          if (_isScanning)
                            FadeTransition(
                              opacity: _pulseAnimation,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.cyanAccent, width: 6),
                                  color: Colors.cyan.withOpacity(0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    s.isBengali ? '[ তথ্য পাঠানো হচ্ছে ]' : '[ TRANSMITTING DATA ]', 
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, backgroundColor: Colors.black54, letterSpacing: 2)
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (!_isScanning && !_scanComplete)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: Text(s.translate('take_photo')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: Text(s.isBengali ? 'গ্যালারি' : 'Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.glassFill,
                              foregroundColor: AppColors.accent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: AppColors.accent, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                  if (_isScanning)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: AppColors.accent),
                      )
                    ),
                    
                  if (_scanComplete)
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildResultsPanel(),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => setState(() { _imageBytes = null; _scanComplete = false; }),
                              icon: Icon(Icons.refresh_rounded, color: AppColors.secondaryText),
                              label: Text(s.isBengali ? 'অন্য পাতা পরীক্ষা করুন' : 'Scan Another Leaf', style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                    ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
