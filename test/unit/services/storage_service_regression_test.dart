import 'helpers/storage/storage_service_additional_crud.dart'
    as additional_crud;
import 'helpers/storage/storage_service_lifecycle.dart' as lifecycle;
import 'helpers/storage/storage_service_settings_and_maintenance.dart'
    as settings_and_maintenance;

void main() {
  lifecycle.registerStorageServiceLifecycleTests();
  settings_and_maintenance.registerStorageServiceSettingsAndMaintenanceTests();
  additional_crud.registerStorageServiceAdditionalCrudTests();
}
