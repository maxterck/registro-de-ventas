class EmployeeSession {
  final String keyId;
  final String storeId;
  final String role;
  final String employeeName;
  final bool canManageProducts;

  EmployeeSession({
    required this.keyId,
    required this.storeId,
    required this.role,
    required this.employeeName,
    this.canManageProducts = false,
  });
}
