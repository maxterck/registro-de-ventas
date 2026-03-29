class EmployeeSession {
  final String keyId;
  final String storeId;
  final String role;
  final String employeeName;
  final bool canManageProducts;
  final bool canSettleDebts;
  final bool requiresShiftControl;

  EmployeeSession({
    required this.keyId,
    required this.storeId,
    required this.role,
    required this.employeeName,
    this.canManageProducts = false,
    this.canSettleDebts = false,
    this.requiresShiftControl = false,
  });
}
