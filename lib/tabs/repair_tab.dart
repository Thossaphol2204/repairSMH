import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class RepairTab extends StatefulWidget {
  @override
  _RepairTabState createState() => _RepairTabState();
}

class _RepairTabState extends State<RepairTab> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _reporterNameController = TextEditingController();
  final _machineIdController = TextEditingController();
  final _problemDescriptionController = TextEditingController();
  String _selectedRepairType = 'แจ้งซ่อม';
  String _urgency = 'ไม่ด่วน';
  String? _selectedDepartment;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _repairTypes = ['แจ้งซ่อม', 'แจ้งสร้าง'];
  final List<String> _urgencyLevels = ['ไม่ด่วน', 'ด่วนมาก'];

  final List<String> _departments = [
    'แผนกผลิต',
    'แผนกวิศวกรรม',
    'แผนกอาดี',
    'แผนกคลังสินค้า',
    'แผนกขนส่ง',
    'แผนกจัดซื้อ',
    'แผนกการตลาดในประเทศ',
    'แผนกการตลาดต่างประเทศ',
  ];

  final ImagePicker _picker = ImagePicker();
  List<File> _images = [];

  // Machine data state
  Map<String, List<Map<String, String>>> _machinesByZone = {};
  bool _isMachinesLoading = true;
  String? _fetchError;

  // Selected zone and machine
  String? _selectedZone;
  String? _selectedMachineId;
  String? _selectedMachineName;
  final TextEditingController _machineSearchController = TextEditingController();
  List<Map<String, String>> _filteredMachines = [];

  // Cache variables
  DateTime? _lastUpdated;
  static const String _lastUpdatedKey = 'last_updated';
  static const String _machinesCacheKey = 'machines_cache';

  final FocusNode _machineSearchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCachedMachines();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  Future<void> _loadCachedMachines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_machinesCacheKey);
      final lastUpdated = prefs.getString(_lastUpdatedKey);

      if (cachedData != null) {
        final decodedData = jsonDecode(cachedData);
        setState(() {
          _machinesByZone = Map<String, List<Map<String, String>>>.from(
            decodedData.map(
              (k, v) => MapEntry(
                k,
                List<Map<String, String>>.from(
                  v.map((x) => Map<String, String>.from(x)),
                ),
              ),
            ),
          );
          _isMachinesLoading = false;
        });
      }

      if (lastUpdated != null) {
        _lastUpdated = DateTime.parse(lastUpdated);
      }

      // ดึงข้อมูลจาก API ถ้าแคชเก่าเกิน 1 วันหรือไม่มีแคช
      final now = DateTime.now();
      if (_lastUpdated == null || 
          now.difference(_lastUpdated!) > Duration(days: 1)) {
        await _fetchAndProcessMachines();
      }
    } catch (e) {
      print('Error loading cached machines: $e');
      // ถ้าโหลดจากแคชไม่ได้ ให้ดึงจาก API ใหม่
      await _fetchAndProcessMachines();
    }
  }

  Future<void> _fetchAndProcessMachines() async {
    try {
      if (mounted) {
        setState(() {
          _isMachinesLoading = true;
          _fetchError = null;
        });
      }

      final response = await http.get(Uri.parse(
          'https://script.google.com/macros/s/AKfycbwvfUY_5R2RNz9VrQYn-vaaH5vpVsbPBPA_h-Q0qQEwyQ_ErOjLjdS_bg3SFXo4N87a/exec'));

      if (response.statusCode == 200) {
        final List<dynamic> machineData =
            jsonDecode(utf8.decode(response.bodyBytes));
        final Map<String, List<Map<String, String>>> machinesByZone = {};

        for (var machine in machineData) {
          final String rawZoneId = machine['ZoneID'] ?? '';
          if (rawZoneId.isNotEmpty && rawZoneId.startsWith('Z00')) {
            final zoneKey = int.tryParse(rawZoneId.substring(3))?.toString();
            if (zoneKey != null) {
              if (!machinesByZone.containsKey(zoneKey)) {
                machinesByZone[zoneKey] = [
                  {'id': 'ไม่มีรหัส', 'name': 'ไม่มีเครื่อง', 'zone': 'Z00$zoneKey'}
                ];
              }
              machinesByZone[zoneKey]!.add({
                'id': machine['MachineID'] ?? 'ไม่มีรหัส',
                'name': machine['MachineName'] ?? 'ไม่มีชื่อ',
                'zone': rawZoneId,
              });
            }
          }
        }

        for (int i = 1; i <= 6; i++) {
          String zoneKey = i.toString();
          if (!machinesByZone.containsKey(zoneKey)) {
            machinesByZone[zoneKey] = [
              {'id': 'ไม่มีรหัส', 'name': 'ไม่มีเครื่อง', 'zone': 'Z00$zoneKey'}
            ];
          }
        }

        // บันทึกข้อมูลลงแคช
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_machinesCacheKey, jsonEncode(machinesByZone));
        await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());

        if (mounted) {
          setState(() {
            _machinesByZone = machinesByZone;
            _lastUpdated = DateTime.now();
            _isMachinesLoading = false;
          });
        }
      } else {
        throw Exception('ไม่สามารถโหลดข้อมูลได้: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = 'เกิดข้อผิดพลาดในการโหลดข้อมูลเครื่องจักร: $e';
          _isMachinesLoading = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final now = DateTime.now();
        final ticketId =
            'SMH${DateFormat('yyyyMMdd').format(now)}-${now.millisecondsSinceEpoch.toString().substring(8)}';

        // แปลงรูปภาพเป็น base64 และเตรียมชื่อไฟล์
        String? qrBase64;
        String? qrFilename;
        if (_images.isNotEmpty) {
          final bytes = await _images[0].readAsBytes();
          qrBase64 = base64Encode(bytes);
          qrFilename = 'qr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }

        final Map<String, dynamic> data = {
          "เลขที่ใบแจ้งซ่อม": ticketId,
          "Qrเครื่องจักร": qrBase64 ?? "",
          "Qrเครื่องจักร_filename": qrFilename ?? "",
          "วันที่แจ้ง": DateFormat('yyyy-MM-dd').format(now),
          "ชื่อผู้แจ้ง": _reporterNameController.text,
          "แผนก": _selectedDepartment,
          "MachineName": _machineSearchController.text,
          "MachineID": _machineIdController.text,
          "รายละเอียด": _problemDescriptionController.text,
          "ประเภทการแจ้ง": _selectedRepairType,
          "ประเภทงาน": _urgency,
          "สถานะ": "รอดำเนินการ",
        };

        final response = await http.post(
          Uri.parse(
            'https://script.google.com/macros/s/AKfycbxo4DJNNxidHRdd22TluoGZbI_-iNoRaFfwrBMoz04SEsAP5zEWlPkEIFYRcTobuNcf/exec',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );

        final isSuccess =
            (response.statusCode == 200 || response.statusCode == 302) ||
                (response.body.contains('"status":"success"')) ||
                (response.body.toLowerCase().contains('success'));

        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บันทึกข้อมูลแจ้งซ่อมสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
          // log การแจ้งซ่อม
          final prefs = await SharedPreferences.getInstance();
          final userName = prefs.getString('userName') ?? _reporterNameController.text.trim() ?? 'ไม่ระบุ';
          await logWorkOrderAction(
            workOrderId: ticketId,
            user: userName,
            action: 'create_ticket',
            oldStatus: '',
            newStatus: 'รอดำเนินการ',
            comment: 'แจ้งซ่อม: ${_problemDescriptionController.text}',
          );
          _clearForm();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showConfirmDialog(BuildContext mainContext) async {
    await showDialog(
      context: mainContext,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.build_circle, color: Color(0xFF667eea), size: 48),
                SizedBox(height: 12),
                Text(
                  'ยืนยันการส่งคำขอแจ้งซ่อม',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF1A237E),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Divider(),
                SizedBox(height: 8),
                ...[
                  _buildConfirmRow('ชื่อผู้แจ้ง', _reporterNameController.text),
                  _buildConfirmRow('แผนก', _selectedDepartment ?? '-'),
                  _buildConfirmRow('โซน', _selectedZone != null ? 'โซน $_selectedZone' : '-'),
                  _buildConfirmRow('ชื่อเครื่องจักร', _machineSearchController.text),
                  _buildConfirmRow('รหัสเครื่องจักร', _machineIdController.text),
                  _buildConfirmRow('ประเภทการแจ้ง', _selectedRepairType),
                  _buildConfirmRow('ความเร่งด่วน', _urgency),
                  _buildConfirmRow('รายละเอียด', _problemDescriptionController.text),
                ],
                SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('ยกเลิก'),
                      onPressed: () {
                         Navigator.of(dialogContext).pop();
                      },
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text('ยืนยัน', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                         Navigator.of(dialogContext).pop();
                         Future.delayed(Duration(milliseconds: 100), () {
                           _submitForm();
                         });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _clearForm() {
    _reporterNameController.clear();
    _machineIdController.clear();
    _problemDescriptionController.clear();
    _machineSearchController.clear();
    setState(() {
      _selectedRepairType = 'แจ้งซ่อม';
      _urgency = 'ไม่ด่วน';
      _selectedDepartment = null;
      _selectedZone = null;
      _selectedMachineId = null;
      _selectedMachineName = null;
      _filteredMachines.clear();
      _images.clear();
    });
  }

  Widget _buildAnimatedCard({required Widget child, required int delay}) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + (delay * 100)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        final clampedOpacity = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - clampedOpacity)),
          child: Opacity(opacity: clampedOpacity, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    VoidCallback? onEditingComplete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
              hintText: hintText,
            ),
            validator: validator,
            onEditingComplete: onEditingComplete,
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: TextStyle(fontSize: 16)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'กรุณาเลือกแผนก';
              }
              return null;
            },
            hint: Text('กรุณาเลือกแผนก',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBox(
    String title,
    String selectedValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = option == selectedValue;
              return GestureDetector(
                onTap: () => onChanged(option),
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF1A237E) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? Color(0xFF1A237E)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _selectZone(String zone) {
    setState(() {
      _selectedZone = zone;
      _selectedMachineId = null;
      _selectedMachineName = null;
      _machineIdController.clear();
      _machineSearchController.clear();
      final searchText = _machineSearchController.text;
      final allMachines = _machinesByZone[zone] ?? [];
      if (searchText.isEmpty) {
        _filteredMachines = allMachines;
      } else {
        _filteredMachines = allMachines.where((machine) {
          final name = machine['name']?.toLowerCase() ?? '';
          final id = machine['id']?.toLowerCase() ?? '';
          final search = searchText.toLowerCase();
          return name.contains(search) || id.contains(search);
        }).toList();
      }
    });
  }

  void _filterMachines(String searchText) {
    if (_selectedZone != null) {
      final allMachines = _machinesByZone[_selectedZone] ?? [];
      setState(() {
        if (searchText.isEmpty) {
          _filteredMachines = allMachines;
        } else {
          _filteredMachines = allMachines.where((machine) {
            final name = machine['name']?.toLowerCase() ?? '';
            final id = machine['id']?.toLowerCase() ?? '';
            final search = searchText.toLowerCase();
            return name.contains(search) || id.contains(search);
          }).toList();
        }
      });
    }
  }

  void _selectMachine(String machineId) {
    if (_selectedZone != null) {
      final machines = _machinesByZone[_selectedZone]!;
      final selectedMachine =
          machines.firstWhere((machine) => machine['id'] == machineId);

      setState(() {
        _selectedMachineId = machineId;
        _selectedMachineName = selectedMachine['name'];
        _machineIdController.text = machineId;
        _machineSearchController.text = selectedMachine['name']!;
      });
    }
  }

  void _clearMachineSelection() {
    setState(() {
      _selectedMachineId = null;
      _selectedMachineName = null;
      _machineIdController.clear();
      _machineSearchController.clear();
      if (_selectedZone != null) {
        _filteredMachines = List<Map<String, String>>.from(_machinesByZone[_selectedZone] ?? []);
      } else {
        _filteredMachines.clear();
      }
    });
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: Icon(Icons.refresh),
      onPressed: () async {
        await _fetchAndProcessMachines();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปเดตข้อมูลเครื่องจักรเรียบร้อย'),
            backgroundColor: Colors.green,
          ),
        );
      },
      tooltip: 'อัปเดตข้อมูลเครื่องจักร',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
        ),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final animationValue =
                              _animationController.value.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - animationValue)),
                            child: Opacity(
                              opacity: animationValue,
                              child: Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF667eea).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.build_circle,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'แบบฟอร์มแจ้งซ่อมเครื่องจักร',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'กรอกข้อมูลเพื่อแจ้งซ่อมอุปกรณ์',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24),
                      _buildAnimatedCard(
                        delay: 1,
                        child: _buildModernTextField(
                          controller: _reporterNameController,
                          label: 'ชื่อผู้แจ้ง',
                          icon: Icons.person_outline,
                          hintText: 'กรอกชื่อ-นามสกุลของคุณ',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอกชื่อผู้แจ้ง';
                            }
                            return null;
                          },
                          onEditingComplete: () => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildAnimatedCard(
                        delay: 2,
                        child: _buildModernDropdown(
                          label: 'แผนก',
                          value: _selectedDepartment,
                          items: _departments,
                          icon: Icons.business_outlined,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedDepartment = value;
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildAnimatedCard(
                        delay: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เลือกโซน',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Container(
                              height: 45,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 6,
                                itemBuilder: (context, index) {
                                  final zone = '${index + 1}';
                                  final isSelected = _selectedZone == zone;
                                  return GestureDetector(
                                    onTap: () => _selectZone(zone),
                                    child: Container(
                                      margin: EdgeInsets.only(right: 8),
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Color(0xFF1A237E)
                                            : Colors.white,
                                        border: Border.all(
                                          color: isSelected
                                              ? Color(0xFF1A237E)
                                              : Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'โซน $zone',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildAnimatedCard(
                        delay: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ชื่อเครื่องจักร',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            if (_isMachinesLoading)
                              Center(child: CircularProgressIndicator())
                            else if (_fetchError != null)
                              Center(
                                  child: Text(_fetchError!,
                                      style: TextStyle(color: Colors.red)))
                            else ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextFormField(
                                  focusNode: _machineSearchFocusNode,
                                  controller: _machineSearchController,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: InputBorder.none,
                                    hintText: _selectedZone != null
                                        ? 'พิมพ์ค้นหาเครื่องจักร...'
                                        : 'กรุณาเลือกโซนก่อน',
                                    suffixIcon: _selectedZone != null
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildRefreshButton(),
                                              IconButton(
                                                icon: Icon(Icons.clear),
                                                tooltip: 'เคลียร์',
                                                onPressed: _clearMachineSelection,
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                  onChanged: _filterMachines,
                                  enabled: _selectedZone != null,
                                  validator: (value) {
                                    if (_selectedMachineId == null &&
                                        _selectedZone != null) {
                                      return 'กรุณาเลือกเครื่องจักรจากรายการ';
                                    }
                                    return null;
                                  },
                                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                                ),
                              ),
                              if (_selectedZone != null &&
                                  _filteredMachines.isNotEmpty &&
                                  _selectedMachineId == null) ...[
                                SizedBox(height: 8),
                                Container(
                                  constraints: BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredMachines.length,
                                    itemBuilder: (context, index) {
                                      final machine = _filteredMachines[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          machine['name'] ?? '',
                                          style: TextStyle(
                                              fontSize: 14, fontFamily: 'Kanit'),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'รหัส: ${machine['id']}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600]),
                                        ),
                                        onTap: () =>
                                            _selectMachine(machine['id']!),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ]
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildAnimatedCard(
                        delay: 5,
                        child: _buildModernTextField(
                          controller: _machineIdController,
                          label: 'รหัสเครื่องจักร',
                          icon: Icons.qr_code_outlined,
                          hintText: 'กรอกอัตโนมัติ',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณาเลือกรหัสเครื่องจักร';
                            }
                            return null;
                          },
                          onEditingComplete: () => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildSelectionBox(
                        'ประเภทการแจ้ง',
                        _selectedRepairType,
                        _repairTypes,
                        (value) => setState(() => _selectedRepairType = value),
                      ),
                      SizedBox(height: 16),
                      _buildSelectionBox(
                        'ความเร่งด่วน',
                        _urgency,
                        _urgencyLevels,
                        (value) => setState(() => _urgency = value),
                      ),
                      SizedBox(height: 16),
                      _buildAnimatedCard(
                        delay: 7,
                        child: _buildModernTextField(
                          controller: _problemDescriptionController,
                          label: 'รายละเอียดปัญหา',
                          icon: Icons.description_outlined,
                          maxLines: 4,
                          hintText: 'อธิบายอาการหรือปัญหาที่พบ',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอกรายละเอียดปัญหา';
                            }
                            return null;
                          },
                          onEditingComplete: () => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'รูปภาพประกอบ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _images.length) {
                              return GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 100,
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.add_a_photo, size: 40),
                                ),
                              );
                            }
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_images[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 32),
                      _buildAnimatedCard(
                        delay: 8,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey[400]!, Colors.grey[500]!]
                                  : [Color(0xFF667eea), Color(0xFF764ba2)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_isLoading ? Colors.grey : Color(0xFF667eea))
                                    .withOpacity(0.3),
                                blurRadius: 15,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _showConfirmDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'กำลังบันทึก...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'ส่งคำขอแจ้งซ่อม',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reporterNameController.dispose();
    _machineIdController.dispose();
    _problemDescriptionController.dispose();
    _machineSearchController.dispose();
    _machineSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> logWorkOrderAction({
    required String workOrderId,
    required String user,
    required String action,
    String? oldStatus,
    String? newStatus,
    String? comment,
  }) async {
    final url = 'https://script.google.com/macros/s/AKfycby5qGKd5XfKAeXj_CjzrIJHEJURdnq3jxD9HeP7CII-aQ616_Q8h0EC_B_nWhwslsxZ/exec';
    await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'workOrderId': workOrderId,
        'timestamp': DateTime.now().toIso8601String(),
        'user': user,
        'action': action,
        'oldStatus': oldStatus ?? '',
        'newStatus': newStatus ?? '',
        'comment': comment ?? '',
      }),
    );
  }
}