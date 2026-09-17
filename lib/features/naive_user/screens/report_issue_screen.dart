import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/grievance_provider.dart';
import '../../../models/building_model.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  File? _capturedImage;
  double? _gpsLat;
  double? _gpsLng;

  int? _selectedBuildingId;
  String _selectedIssueType = AppConstants.issueTypes.first;
  String _selectedSeverity = 'Medium';
  final _locationInsideBuildingController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<GrievanceProvider>(context, listen: false);
      if (prov.buildings.isEmpty) {
        prov.fetchBuildings();
      }
    });
  }

  @override
  void dispose() {
    _locationInsideBuildingController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// STRICT RULE (Spec 6.3): Camera ONLY — no gallery/file upload.
  Future<void> _capturePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() {
          _capturedImage = File(picked.path);
        });

        // Silently extract GPS coordinates in background without showing to user
        _silentFetchGps();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _silentFetchGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _gpsLat = position.latitude;
        _gpsLng = position.longitude;
      }
    } catch (_) {
      // Fallback: gracefully continue if location fails or is unavailable
    }
  }

  Future<void> _submitReport() async {
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo is required. Please capture a photo with the camera.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building from the dropdown.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Spec Rule: Description required when Issue Type = "Others"
    if (_selectedIssueType == 'Others' && _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Issue Description is required when Issue Type is "Others".'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prov = Provider.of<GrievanceProvider>(context, listen: false);
    final success = await prov.submitGrievance(
      imageFile: _capturedImage!,
      buildingId: _selectedBuildingId!,
      issueType: _selectedIssueType,
      severity: _selectedSeverity,
      description: _descriptionController.text.trim(),
      locationText: _locationInsideBuildingController.text.trim(),
      isAnonymous: _isAnonymous,
      latitude: _gpsLat,
      longitude: _gpsLng,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grievance reported successfully! Our team will triage it.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.errorMessage ?? 'Failed to submit grievance.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<GrievanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Camera Capture Box (CAMERA ONLY)
                const Text(
                  'Take Photo of the Problem *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _capturePhoto,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _capturedImage != null ? AppTheme.primaryBlue : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: _capturedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_capturedImage!, fit: BoxFit.cover),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 36,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to open Camera',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Live camera photo only (gallery not allowed)',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Issue Type Dropdown
                const Text(
                  'Issue Type *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedIssueType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: AppConstants.issueTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(AppConstants.getIssueIcon(type), size: 20, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Text(type),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedIssueType = val);
                  },
                ),
                const SizedBox(height: 20),

                // Building Dropdown (Admin managed from database)
                const Text(
                  'Campus Building *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedBuildingId,
                  hint: const Text('Select campus building'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.apartment),
                  ),
                  items: prov.buildings.map((BuildingModel b) {
                    return DropdownMenuItem<int>(
                      value: b.id,
                      child: Text('${b.name} (${b.code})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBuildingId = val),
                  validator: (val) => val == null ? 'Please select a building' : null,
                ),
                const SizedBox(height: 20),

                // Location inside building (Optional)
                const Text(
                  'Location inside Building (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationInsideBuildingController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 2nd Floor, Room 204, East Restroom',
                    prefixIcon: Icon(Icons.pin_drop_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // Severity Picker (Low, Medium, High)
                const Text(
                  'Severity *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: AppConstants.severities.map((sev) {
                    final isSelected = _selectedSeverity == sev;
                    final sevColor = AppConstants.getSeverityColor(sev);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              sev,
                              style: TextStyle(
                                color: isSelected ? Colors.white : sevColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: sevColor,
                          backgroundColor: sevColor.withOpacity(0.1),
                          side: BorderSide(color: sevColor),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedSeverity = sev);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Issue Description
                Row(
                  children: [
                    const Text(
                      'Issue Description',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (_selectedIssueType == 'Others')
                      const Text(
                        ' * (Required for Others)',
                        style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    else
                      Text(
                        ' (Optional)',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _selectedIssueType == 'Others'
                        ? 'Please specify details of the problem...'
                        : 'Describe the issue (optional)...',
                  ),
                  validator: (val) {
                    if (_selectedIssueType == 'Others' && (val == null || val.trim().isEmpty)) {
                      return 'Description is required when Issue Type is "Others"';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Report Anonymously Checkbox
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Report Anonymously', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                      'Hides your name and contact info from engineer dashboards.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isAnonymous,
                    onChanged: (val) => setState(() => _isAnonymous = val ?? false),
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                ElevatedButton(
                  onPressed: prov.isLoading ? null : _submitReport,
                  child: prov.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Grievance Report'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
