import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_api.dart';

class AdminServices {
  const AdminServices(this.adminSession);
  final MobileAdminSession adminSession;
}

final servicesProvider = Provider<AdminServices>(
  (ref) => throw StateError('AdminServices must be provided at startup'),
);
