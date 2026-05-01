// lib/screens/admin/branch_admin_management.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jalasupport/branch_admin_service.dart';
import 'package:jalasupport/l10n/app_localizations.dart';
import 'package:jalasupport/main.dart';
import '../../models.dart';

class BranchAdminManagement extends StatefulWidget {
  final UserModel currentUser;

  const BranchAdminManagement({super.key, required this.currentUser});

  @override
  State<BranchAdminManagement> createState() => _BranchAdminManagementState();
}

class _BranchAdminManagementState extends State<BranchAdminManagement>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _branchAdmins = [];
  List<PlaceModel> _allPlaces = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBranchAdmins();
  }

  Future<void> _loadBranchAdmins() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final branchAdmins =
          await BranchAdminService.getAllBranchAdminsWithPlaces();
      final places = await BranchAdminService.getAllAvailablePlaces();

      if (mounted) {
        setState(() {
          _branchAdmins = branchAdmins;
          _allPlaces = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading branch admins: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.safeOf(context);
        _showError(l10n.failedToLoad);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showEditPlacesDialog(
      Map<String, dynamic> branchAdminData) async {
    final l10n = AppLocalizations.safeOf(context);
    final admin = branchAdminData['admin'] as Map<String, dynamic>;
    final currentPlaces = (branchAdminData['places'] as List<PlaceModel>)
        .map((p) => p.id)
        .toList();

    // Create a copy of current places for the dialog
    final selectedPlaces = List<String>.from(currentPlaces);

    final result = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${l10n.editPlacesFor} ${admin['full_name']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: _allPlaces.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noPlacesAvailable,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _allPlaces.length,
                    itemBuilder: (context, index) {
                      final place = _allPlaces[index];
                      final isSelected = selectedPlaces.contains(place.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            place.localizedName(Localizations.localeOf(context).languageCode),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: place.description != null
                              ? Text(
                                  place.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                )
                              : null,
                          value: isSelected,
                          activeColor: Colors.blue,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedPlaces.add(place.id);
                              } else {
                                selectedPlaces.remove(place.id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedPlaces),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l10n.save,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    // Handle the result
    if (result != null && mounted) {
      // Show loading indicator
      setState(() => _isLoading = true);

      try {
        final success = await BranchAdminService.assignPlacesToBranchAdmin(
          adminId: admin['id'] as String,
          placeIds: result,
        );

        if (success && mounted) {
          // Reload data
          await _loadBranchAdmins();

          // Show success message
          _showSuccess(l10n.placesUpdatedSuccessfully);
        } else if (mounted) {
          setState(() => _isLoading = false);
          _showError(l10n.failedToUpdatePlaces);
        }
      } catch (e) {
        print('Error updating places: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _showError('${l10n.failedToUpdatePlaces}: $e');
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBranchAdmins {
    if (_searchQuery.isEmpty) return _branchAdmins;

    return _branchAdmins.where((branchAdminData) {
      final admin = branchAdminData['admin'] as Map<String, dynamic>;
      final fullName = (admin['full_name'] as String? ?? '').toLowerCase();
      final email = (admin['email'] as String? ?? '').toLowerCase();
      final places = branchAdminData['places'] as List<PlaceModel>;
      final placesStr = places.map((p) => p.name.toLowerCase()).join(' ');
      final query = _searchQuery.toLowerCase();

      return fullName.contains(query) ||
          email.contains(query) ||
          placesStr.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.safeOf(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 992;
    final bottomNavBarHeight = isTablet && !kIsWeb ? 90.0 : 0.0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.branchAdminManagement,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_filteredBranchAdmins.length} ${l10n.total}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadBranchAdmins,
                    tooltip: l10n.refresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.branchAdminManagementDescription,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Search
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: l10n.searchBranchAdmins,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredBranchAdmins.isEmpty
                  ? SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: bottomNavBarHeight + 24,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.noBranchAdminsYet
                                  : l10n.noResultsFound,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.createBranchAdminsInUserManagement
                                  : l10n.tryAdjustingFilters,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: bottomNavBarHeight + 24,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredBranchAdmins.length,
                      itemBuilder: (context, index) {
                        final branchAdminData = _filteredBranchAdmins[index];
                        final admin =
                            branchAdminData['admin'] as Map<String, dynamic>;
                        final places =
                            branchAdminData['places'] as List<PlaceModel>;
                        final fullName =
                            admin['full_name'] as String? ?? 'Unknown';
                        final email = admin['email'] as String? ?? 'No email';
                        final isActive = admin['is_active'] as bool? ?? false;
                        final profileImageUrl =
                            admin['profile_image_url'] as String?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.deepPurple.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.deepPurple.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: profileImageUrl != null &&
                                      profileImageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        profileImageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              fullName
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isActive
                                                    ? Colors.deepPurple
                                                    : Colors.grey,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        fullName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? Colors.deepPurple
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (!isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.inactive,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: places.isEmpty
                                        ? Colors.orange.withOpacity(0.05)
                                        : Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: places.isEmpty
                                          ? Colors.orange.withOpacity(0.3)
                                          : Colors.blue.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        places.isEmpty
                                            ? Icons.location_off
                                            : Icons.location_on,
                                        size: 16,
                                        color: places.isEmpty
                                            ? Colors.orange
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          places.isEmpty
                                              ? l10n.noPlacesAssigned
                                              : '${l10n.places} (${places.length}): ${places.map((p) => p.name).join(", ")}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: places.isEmpty
                                                ? Colors.orange
                                                : Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit_location,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () =>
                                        _showEditPlacesDialog(branchAdminData),
                                tooltip: l10n.editPlaces,
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
