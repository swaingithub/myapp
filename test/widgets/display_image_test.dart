
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchar_messaging_app/widgets/display_image.dart';

void main() {
  group('DisplayImage', () {
    testWidgets('shows placeholder when path is null', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DisplayImage(path: null),
      ));

      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    });

    testWidgets('shows placeholder when path is empty', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DisplayImage(path: ''),
      ));

      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    });

    testWidgets('shows custom placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DisplayImage(
          path: null,
          placeholder: Text('Custom Placeholder'),
        ),
      ));

      expect(find.text('Custom Placeholder'), findsOneWidget);
    });

    testWidgets('renders base64 image', (WidgetTester tester) async {
      // 1x1 transparent pixel png
      final String base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      
      await tester.pumpWidget(MaterialApp(
        home: DisplayImage(path: base64Image),
      ));

      expect(find.byType(Image), findsOneWidget);
      // We can't easily verify the content of the image without golden tests, but finding the Image widget is a good start.
    });

    testWidgets('applies border radius', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DisplayImage(path: '', radius: 10),
      ));

      // Even with placeholder, if radius > 0, it wraps in Container with decoration or ClipRRect?
      // In the code:
      // if (radius > 0) return ClipRRect(...)
      // But wait, if path is null/empty, it returns _buildPlaceholder(context).
      // _buildPlaceholder returns a Container with borderRadius.
      // So ClipRRect is ONLY used if imageWidget is created (path is not null/empty).
      
      // Let's test with a valid image path to see ClipRRect
      final String base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      
      await tester.pumpWidget(MaterialApp(
        home: DisplayImage(path: base64Image, radius: 10),
      ));

      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });
}
