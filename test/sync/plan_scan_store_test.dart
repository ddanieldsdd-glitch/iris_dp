import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/media_entity_types.dart';
import 'package:iris_dp/core/sync/media_slots.dart';
import 'package:iris_dp/core/sync/plan_scan_store.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_store.dart';

void main() {
  test('la clave es el nombre que guarda la planta, sin carpetas', () {
    final name = ScanStore.newName('C:/Capturas/Salón RealityScan.GLB');
    expect(name, endsWith('.glb'));
    expect(PlanScanStore.isKey(name), isTrue);
    expect(PlanScanStore.isKey('../../secreto.glb'), isFalse);
    expect(PlanScanStore.isKey(r'scans\a.glb'), isFalse);
    expect(PlanScanStore.isKey('abc.usdz'), isFalse);
  });

  test('lo que pesa más que el límite de la nube no se sube', () {
    expect(PlanScanStore.fitsCloud(MediaSlot.maxFileBytes), isTrue);
    expect(PlanScanStore.fitsCloud(MediaSlot.maxFileBytes + 1), isFalse);
    expect(MediaEntityType.planScan, 'plan_scan');
  });
}
