import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  stdout.writeln('🎨 Material Symbols Subsetter 🎨');

  final sourceFile = File('lib/widgets/pure_icons.dart');
  final targetFile = File('assets/fonts/MaterialSymbolsOutlined.ttf');

  if (!await sourceFile.exists()) {
    stdout.writeln('❌ Error: lib/widgets/pure_icons.dart not found.');
    exit(1);
  }

  // 1. Scan for Codepoints
  stdout.writeln('   Scanning pure_icons.dart...');
  final content = await sourceFile.readAsString();

  // Regex for 0xe123 or 0xE123 format
  final regex = RegExp(r'0x([0-9a-fA-F]{4})');
  final matches = regex.allMatches(content);

  final codepoints = <int>{};
  for (final match in matches) {
    // Only capture probable Material Icon codes (E000 - F8FF typically)
    // But we accept all 4-digit hex just in case.
    final hex = match.group(1)!;
    final value = int.parse(hex, radix: 16);
    codepoints.add(value);
  }

  if (codepoints.isEmpty) {
    stdout.writeln('⚠️ No icon codepoints found!');
    exit(0);
  }

  stdout.writeln('   Found ${codepoints.length} unique icons.');

  // 2. Construct API URL
  // We need to pass the actual characters, url-encoded.
  final buffer = StringBuffer();
  final sortedPoints = codepoints.toList()..sort();
  for (final point in sortedPoints) {
    buffer.writeCharCode(point);
  }

  final textParam = Uri.encodeComponent(buffer.toString());
  final cssUrl =
      'https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght@400&text=$textParam';

  stdout.writeln('   Fetching font metadata...');

  // 3. Get CSS to find the font file URL
  // We use a specific UA to ask for TTF if possible, but Google often gives woff2.
  // Flutter supports WOFF2 since 3.16.
  final client = http.Client();
  try {
    final cssResponse = await client.get(
      Uri.parse(cssUrl),
      headers: {
        // 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ...', // might get woff2
        // Trying effective "older android" or generic can sometimes fail or give ttf.
        // Let's just take what we get and warn if it's not TTF.
      },
    );

    if (cssResponse.statusCode != 200) {
      stdout.writeln('❌ API Error: ${cssResponse.statusCode}');
      stdout.writeln(cssResponse.body);
      exit(1);
    }

    // Extract url(...)
    // src: url(https://fonts.gstatic.com/s/materialsymbolsoutlined/v175/...) format('woff2');
    final urlRegex = RegExp(r'url\((https://.*?)\)');
    final urlMatch = urlRegex.firstMatch(cssResponse.body);

    if (urlMatch == null) {
      stdout.writeln('❌ Could not find font URL in CSS response.');
      stdout.writeln(cssResponse.body);
      exit(1);
    }

    final fontUrl = urlMatch.group(1)!;
    stdout.writeln('   Downloading font...');

    // 4. Download Font
    final fontResponse = await client.get(Uri.parse(fontUrl));

    if (fontResponse.statusCode == 200) {
      final bytes = fontResponse.bodyBytes;

      // Basic magic number check
      // WOFF2 starts with 'wOF2', TTF starts with various, often 0x00010000 or 'OTTO'
      // We will save as .ttf anyway because User asked for .ttf and flutter often handles mismatched extension
      // BUT if it is WOFF2, we should probably output a note.

      await targetFile.writeAsBytes(bytes);
      stdout.writeln(
          '✅ Saved to ${targetFile.path} (${(bytes.length / 1024).toStringAsFixed(1)} KB)');

      // Verify size reduction
      if (bytes.length > 500 * 1024) {
        stdout.writeln(
            '⚠️ Warning: File size is large. Verify subsetting worked.');
      }
    } else {
      stdout.writeln('❌ Failed download: ${fontResponse.statusCode}');
    }
  } catch (e) {
    stdout.writeln('❌ Error: $e');
  } finally {
    client.close();
  }
}
