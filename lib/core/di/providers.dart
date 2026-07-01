import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../config/app_config.dart';
import '../../data/local/database/app_database.dart';
import '../../data/local/file_storage_service.dart';
import '../../data/repositories/recent_files_repository.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../../domain/entities/recent_file.dart';
import '../../domain/entities/scan_page.dart';
import '../../services/monetization/ad_service.dart';
import '../../services/monetization/admob_ad_service.dart';
import '../../services/monetization/billing_service.dart';
import '../../services/monetization/play_billing_service.dart';
import '../../services/pdf/pdf_job_runner.dart';
import '../../services/pdf/pdf_processing_service.dart';
import '../../services/pdf/pdf_service.dart';
import '../../services/scan/page_enhancer.dart';
import '../../services/scan/scan_service.dart';
import '../../services/share/share_service.dart';
import '../../services/storage/file_save_service.dart';
import '../../services/storage/recent_files_service.dart';
import '../../services/storage/storage_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fileStorageProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

final fileSaveServiceProvider = Provider<FileSaveService>((ref) {
  return FileSaveService();
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository();
});

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

final pdfProcessingServiceProvider = Provider<PdfProcessingService>((ref) {
  return PdfProcessingService(
    ref.watch(pdfServiceProvider),
    ref.watch(fileSaveServiceProvider),
  );
});

final pdfJobRunnerProvider = Provider<PdfJobRunner>((ref) => PdfJobRunner());

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

final pageEnhancerProvider = Provider<PageEnhancer>((ref) => PageEnhancer());

final scanServiceProvider = Provider<ScanService>((ref) {
  if (Platform.isAndroid) {
    return CunningDocumentScanService();
  }
  return StubScanService();
});

final recentFilesRepositoryProvider = Provider<RecentFilesRepository>((ref) {
  return RecentFilesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStorageProvider),
    ref.watch(pdfServiceProvider),
  );
});

final recentFilesServiceProvider = Provider<RecentFilesService>((ref) {
  return RecentFilesService(ref.watch(recentFilesRepositoryProvider));
});

final recentFilesStreamProvider = StreamProvider<List<RecentFileItem>>((ref) {
  return ref.watch(recentFilesRepositoryProvider).watchRecentFiles();
});

final adServiceProvider = Provider<AdService>((ref) {
  AdService service;
  if (AppConfig.enableAds) {
    service = AdMobAdService();
  } else {
    service = NoOpAdService();
  }
  ref.onDispose(service.dispose);
  return service;
});

final billingServiceProvider = Provider<BillingService>((ref) {
  BillingService service;
  if (AppConfig.enableBilling) {
    service = PlayBillingService();
  } else {
    service = NoOpBillingService();
  }
  ref.onDispose(service.dispose);
  return service;
});

final adsEnabledProvider = FutureProvider<bool>(
  (ref) => AppConfig.adsEnabled(),
);

final billingEnabledProvider = FutureProvider<bool>(
  (ref) => AppConfig.billingEnabled(),
);

class PdfJobNotifier extends StateNotifier<PdfJobProgress> {
  PdfJobNotifier(this._runner)
    : super(const PdfJobProgress(status: PdfJobStatus.idle));

  final PdfJobRunner _runner;

  void cancel() => _runner.cancel();

  void reset() {
    _runner.reset();
    state = const PdfJobProgress(status: PdfJobStatus.idle);
  }

  Future<T?> execute<T>(
    Future<T> Function(PdfProgressReporter reporter) task,
  ) async {
    final controller = StreamController<PdfJobProgress>();
    final sub = controller.stream.listen((progress) => state = progress);

    try {
      return await _runner.run(progress: controller, task: task);
    } on StateError catch (e) {
      if (e.message == 'cancelled') {
        state = const PdfJobProgress(status: PdfJobStatus.cancelled);
      }
      return null;
    } finally {
      await sub.cancel();
      await controller.close();
    }
  }
}

final pdfJobNotifierProvider =
    StateNotifierProvider<PdfJobNotifier, PdfJobProgress>((ref) {
      return PdfJobNotifier(ref.watch(pdfJobRunnerProvider));
    });

class ScanSessionNotifier extends StateNotifier<List<ScanPage>> {
  ScanSessionNotifier() : super(const []);

  void setPages(List<ScanPage> pages) => state = pages;

  void reorder(int oldIndex, int newIndex) {
    final pages = [...state];
    final item = pages.removeAt(oldIndex);
    pages.insert(newIndex, item);
    state = pages;
  }

  void removeAt(int index) {
    final pages = [...state]..removeAt(index);
    state = pages;
  }

  void updatePage(int index, ScanPage page) {
    final pages = [...state];
    pages[index] = page;
    state = pages;
  }

  void clear() => state = const [];
}

final scanSessionProvider =
    StateNotifierProvider<ScanSessionNotifier, List<ScanPage>>((ref) {
      return ScanSessionNotifier();
    });

final selectedFeatureProvider = StateProvider<PdfFeatureType?>((ref) => null);
