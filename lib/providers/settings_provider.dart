import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isSyncing = false;
  bool _isBackingUp = false;
  int _selectedShift = 2;
  bool _isEditingProfile = false;
  bool _isEditingSettings = false;
  bool _isLoaded = false;
  DateTime? _syncCooldownUntil;
  DateTime? _lastBackupTime;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;

  bool get isBackingUp => _isBackingUp;

  int get selectedShift => _selectedShift;

  bool get isEditingProfile => _isEditingProfile;

  bool get isEditingSettings => _isEditingSettings;

  bool get isLoaded => _isLoaded;

  DateTime? get syncCooldownUntil => _syncCooldownUntil;

  DateTime? get lastBackupTime => _lastBackupTime;

  DateTime? get lastSyncTime => _lastSyncTime;

  void setLoaded(bool value) {
    _isLoaded = value;
    notifyListeners();
  }

  void setEditingProfile(bool value) {
    _isEditingProfile = value;
    notifyListeners();
  }

  void setEditingSettings(bool value) {
    _isEditingSettings = value;
    notifyListeners();
  }

  void setSelectedShift(int value) {
    _selectedShift = value;
    notifyListeners();
  }

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  void setBackingUp(bool value) {
    _isBackingUp = value;
    notifyListeners();
  }

  void setSyncCooldownUntil(DateTime? value) {
    _syncCooldownUntil = value;
    notifyListeners();
  }

  void setLastBackupTime(DateTime? value) {
    _lastBackupTime = value;
    notifyListeners();
  }

  void setLastSyncTime(DateTime? value) {
    _lastSyncTime = value;
    notifyListeners();
  }

  void initializeScreenState({required int shiftCount}) {
    _isEditingProfile = false;
    _isEditingSettings = false;
    _selectedShift = shiftCount;
    _isLoaded = true;
    notifyListeners();
  }

  void clearEditingStateSilent() {
    _isEditingProfile = false;
    _isEditingSettings = false;
  }

  void markChanged() {
    notifyListeners();
  }
}
