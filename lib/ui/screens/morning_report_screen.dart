import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../data/providers.dart';
import '../widgets/glass_container.dart';
import '../theme/app_theme.dart';

class MorningReportScreen extends ConsumerWidget {
  const MorningReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(morningReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "DAILY DIGEST",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 14,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: reportAsync.when(
        data: (report) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Image with premium styling
                if (report.headImage.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: kIsWeb 
                      ? Image.network(
                          'https://corsproxy.io/?${Uri.encodeComponent(report.headImage)}',
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 240,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 50),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: report.headImage,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 240,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 240,
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 50),
                          ),
                        ),
                    ),
                  ),
                const SizedBox(height: 32),
                
                // Date
                Text(
                  report.date,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Weiyu (Quote) - Solid design
                Container(
                   decoration: BoxDecoration(
                     color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                   ),
                   padding: const EdgeInsets.all(20),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Icon(
                         Icons.format_quote, 
                         color: AppTheme.primaryBlue.withOpacity(0.5),
                         size: 28,
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           report.weiyu,
                           style: GoogleFonts.outfit(
                             fontSize: 16,
                             height: 1.6,
                             fontWeight: FontWeight.w500,
                             color: isDark ? Colors.white70 : Colors.black87,
                           ),
                         ),
                       ),
                     ],
                   ),
                ),
                const SizedBox(height: 40),
                
                // News Section Title
                Text(
                  "LATEST UPDATES",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 20),

                // News List
                ...report.news.map((newsItem) => Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          newsItem,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text("无法加载早报", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  err.toString(), 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(morningReportProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text("RETRY", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
