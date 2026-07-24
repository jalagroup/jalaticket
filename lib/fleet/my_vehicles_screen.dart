import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models.dart' show UserModel;
import 'fleet_models.dart';
import 'fleet_service.dart';
import 'fleet_vehicle_detail_screen.dart';

/// Driver-facing view of just the vehicles the current user is assigned to
/// — no admin controls, just warnings + check-in/out, for users who don't
/// have full Fleet Access.
class MyVehiclesScreen extends StatefulWidget {
  final UserModel currentUser;
  const MyVehiclesScreen({super.key, required this.currentUser});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  List<FleetVehicle> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vehicles = await FleetService.getVehiclesForUser(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openVehicle(FleetVehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FleetVehicleDetailScreen(vehicle: vehicle, currentUser: widget.currentUser, canManage: false),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text(isAr ? 'مركباتي' : 'My Vehicles', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _vehicles.isEmpty
              ? Center(
                  child: Text(isAr ? 'لا توجد مركبات مخصصة لك' : 'No vehicles assigned to you', style: TextStyle(color: Colors.grey[500])),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, i) {
                      final v = _vehicles[i];
                      final warnings = generateFleetAlerts([v], const [], isAr: isAr);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openVehicle(v),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(v.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(
                                        [if (v.vehicleType.isNotEmpty) v.vehicleType, '${fleetFormatNumber(v.currentOdometer)} ${isAr ? 'كم' : 'km'}'].join(' · '),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (warnings.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text('${warnings.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                  ),
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
