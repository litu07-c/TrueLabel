
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const TrueLabelApp());
}

class TrueLabelApp extends StatelessWidget {
  const TrueLabelApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrueLabel – What\'s In My Food?',
      theme: ThemeData(primarySwatch: Colors.yellow),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Product {
  final String name;
  final String image;
  final String ingredients;
  final String risks;
  Product({required this.name, required this.image, required this.ingredients, required this.risks});
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    name: json['name'],
    image: json['image'],
    ingredients: json['ingredients'],
    risks: json['risks'],
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> allProducts = [];
  List<Product> displayedProducts = [];
  late BannerAd _bannerAd;
  bool isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    loadProducts();
    _bannerAd = BannerAd(
      adUnitId: BannerAd.testAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => isAdLoaded = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  Future<void> loadProducts() async {
    final String response = await rootBundle.loadString('assets/products.json');
    final List<dynamic> data = json.decode(response);
    setState(() {
      allProducts = data.map((e) => Product.fromJson(e)).toList();
      displayedProducts = allProducts;
    });
  }

  void filterSearch(String query) {
    setState(() {
      displayedProducts = allProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void openScanner() async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen(products: [])));
  }

  void showProductDetails(Product p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(p.image, height: 100),
            const SizedBox(height: 10),
            Text("Ingredients:\n${p.ingredients}"),
            const SizedBox(height: 10),
            Text("Health Risks:\n${p.risks}", style: const TextStyle(color: Colors.red)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrueLabel'),
        actions: [
          IconButton(onPressed: openScanner, icon: const Icon(Icons.qr_code_scanner)),
        ],
      ),
      body: Column(
        children: [
          if (isAdLoaded) SizedBox(height: 50, child: AdWidget(ad: _bannerAd)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search product...', border: OutlineInputBorder()),
              onChanged: filterSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: displayedProducts.length,
              itemBuilder: (context, index) {
                final product = displayedProducts[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Image.network(product.image, width: 60, height: 60),
                    title: Text(product.name),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                      child: const Text("View"),
                      onPressed: () => showProductDetails(product),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final List<Product> products;
  const QRScannerScreen({super.key, required this.products});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  late QRViewController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: (controller) {
                this.controller = controller;
                controller.scannedDataStream.listen((scanData) {
                  setState(() => result = scanData);
                });
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: (result != null)
                  ? Text("Scanned: \${result!.code}")
                  : const Text("Scan a code"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
