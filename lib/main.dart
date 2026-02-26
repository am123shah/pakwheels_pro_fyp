import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
// --- GLOBAL VARIABLE (Top of file par, main() se pehle) ---
List<Map<String, dynamic>> myCart = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NOTE: Firebase initialize karein
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // --- APNI FIREBASE KEYS YAHAN PASTE KAREIN ---
      apiKey: "AIzaSyCgy8Jp2Gm-NbJLz1y2AeicCYTgJrBPeVg",
      appId: "1:240923894586:web:7c9e7826359f9393309a48",
      messagingSenderId: "240923894586",
      projectId: "pakwheels-fyp",
      storageBucket: "pakwheels-fyp.firebasestorage.app",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PakWheels Pro',
      theme: ThemeData(
        primaryColor: const Color(0xFFB71C1C),
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: const Color(0xFFB71C1C)),
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB71C1C),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB71C1C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFB71C1C))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- 1. INTELLIGENT HELPER FUNCTIONS ---

double extractNumber(dynamic value) {
  if (value == null) return 0.0;
  String v = value.toString();
  String clean = v.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(clean) ?? 0.0;
}// Isay baaki helper functions ke sath rakhein (Line 100 ke aas paas)
Future<bool> isAdmin(String uid) async {
  try {
    var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    // Check karega agar 'isAdmin' true hai
    return doc.exists && (doc.data()!['isAdmin'] == true);
  } catch(e) { 
    return false; 
  }
}

// --- STRICT PRICE LOGIC ---
double getRealisticPrice(Map<String, dynamic> data) {
  String name = (data['name'] ?? '').toString().toLowerCase();
  
  // 1. Luxury / SUV (2.5 - 3 Crores)
  if (name.contains('land') || name.contains('cruiser') || name.contains('fortuner') || name.contains('sonata') || name.contains('haval') || name.contains('tesla') || name.contains('etron') || name.contains('prado') || name.contains('audi') || name.contains('mercedes') || name.contains('revo')) {
    return 25000000.0; 
  }
  
  // 2. Mid Range (60-80 Lacs)
  if (name.contains('civic') || name.contains('kia') || name.contains('sportage') || name.contains('tuscon') || name.contains('elantra') || name.contains('corolla') || name.contains('grande') || name.contains('yaris') || name.contains('city') || name.contains('alsvin') || name.contains('br-v')) {
    return 6500000.0; 
  }
  
  // 3. Small Cars (30-40 Lacs)
  if (name.contains('alto') || name.contains('cultus') || name.contains('mehran') || name.contains('wagon') || name.contains('daihatsu') || name.contains('mira') || name.contains('picanto') || name.contains('suzuki') || name.contains('bolan')) {
    return 3500000.0; 
  }

  // Fallback
  double dbPrice = extractNumber(data['price']);
  if (dbPrice > 500000000) return 5000000.0; 
  if (dbPrice < 500000) return 3000000.0; 
  
  return dbPrice;
}

String formatPrice(double price) {
  if (price >= 10000000) {
    return "${(price / 10000000).toStringAsFixed(2)} Crore";
  } else if (price >= 100000) {
    return "${(price / 100000).toStringAsFixed(2)} Lacs";
  }
  return price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
}

// --- RATING LOGIC ---
double calculateSmartRating(String type, Map<String, dynamic> car) {
  double score = 3.0; 
  String name = (car['name'] ?? '').toString().toLowerCase();
  double engine = extractNumber(car['engine']);
  bool isTopBrand = name.contains('toyota') || name.contains('honda') || name.contains('suzuki');
  
  if (type == 'Resale Value') {
    if (name.contains('corolla') || name.contains('civic') || name.contains('alto') || name.contains('city') || name.contains('mehran')) score = 5.0; 
    else if (isTopBrand) score = 4.5;
    else score = 3.0;
  }
  else if (type == 'Comfort Level') {
    if (getRealisticPrice(car) > 15000000) score = 5.0; 
    else if (engine >= 1800) score = 4.5; 
    else if (engine >= 1300) score = 4.0; 
    else score = 3.0; 
  }
  else if (type == 'Parts Availability') {
    if (isTopBrand) score = 5.0; 
    else score = 3.5; 
  }
  return score.clamp(1.0, 5.0);
}

// --- GLOBAL NAVIGATION ---
Future<void> openChatLogic(BuildContext context, Map<String, dynamic> carData, String currentUserId) async {
  String sellerId = (carData['userId'] ?? '').toString();
  if (sellerId == currentUserId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot buy your own car!")));
    return;
  }
  var query = await FirebaseFirestore.instance.collection('chats').where('users', arrayContains: currentUserId).get();
  DocumentReference? chatRoomRef;
  for (var doc in query.docs) {
    if ((doc['users'] as List).contains(sellerId)) {
      chatRoomRef = doc.reference;
      break;
    }
  }
  if (chatRoomRef == null) {
    chatRoomRef = await FirebaseFirestore.instance.collection('chats').add({
      'users': [currentUserId, sellerId],
      'lastMessage': 'I am interested in buying: ${carData['name']}',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'userNames': { currentUserId: 'Buyer', sellerId: 'Seller' }
    });
  }
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chatRoomRef!.id, otherUserId: sellerId)));
}

// Handles Network/Memory images for Cars
Widget buildUniversalImage(String? imagePath, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
  if (imagePath == null || imagePath.isEmpty) {
    return Container(height: height, width: width, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey, size: 40));
  }
  if (imagePath.startsWith('http')) {
    return Image.network(imagePath, height: height, width: width, fit: fit, 
      errorBuilder: (c, o, s) => Container(height: height, width: width, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey))
    );
  } 
  try {
    Uint8List bytes = base64Decode(imagePath);
    return Image.memory(bytes, height: height, width: width, fit: fit);
  } catch (e) {
    return Container(height: height, width: width, color: Colors.grey[200], child: const Icon(Icons.error, color: Colors.red));
  }
}

List<String> getImagesList(dynamic imagesData) {
  List<String> imgList = [];
  if (imagesData == null) return [];
  try {
    if (imagesData is List) {
      for(var item in imagesData) { if(item != null) imgList.add(item.toString()); }
    } else if (imagesData is Map) {
      if (imagesData['exterior'] != null && imagesData['exterior'] != '') imgList.add(imagesData['exterior']);
      if (imagesData['interior'] != null && imagesData['interior'] != '') imgList.add(imagesData['interior']);
      if (imagesData['engine'] != null && imagesData['engine'] != '') imgList.add(imagesData['engine']);
    }
  } catch (e) { print("Error parsing images: $e"); }
  return imgList;
}

// --- 2. CAR CARD (UPDATED WITH SOLD LOGIC) ---
class CarCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool showDeleteButton; // Ye batata hai ke ye "My Ad" hai ya nahi

  const CarCard({super.key, required this.data, required this.docId, this.showDeleteButton = false});

  // --- DELETE LOGIC ---
  void deleteAd(BuildContext context) async {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Ad"), content: const Text("Are you sure you want to delete this ad?"),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), TextButton(onPressed: () async { Navigator.pop(ctx); await FirebaseFirestore.instance.collection('cars').doc(docId).delete(); }, child: const Text("Delete", style: TextStyle(color: Colors.red)))]
    ));
  }

  // --- MARK AS SOLD LOGIC ---
  void markAsSold(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Mark as Sold?"),
      content: const Text("This will mark the car as SOLD. Buyers won't be able to contact you anymore.\n\nThis cannot be undone."),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: (){
          Navigator.pop(ctx);
          // Firestore update
          FirebaseFirestore.instance.collection('cars').doc(docId).update({'isSold': true});
        }, child: const Text("CONFIRM SOLD", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
      ]
    ));
  }

  void addToFavorites(BuildContext context) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) { Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); return; }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').doc(docId).set(data);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.pink, content: Text("Added to Favorites ❤️")));
  }

  void handleBuyClick(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(pendingAdData: data)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CarDetailScreen(data: data, showChatOption: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = getImagesList(data['images']);
    String thumbnail = images.isNotEmpty ? images[0] : (data['image'] ?? '');
    double priceVal = getRealisticPrice(data);
    
    // --- CHECK IF SOLD ---
    bool isSold = data['isSold'] == true;

    return GestureDetector(
      // Agar Sold hai to click kaam nahi karega (Freeze)
      onTap: isSold ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarDetailScreen(data: data, showChatOption: false))),
      child: Container(
        // Sold honay par Grey color, warna White
        decoration: BoxDecoration(
          color: isSold ? Colors.grey[300] : Colors.white, 
          borderRadius: BorderRadius.circular(15), 
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), 
                  child: ColorFiltered(
                    // Agar sold hai to Black & White filter lagado
                    colorFilter: isSold 
                        ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) 
                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                    child: SizedBox(height: 210, width: double.infinity, child: buildUniversalImage(thumbnail, fit: BoxFit.cover))
                  )
                ),
                
                // Featured Tag
                if(data['featured'] == true && !isSold) Positioned(top: 12, left: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFDAA520), borderRadius: BorderRadius.circular(20)), child: const Text("FEATURED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))),
                
                // --- SOLD OUT OVERLAY ---
                if(isSold) Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 4), borderRadius: BorderRadius.circular(10)),
                        child: const Text("SOLD OUT", style: TextStyle(color: Colors.red, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2))
                      )
                    )
                  )
                ),

                // Top Right Icons
                Positioned(top: 10, right: 10, child: Row(
                  children: [
                    // Agar ye meri ad hai aur abi tak sold nahi hui, to MARK SOLD ka button dikhao
                    if(showDeleteButton && !isSold) 
                      GestureDetector(
                        onTap: () => markAsSold(context),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                          child: const Text("Mark Sold", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                        ),
                      ),
                    
                    // Delete Button (Only for My Ads)
                    if(showDeleteButton) 
                      CircleAvatar(backgroundColor: Colors.white, radius: 16, child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => deleteAd(context)))
                    // Favorite Button (For others)
                    else if(!isSold)
                      CircleAvatar(backgroundColor: Colors.white, radius: 16, child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.favorite_border, size: 18, color: Colors.red), onPressed: () => addToFavorites(context))),
                  ],
                )),
            ]),
            
            Padding(padding: const EdgeInsets.all(15.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, decoration: isSold ? TextDecoration.lineThrough : null, color: isSold ? Colors.grey : Colors.black), maxLines: 1), 
              const SizedBox(height: 4), 
              Text("PKR ${formatPrice(priceVal)}", style: TextStyle(color: isSold ? Colors.grey : const Color(0xFFB71C1C), fontWeight: FontWeight.bold, fontSize: 20)), 
              const SizedBox(height: 10), 
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(data['city'] ?? '', style: TextStyle(color: Colors.grey[600]))]),
                  
                  // Buy Button Logic
                  if(!showDeleteButton) SizedBox(height: 35, child: ElevatedButton.icon(
                    onPressed: isSold ? null : () => handleBuyClick(context), // Disable if sold
                    icon: Icon(isSold ? Icons.lock : Icons.shopping_cart, size: 16), 
                    label: Text(isSold ? "SOLD" : "Buy"), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSold ? Colors.grey : Colors.green[700], 
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0), 
                      textStyle: const TextStyle(fontSize: 12)
                    )
                  ))
              ])
            ])),
        ]),
      ),
    );
  }
}
// --- 3. MAIN SCREEN (FIXED ADMIN PIN LOGIC) ---
class MainScreen extends StatefulWidget { const MainScreen({super.key}); @override State<MainScreen> createState() => _MainScreenState(); }
class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [const HomeScreen(), const PartsScreen(), const SellCarForm(), const ComparisonScreen()];
  
  @override Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), 
      builder: (context, snapshot) { 
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C))));
        }
        
        User? currentUser = snapshot.data; 
        return Scaffold(
          drawer: Drawer(child: Column(children: [
            const DrawerHeader(decoration: BoxDecoration(color: Color(0xFFB71C1C)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_open, color: Colors.white, size: 50), SizedBox(height: 10), Text("PakWheels Pro Menu", style: TextStyle(color: Colors.white, fontSize: 18))]))), 
            Expanded(child: ListView(padding: EdgeInsets.zero, children: [
              if(currentUser == null) ...[
                 ListTile(leading: const Icon(Icons.login), title: const Text("Login / Register"), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())); }),
              ] else ...[
                ListTile(leading: const Icon(Icons.person), title: const Text("My Profile"), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen())); }), 
                ListTile(leading: const Icon(Icons.list_alt, color: Colors.blue), title: const Text("My Ads (Mark Sold)"), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => const MyAdsScreen())); }), 
                ListTile(leading: const Icon(Icons.favorite, color: Colors.red), title: const Text("Favorites"), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => const FavoritesScreen())); }),
                ListTile(leading: const Icon(Icons.chat, color: Colors.green), title: const Text("My Chats"), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => const ChatListScreen())); }),
                const Divider(),
                
                // --- ADMIN LOGIC (FIXED) ---
                ListTile(
                  tileColor: Colors.red[50], leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFB71C1C)),
                  title: const Text("Store Manager (Admin)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
                  onTap: () {
                    Navigator.pop(context); // Drawer band
                    
                    // Controller yahan banaya taake text sahi se parh sakay
                    TextEditingController pinController = TextEditingController(); 
                    
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text("Enter Admin PIN"),
                      content: TextField(
                        controller: pinController, // Controller connect kiya
                        obscureText: true, 
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: "Enter PIN"),
                      ),
                      actions: [TextButton(onPressed: (){ 
                        // PIN CHECK (Seedha check)
                        if (pinController.text.trim() == "1234") {
                           Navigator.pop(ctx); 
                           Navigator.push(context, MaterialPageRoute(builder: (_)=>const AdminOrdersScreen()));
                        } else { 
                           Navigator.pop(ctx); 
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Wrong PIN! Try Again")));
                        }
                      }, child: const Text("UNLOCK"))]
                    ));
                  },
                ),
                // ---------------------------
              ],
            ])), 
            if(currentUser != null) ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout"), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pop(context); setState(() { _selectedIndex = 0; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged Out Successfully"))); }), const SizedBox(height: 20),
          ],),), 
          appBar: AppBar(title: const Text("PakWheels Pro")), 
          body: _screens[_selectedIndex], 
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex, 
            type: BottomNavigationBarType.fixed, selectedItemColor: const Color(0xFFB71C1C), unselectedItemColor: Colors.grey, backgroundColor: Colors.white, elevation: 10, 
            items: const [BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Buy"), BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: "Parts"), BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "Sell"), BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: "Compare")],
            onTap: (index) {
              if (index == 2 && currentUser == null) { Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen())); return; }
              setState(() => _selectedIndex = index);
            },
          ),
        ); 
      }); 
  }
}

// --- 4. COMPARISON SCREEN (FIXED & THEMED) ---
class ComparisonScreen extends StatefulWidget { const ComparisonScreen({super.key}); @override State<ComparisonScreen> createState() => _ComparisonScreenState(); }
class _ComparisonScreenState extends State<ComparisonScreen> {
  Map<String, dynamic>? car1;
  Map<String, dynamic>? car2;
  List<Map<String, dynamic>> allCars = [];
  bool isLoading = true;

  @override void initState() { super.initState(); fetchSpecsFromFirebase(); }

  void fetchSpecsFromFirebase() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('car_specs').get();
      List<Map<String, dynamic>> loadedCars = [];
      for (var doc in snapshot.docs) { loadedCars.add(doc.data()); }
      setState(() { allCars = loadedCars; isLoading = false; });
    } catch (e) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Comparison")),
      body: Column(children: [
          Container(padding: const EdgeInsets.all(15), color: Colors.white, child: Row(children: [Expanded(child: _buildDropdown(1)), const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.compare_arrows, size: 30, color: Colors.red)), Expanded(child: _buildDropdown(2))])),
          const Divider(height: 1),
          Expanded(child: (car1 == null || car2 == null) ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_car, size: 80, color: Colors.grey[300]), Text("Select two cars to compare", style: TextStyle(color: Colors.grey[600]))])) : 
          ListView(padding: const EdgeInsets.all(10), children: [
            _buildTextRow("Price (Approx)", "price", Icons.monetization_on, isPrice: true),
            _buildTextRow("Engine Capacity", "engine", Icons.engineering), 
            _buildTextRow("Horsepower", "power", Icons.speed), 
            _buildTextRow("Torque", "torque", Icons.bolt), 
            _buildTextRow("Transmission", "trans", Icons.settings), 
            _buildTextRow("Fuel Average", "fuel", Icons.local_gas_station), 
            const Divider(),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: Text("Quality & Ratings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)))),
            _buildStarRatingRow("Resale Value"),
            _buildStarRatingRow("Comfort Level"),
            _buildStarRatingRow("Parts Availability"),
            const SizedBox(height: 20),
            _buildVerdictCard()
          ]))
      ]),
    );
  }

  Widget _buildDropdown(int carNum) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<Map<String, dynamic>>(isExpanded: true, hint: Text("Select Car $carNum"), value: carNum == 1 ? car1 : car2, items: allCars.map((car) { return DropdownMenuItem(value: car, child: Text(car['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))); }).toList(), onChanged: (val) { 
      setState(() { 
        if (carNum == 1) car1 = val; else car2 = val;
      }); 
    })));
  }

  Widget _buildTextRow(String title, String key, IconData icon, {bool isPrice = false}) {
    String val1 = car1![key] ?? '-';
    String val2 = car2![key] ?? '-';
    if (isPrice) {
      val1 = formatPrice(getRealisticPrice(car1!));
      val2 = formatPrice(getRealisticPrice(car2!));
    }
    return Card(margin: const EdgeInsets.only(bottom: 15), elevation: 2, child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 5), Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))]), const SizedBox(height: 10), Row(children: [Expanded(child: Center(child: Text(val1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))), Container(width: 1, height: 20, color: Colors.grey[300]), Expanded(child: Center(child: Text(val2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))))])])));
  }

  Widget _buildStarRatingRow(String title) {
    double r1 = calculateSmartRating(title, car1!);
    double r2 = calculateSmartRating(title, car2!);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), child: Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: List.generate(5, (index) { if (index + 1 <= r1) return const Icon(Icons.star, color: Colors.amber, size: 18); if (index < r1 && index + 1 > r1) return const Icon(Icons.star_half, color: Colors.amber, size: 18); return const Icon(Icons.star_border, color: Colors.amber, size: 18); })),
          Row(children: List.generate(5, (index) { if (index + 1 <= r2) return const Icon(Icons.star, color: Colors.amber, size: 18); if (index < r2 && index + 1 > r2) return const Icon(Icons.star_half, color: Colors.amber, size: 18); return const Icon(Icons.star_border, color: Colors.amber, size: 18); })),
        ]),
        const Divider(),
      ],
    ));
  }

  // --- UPDATED VERDICT CARD (THEME MATCHED) ---
  Widget _buildVerdictCard() {
    double hp1 = extractNumber(car1!['power']);
    double hp2 = extractNumber(car2!['power']);
    double engine1 = extractNumber(car1!['engine']);
    double engine2 = extractNumber(car2!['engine']);
    double fuel1 = extractNumber(car1!['fuel']);
    double fuel2 = extractNumber(car2!['fuel']);
    double p1 = getRealisticPrice(car1!);
    double p2 = getRealisticPrice(car2!);

    int score1 = 0; 
    int score2 = 0;

    if (engine1 > engine2) score1 += 2; else if (engine2 > engine1) score2 += 2; 
    if (hp1 > hp2) score1 += 2; else if (hp2 > hp1) score2 += 2; 
    if (fuel1 > fuel2) score1 += 1; else if (fuel2 > fuel1) score2 += 1; 

    String winnerName = "Both are Good";
    String buyReason = "";
    String avoidReason = "";
    
    // Theme Colors
    Color themeRed = const Color(0xFFB71C1C); 
    Color winnerColor = Colors.green[800]!;

    if (score1 > score2) {
      winnerName = car1!['name']; 
      if (hp1 > hp2) buyReason = "✅ Buy for Superior Power & Driving Thrill.\n";
      else if (fuel1 > fuel2) buyReason = "✅ Buy for Excellent Fuel Economy.\n";
      else buyReason = "✅ Buy for Better Engine Specs.\n";

      if (p2 > p1) avoidReason = "❌ Avoid ${car2!['name']}: It is more expensive with lower specs.";
      else avoidReason = "❌ ${car2!['name']} is slightly underpowered compared to the winner.";

    } else if (score2 > score1) {
      winnerName = car2!['name'];
      if (hp2 > hp1) buyReason = "✅ Buy for Superior Power & Driving Thrill.\n";
      else if (fuel2 > fuel1) buyReason = "✅ Buy for Excellent Fuel Economy.\n";
      else buyReason = "✅ Buy for Better Engine Specs.\n";

      if (p1 > p2) avoidReason = "❌ Avoid ${car1!['name']}: It is more expensive with lower specs.";
      else avoidReason = "❌ ${car1!['name']} is slightly underpowered compared to the winner.";

    } else {
      if (p1 < p2) { 
        winnerName = car1!['name']; 
        buyReason = "✅ Similar Specs, but this is Cheaper.";
        avoidReason = "❌ ${car2!['name']} is overpriced.";
      } else { 
        winnerName = car2!['name'];
        buyReason = "✅ Similar Specs, but this is Cheaper.";
        avoidReason = "❌ ${car1!['name']} is overpriced.";
      }
    }

    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: Colors.red.shade50, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: themeRed, width: 2)
      ), 
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(Icons.emoji_events, color: themeRed), 
            const SizedBox(width: 10), 
            Text("PAK WHEELS VERDICT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: themeRed, fontSize: 16))
          ]
        ), 
        const SizedBox(height: 10), 
        Text(winnerName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: winnerColor), textAlign: TextAlign.center), 
        const SizedBox(height: 15), 
        Text(buyReason, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(avoidReason, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 14, fontStyle: FontStyle.italic)),
      ])
    );
  }
}

// --- 5. HOME SCREEN ---
class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> { 
  String searchQuery = ""; String? selectedCity; RangeValues priceRange = const RangeValues(0, 500000000); RangeValues yearRange = const RangeValues(1980, 2030); String? selectedTrans; final List<String> cities = ["Lahore", "Karachi", "Islamabad", "Faisalabad", "Rawalpindi", "Multan", "Peshawar", "Quetta"];
  void _showFilterModal() { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) { return StatefulBuilder(builder: (context, setModalState) { return Container(height: MediaQuery.of(context).size.height * 0.9, padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Filter Search", style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)), TextButton(onPressed: (){ setModalState((){ selectedCity = null; priceRange = const RangeValues(0, 500000000); yearRange = const RangeValues(1980, 2030); selectedTrans = null; }); }, child: const Text("Reset All", style: TextStyle(color: Color(0xFFB71C1C))))]), const Divider(color: Colors.grey), const Text("Location", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: selectedCity, dropdownColor: Colors.white, hint: const Text("Select City", style: TextStyle(color: Colors.black54)), icon: const Icon(Icons.location_on, color: Color(0xFFB71C1C)), isExpanded: true, style: const TextStyle(color: Colors.black), items: cities.map((String city) => DropdownMenuItem<String>(value: city, child: Text(city))).toList(), onChanged: (val) => setModalState(() => selectedCity = val)))), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Price Range (PKR)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)), Text("Any", style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12))]), RangeSlider(values: priceRange, min: 0, max: 500000000, divisions: 100, activeColor: const Color(0xFFB71C1C), inactiveColor: Colors.grey[300], labels: RangeLabels(formatPrice(priceRange.start), formatPrice(priceRange.end)), onChanged: (v) => setModalState(() => priceRange = v)), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Model Year", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)), Text("${yearRange.start.toInt()} - ${yearRange.end.toInt()}", style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12))]), RangeSlider(values: yearRange, min: 1980, max: 2030, divisions: 50, activeColor: const Color(0xFFB71C1C), inactiveColor: Colors.grey[300], labels: RangeLabels(yearRange.start.toInt().toString(), yearRange.end.toInt().toString()), onChanged: (v) => setModalState(() => yearRange = v)), const SizedBox(height: 20), const Text("Transmission", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), Wrap(spacing: 10, children: ["Automatic", "Manual"].map((t) => ChoiceChip(label: Text(t), selected: selectedTrans == t, selectedColor: const Color(0xFFB71C1C), backgroundColor: Colors.grey[200], labelStyle: TextStyle(color: selectedTrans == t ? Colors.white : Colors.black), onSelected: (b) => setModalState(() => selectedTrans = b ? t : null))).toList()), const SizedBox(height: 40), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)), onPressed: () { setState(() {}); Navigator.pop(context); }, child: const Text("Show Results", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))]))); }); }, ); }
  @override Widget build(BuildContext context) { return Column(children: [Container(padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10), decoration: const BoxDecoration(color: Color(0xFFB71C1C), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))), child: Row(children: [Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: TextField(onChanged: (val) => setState(() => searchQuery = val.toLowerCase()), decoration: const InputDecoration(hintText: "Search used cars...", border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Colors.grey), contentPadding: EdgeInsets.symmetric(vertical: 12))))), const SizedBox(width: 10), GestureDetector(onTap: _showFilterModal, child: Container(height: 48, width: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Stack(alignment: Alignment.center, children: [const Icon(Icons.tune, color: Color(0xFFB71C1C)), if(selectedCity != null || selectedTrans != null) Positioned(top: 10, right: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)))],),))])), Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection('cars').orderBy('year', descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); var allDocs = snapshot.data!.docs; var displayCars = allDocs.where((doc) { var data = doc.data(); var name = (data['name'] ?? '').toString().toLowerCase(); bool matchesSearch = name.contains(searchQuery); bool matchesCity = selectedCity == null || ((data['city'] ?? '').toString().toLowerCase() == selectedCity!.toLowerCase()); int price = int.tryParse((data['price'] ?? '0').toString()) ?? 0; bool matchesPrice = price >= priceRange.start && price <= priceRange.end; int year = int.tryParse((data['year'] ?? '2025').toString()) ?? 2025; bool matchesYear = year >= yearRange.start && year <= yearRange.end; bool matchesTrans = selectedTrans == null || ((data['trans'] ?? '').toString() == selectedTrans); return matchesSearch && matchesCity && matchesPrice && matchesYear && matchesTrans; }).toList(); if (displayCars.isEmpty) return const Center(child: Text("No car found")); return ListView.separated(padding: const EdgeInsets.all(12), itemCount: displayCars.length, separatorBuilder: (c, i) => const SizedBox(height: 15), itemBuilder: (context, index) { return CarCard(data: displayCars[index].data(), docId: displayCars[index].id); }); }))]); } 
}

class PartsScreen extends StatefulWidget {
  const PartsScreen({super.key});
  @override State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  final List<Map<String, dynamic>> parts = [
    { "name": "Civic X Headlights", "price": 45000, "category": "Lights", "image_path": "assets/p4.jpg", "desc": "Original projection headlights." },
    { "name": "Shell Helix 5W-30 Oil", "price": 8500, "category": "Engine", "image_path": "assets/p2.jpg", "desc": "Fully synthetic motor oil." },
    { "name": "Yokohama Tyres", "price": 32000, "category": "Wheels", "image_path": "assets/p3.jpg", "desc": "Soft rubber tyres." },
    { "name": "Android Panel 10 Inch", "price": 18000, "category": "Interior", "image_path": "assets/p4.webp", "desc": "IPS Display, 2GB RAM." },
    { "name": "Genuine Air Filter", "price": 3500, "category": "Engine", "image_path": "assets/p1.jpg", "desc": "Toyota Genuine Air Filter." },
  ];

  String searchQuery = "";
  String selectedCategory = "All";
  final List<String> categories = ["All", "Engine", "Lights", "Wheels", "Interior", "Brakes", "Car Care"];

  void addToCart(Map<String, dynamic> item) async {
    User? user = FirebaseAuth.instance.currentUser;
    // 1. GUEST CHECK
    if (user == null) { 
      Navigator.push(context, MaterialPageRoute(builder: (_)=>const LoginScreen())); 
      return; 
    }
    
    // 2. ADMIN CHECK (Ye line admin ko rokti hai)
    if (await isAdmin(user.uid)) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Admins cannot place orders!"))); 
      return; 
    }
    
    setState(() { myCart.add(item); });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Cart!"), duration: Duration(seconds: 1)));
  }

  @override Widget build(BuildContext context) {
    var filteredParts = parts.where((p) { 
      bool matchName = p['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()); 
      bool matchCat = selectedCategory == "All" || p['category'] == selectedCategory; 
      return matchName && matchCat; 
    }).toList();
    
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Column(children: [
        Container(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10), 
          decoration: const BoxDecoration(color: Color(0xFFB71C1C), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))), 
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Find Auto Parts", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Row(children: [
                if(user != null) IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_)=>const NotificationsScreen()))),
                Stack(children: [
                    IconButton(icon: const Icon(Icons.shopping_cart, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_)=>const CartScreen()))), 
                    if (myCart.isNotEmpty) Positioned(right: 5, top: 5, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle), child: Text("${myCart.length}", style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))))
                ]),
              ])
            ]),
            const SizedBox(height: 15), 
            Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: TextField(onChanged: (v) => setState(() => searchQuery = v), decoration: const InputDecoration(hintText: "Search parts...", border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Colors.grey)))), 
            const SizedBox(height: 15),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: categories.map((cat) { bool isSel = selectedCategory == cat; return GestureDetector(onTap: () => setState(() => selectedCategory = cat), child: Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: isSel ? Colors.white : Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(cat, style: TextStyle(color: isSel ? const Color(0xFFB71C1C) : Colors.white, fontWeight: FontWeight.bold)))); }).toList())),
        ])),
        Expanded(child: GridView.builder(
            padding: const EdgeInsets.all(15), 
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 15, mainAxisSpacing: 15), 
            itemCount: filteredParts.length, 
            itemBuilder: (ctx, i) { 
              var item = filteredParts[i]; 
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PartDetailScreen(item: item))), 
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]), 
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), child: Container(width: double.infinity, color: Colors.grey[100], child: Image.asset(item['image_path'], fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image, size: 50, color: Colors.grey))))), 
                    Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['category'], style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)), 
                      const SizedBox(height: 2), 
                      Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                      const SizedBox(height: 5), 
                      Text("PKR ${formatPrice(item['price'].toDouble())}", style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold, fontSize: 14)), 
                      const SizedBox(height: 5), 
                      SizedBox(width: double.infinity, height: 30, child: ElevatedButton(onPressed: () => addToCart(item), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), padding: EdgeInsets.zero), child: const Text("Add to Cart", style: TextStyle(fontSize: 10))))
                    ]))
                  ])
                )
              ); 
            }
        ))
      ]),
    );
  }
}
class PartDetailScreen extends StatelessWidget { 
  final Map<String, dynamic> item; 
  const PartDetailScreen({super.key, required this.item});
  
  @override Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(title: Text(item['name'])), 
      body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 250, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.asset(item['image_path'], fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image, size: 80, color: Colors.grey)))), 
        const SizedBox(height: 20), 
        Text("PKR ${formatPrice(item['price'].toDouble())}", style: const TextStyle(fontSize: 26, color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)), 
        const SizedBox(height: 10), 
        Text(item['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 5), 
        Chip(label: Text(item['category']), backgroundColor: Colors.red.shade50, labelStyle: const TextStyle(color: Color(0xFFB71C1C))), 
        const Divider(height: 30), 
        const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 10), 
        Text(item['desc'], style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5)), 
        const Spacer(), 
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
          onPressed: () async { 
             User? user = FirebaseAuth.instance.currentUser;
             // 1. GUEST CHECK
             if (user == null) { Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); return; }
             
             // 2. ADMIN CHECK (Ye roka hai)
             if (await isAdmin(user.uid)) { 
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Admins cannot buy items."))); 
               return; 
             } 
             
             myCart.add(item); 
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())); 
          }, 
          icon: const Icon(Icons.shopping_cart), 
          label: const Text("BUY NOW", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
      ]))
    ); 
  } 
}

// --- 7. CHAT LIST SCREEN (WITH DELETE OPTION) ---
class ChatListScreen extends StatelessWidget { 
  const ChatListScreen({super.key});

  void deleteChat(BuildContext context, String chatId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Chat?"),
      content: const Text("This chat will be removed from your list."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
        }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ]
    ));
  }

  @override Widget build(BuildContext context) { 
    User? user = FirebaseAuth.instance.currentUser; 
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login"))); 
    
    return Scaffold(
      appBar: AppBar(title: const Text("My Chats")), 
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('chats').where('users', arrayContains: user.uid).snapshots(), 
        builder: (context, snapshot) { 
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); 
          var chats = snapshot.data!.docs; 
          if (chats.isEmpty) return const Center(child: Text("No chats yet.")); 
          
          return ListView.separated(
            padding: const EdgeInsets.all(10), 
            itemCount: chats.length, 
            separatorBuilder: (c, i) => const Divider(), 
            itemBuilder: (context, index) { 
              var chatData = chats[index].data(); 
              String otherUserId = (chatData['users'] as List).firstWhere((id) => id != user.uid, orElse: () => ""); 
              
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(), 
                builder: (context, userSnapshot) { 
                  String name = "User"; 
                  String? photoUrl; 
                  if (userSnapshot.hasData && userSnapshot.data!.exists) { 
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>; 
                    name = userData['name'] ?? "User"; 
                    photoUrl = userData['photoUrl']; 
                  } 
                  return ListTile(
                    leading: CircleAvatar(radius: 25, backgroundColor: Colors.grey[200], child: ClipOval(child: buildUniversalImage(photoUrl, height: 50, width: 50, fit: BoxFit.cover))), 
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                    subtitle: Text(chatData['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis), 
                    trailing: const Icon(Icons.chevron_right), 
                    // LONG PRESS TO DELETE CHAT
                    onLongPress: () => deleteChat(context, chats[index].id),
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: chats[index].id, otherUserId: otherUserId))); }
                  ); 
                }
              ); 
            }
          ); 
        }
      )
    ); 
  }
}

// --- 8. CHAT DETAIL (WITH DELETE MSG & TIME) ---
class ChatDetailScreen extends StatefulWidget { final String chatId; final String otherUserId; const ChatDetailScreen({super.key, required this.chatId, required this.otherUserId}); @override State<ChatDetailScreen> createState() => _ChatDetailScreenState(); }
class _ChatDetailScreenState extends State<ChatDetailScreen> { 
  final TextEditingController _msgController = TextEditingController(); 
  
  void sendMessage() async { 
    if (_msgController.text.trim().isEmpty) return; 
    String msg = _msgController.text.trim(); 
    _msgController.clear(); 
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({ 'text': msg, 'senderId': FirebaseAuth.instance.currentUser!.uid, 'timestamp': FieldValue.serverTimestamp() }); 
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({ 'lastMessage': msg, 'lastMessageTime': FieldValue.serverTimestamp() }); 
  } 

  // Function to format time manually (No extra package needed)
  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = timestamp.toDate();
    String period = date.hour >= 12 ? "PM" : "AM";
    int hour = date.hour > 12 ? date.hour - 12 : date.hour;
    if (hour == 0) hour = 12;
    String minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  void deleteMessage(String msgId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Message"),
      content: const Text("Remove this message for everyone?"),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').doc(msgId).delete();
        }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ]
    ));
  }

  @override Widget build(BuildContext context) { 
    var currentUser = FirebaseAuth.instance.currentUser!; 
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(), builder: (context, snapshot) { String name = "Chat"; String? photoUrl; if (snapshot.hasData && snapshot.data!.exists) { var data = snapshot.data!.data() as Map<String, dynamic>; name = data['name'] ?? "User"; photoUrl = data['photoUrl']; } return Row(children: [CircleAvatar(radius: 18, backgroundColor: Colors.grey[300], child: ClipOval(child: buildUniversalImage(photoUrl, height: 36, width: 36, fit: BoxFit.cover))), const SizedBox(width: 10), Expanded(child: Text(name, style: const TextStyle(fontSize: 18, overflow: TextOverflow.ellipsis)))]); })), 
      body: Column(children: [
        Expanded(child: StreamBuilder(
          stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(), 
          builder: (context, snapshot) { 
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); 
            var msgs = snapshot.data!.docs; 
            return ListView.builder(
              reverse: true, padding: const EdgeInsets.all(10), itemCount: msgs.length, 
              itemBuilder: (context, index) { 
                var data = msgs[index].data(); 
                bool isMe = data['senderId'] == currentUser.uid; 
                String time = formatTimestamp(data['timestamp']);

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, 
                  child: GestureDetector(
                    onLongPress: isMe ? () => deleteMessage(msgs[index].id) : null, // Sirf apne msg delete kar sakein
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4), 
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
                      decoration: BoxDecoration(color: isMe ? const Color(0xFFB71C1C) : Colors.grey[300], borderRadius: BorderRadius.circular(15)), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(data['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 10)),
                        ],
                      )
                    ),
                  )
                ); 
              }
            ); 
          }
        )), 
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), color: Colors.white, child: Row(children: [Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none))), IconButton(onPressed: sendMessage, icon: const Icon(Icons.send, color: Color(0xFFB71C1C))) ]))
      ])
    ); 
  } 
}

// --- 9. CAR DETAIL ---
class CarDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool showChatOption;
  const CarDetailScreen({super.key, required this.data, required this.showChatOption});
  @override State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    List<String> images = getImagesList(widget.data['images']);
    if (images.isEmpty && widget.data['image'] != null && widget.data['image'] != '') images.add(widget.data['image']);
    if (images.isEmpty) images.add('');

    // Use Smart Price Here too
    double priceVal = getRealisticPrice(widget.data);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: widget.showChatOption ? Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]), child: SizedBox(height: 50, child: ElevatedButton.icon(onPressed: () {
        openChatLogic(context, widget.data, FirebaseAuth.instance.currentUser!.uid);
      }, icon: const Icon(Icons.chat_bubble_outline), label: const Text("Chat with Seller", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C))))) : null,
      body: Column(
        children: [
          Stack(children: [
              Container(height: 300, width: double.infinity, color: Colors.black, child: PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _currentImageIndex = index),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageGallery(images: images, initialIndex: index))),
                      child: buildUniversalImage(images[index], fit: BoxFit.contain)
                    );
                  })),
              Positioned(top: 40, left: 15, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)))),
              if(images.length > 1) Positioned(bottom: 15, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: images.asMap().entries.map((entry) { return Container(width: 8.0, height: 8.0, margin: const EdgeInsets.symmetric(horizontal: 4.0), decoration: BoxDecoration(shape: BoxShape.circle, color: _currentImageIndex == entry.key ? const Color(0xFFB71C1C) : Colors.white.withOpacity(0.5))); }).toList())),
          ]),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("PKR ${formatPrice(priceVal)}", style: const TextStyle(fontSize: 22, color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.location_on, size: 18, color: Colors.grey), const SizedBox(width: 5), Text(widget.data['city'] ?? 'Pakistan', style: const TextStyle(color: Colors.grey, fontSize: 16))]),
              const Divider(height: 30),
              const Text("Specifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Wrap(spacing: 10, runSpacing: 10, children: [
                  _buildSpecCard(Icons.calendar_today, widget.data['year'] ?? '-', "Model Year"),
                  _buildSpecCard(Icons.speed, "${widget.data['km'] ?? '-'} km", "Mileage"),
                  _buildSpecCard(Icons.local_gas_station, widget.data['fuel'] ?? '-', "Fuel"),
                  _buildSpecCard(Icons.engineering, widget.data['engine'] ?? '-', "Engine"),
                  _buildSpecCard(Icons.settings, widget.data['trans'] ?? '-', "Trans"),
              ]),
              const Divider(height: 30),
              const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("This is a well-maintained ${widget.data['name']}. Ideally kept and driven with care. Original documents available.", style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 15)),
          ]))),
        ],
      ),
    );
  }
  Widget _buildSpecCard(IconData icon, String value, String label) { return Container(width: 105, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)), child: Column(children: [Icon(icon, color: const Color(0xFFB71C1C), size: 26), const SizedBox(height: 10), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))])); }
}

// --- 10. AUTH SCREENS ---
class LoginScreen extends StatefulWidget { final Map<String, dynamic>? pendingAdData; const LoginScreen({super.key, this.pendingAdData}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> { final _email = TextEditingController(); final _pass = TextEditingController(); bool isLoading = false; final _formKey = GlobalKey<FormState>(); void login() async { if (!_formKey.currentState!.validate()) return; setState(() => isLoading = true); try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim()); if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Login Successful!"))); if (widget.pendingAdData != null) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CarDetailScreen(data: widget.pendingAdData!, showChatOption: true))); } else { Navigator.pop(context); } } } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Error: ${e.toString()}"))); } setState(() => isLoading = false); } @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: const Text("Login"), automaticallyImplyLeading: false), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(25), child: Form(key: _formKey, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.account_circle, size: 100, color: Color(0xFFB71C1C)), const SizedBox(height: 10), const Text("Welcome Back", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)), const Text("Login to manage your ads", style: TextStyle(color: Colors.grey)), const SizedBox(height: 30), TextFormField(controller: _email, validator: (val) => val!.isEmpty ? "Enter Email" : null, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined))), const SizedBox(height: 15), TextFormField(controller: _pass, obscureText: true, validator: (val) => val!.isEmpty ? "Enter Password" : null, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline))), const SizedBox(height: 25), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : login, child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Don't have an account? "), GestureDetector(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (c) => const RegisterScreen())); }, child: const Text("Register Now", style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)))])]))))); } }

class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _RegisterScreenState(); }
class _RegisterScreenState extends State<RegisterScreen> { final _name = TextEditingController(); final _email = TextEditingController(); final _phone = TextEditingController(); final _pass = TextEditingController(); final _confirmPass = TextEditingController(); final _formKey = GlobalKey<FormState>(); bool isLoading = false; void register() async { if (!_formKey.currentState!.validate()) return; setState(() => isLoading = true); try { UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim()); await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({'uid': userCred.user!.uid, 'name': _name.text.trim(), 'email': _email.text.trim(), 'phone': _phone.text.trim(), 'createdAt': DateTime.now()}); if(mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Account Created! Please Login now."))); } } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Error: ${e.toString()}"))); } setState(() => isLoading = false); } @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Create Account")), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(25), child: Form(key: _formKey, child: Column(children: [const Text("Join PakWheels", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 5), const Text("Fill the form below to register", style: TextStyle(color: Colors.grey)), const SizedBox(height: 30), TextFormField(controller: _name, validator: (val) => val!.isEmpty ? "Enter Username" : null, decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person))), const SizedBox(height: 15), TextFormField(controller: _email, validator: (val) => !val!.contains('@') ? "Invalid Email" : null, decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email))), const SizedBox(height: 15), TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Mobile Number", prefixIcon: Icon(Icons.phone), hintText: "+923001234567"), validator: (val) { if (val == null || val.isEmpty) return "Enter Mobile Number"; if (!val.startsWith("+92")) return "Start with +92"; if (val.length < 13) return "Invalid Number Length"; return null; }), const SizedBox(height: 15), TextFormField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)), validator: (val) { if (val == null || val.isEmpty) return "Enter Password"; if (val.length < 8) return "Must be at least 8 characters"; if (!RegExp(r'[a-zA-Z]').hasMatch(val)) return "Must contain at least 1 alphabet"; return null; }), const SizedBox(height: 15), TextFormField(controller: _confirmPass, obscureText: true, decoration: const InputDecoration(labelText: "Confirm Password", prefixIcon: Icon(Icons.lock_clock)), validator: (val) { if (val != _pass.text) return "Passwords do not match"; return null; }), const SizedBox(height: 30), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : register, child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("REGISTER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))]))))); } }

// --- 11. EXTRA SCREENS ---
class FullScreenImageGallery extends StatelessWidget {
final List<dynamic> images;
final int initialIndex;
const FullScreenImageGallery({super.key, required this.images, required this.initialIndex});
@override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), body: PageView.builder(itemCount: images.length, controller: PageController(initialPage: initialIndex), itemBuilder: (context, index) { return InteractiveViewer(child: Center(child: buildUniversalImage(images[index], fit: BoxFit.contain))); })); }
}

class SellCarForm extends StatefulWidget { const SellCarForm({super.key}); @override State<SellCarForm> createState() => _SellCarFormState(); }
class _SellCarFormState extends State<SellCarForm> {
final _name = TextEditingController(); final _price = TextEditingController(); final _city = TextEditingController(); final _engine = TextEditingController(); final _fuel = TextEditingController(); final _trans = TextEditingController(); final _year = TextEditingController(); final _km = TextEditingController();
List<Uint8List> _selectedImages = []; final ImagePicker _picker = ImagePicker(); bool isLoading = false;
Future<void> _pickMultiImages() async { final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 65); if (pickedFiles.isNotEmpty) { List<Uint8List> tempImages = []; for (var file in pickedFiles) { var bytes = await file.readAsBytes(); tempImages.add(bytes); } setState(() { _selectedImages.addAll(tempImages); }); } }
void uploadCar() async { if (_name.text.isEmpty || _price.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill Name and Price"))); return; } setState(() => isLoading = true); List<String> imagesBase64 = []; for (var bytes in _selectedImages) { imagesBase64.add(base64Encode(bytes)); } if (imagesBase64.isEmpty) imagesBase64.add(''); await FirebaseFirestore.instance.collection('cars').add({ 'name': _name.text, 'price': int.tryParse(_price.text) ?? 0, 'city': _city.text, 'images': imagesBase64, 'year': _year.text.isEmpty ? '2025' : _year.text, 'km': _km.text.isEmpty ? '0' : _km.text, 'fuel': _fuel.text, 'engine': _engine.text, 'trans': _trans.text, 'featured': false, 'userId': FirebaseAuth.instance.currentUser?.uid, }); _name.clear(); _price.clear(); _city.clear(); _engine.clear(); _fuel.clear(); _trans.clear(); _year.clear(); _km.clear(); setState(() { _selectedImages.clear(); }); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Car Posted Successfully!"))); setState(() => isLoading = false); }
@override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(children: [const Text("Sell Your Car", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextFormField(controller: _name, decoration: const InputDecoration(labelText: "Car Model")), const SizedBox(height: 15), TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price (PKR)")), const SizedBox(height: 15), Row(children: [Expanded(child: TextFormField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Year"))), const SizedBox(width: 10), Expanded(child: TextFormField(controller: _km, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Mileage (KM)")))]), const SizedBox(height: 15), TextFormField(controller: _city, decoration: const InputDecoration(labelText: "City")), const SizedBox(height: 15), Row(children: [Expanded(child: TextFormField(controller: _engine, decoration: const InputDecoration(labelText: "Engine (cc)"))), const SizedBox(width: 10), Expanded(child: TextFormField(controller: _fuel, decoration: const InputDecoration(labelText: "Fuel")))]), const SizedBox(height: 10), TextFormField(controller: _trans, decoration: const InputDecoration(labelText: "Transmission")), const SizedBox(height: 20), SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _selectedImages.length + 1, itemBuilder: (context, index) { if (index == 0) { return GestureDetector(onTap: _pickMultiImages, child: Container(width: 100, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey), Text("Add Photos", style: TextStyle(fontSize: 12))]))); } return Stack(children: [Container(width: 120, margin: const EdgeInsets.only(right: 10), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_selectedImages[index - 1], fit: BoxFit.cover))), Positioned(right: 0, top: 0, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => _selectedImages.removeAt(index - 1))))]); })), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: isLoading ? null : uploadCar, child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Post Ad Now", style: TextStyle(fontSize: 18))))]))); }
}

class ProfileScreen extends StatefulWidget { const ProfileScreen({super.key}); @override State<ProfileScreen> createState() => _ProfileScreenState(); }
class _ProfileScreenState extends State<ProfileScreen> { final User? user = FirebaseAuth.instance.currentUser; bool _isUploading = false; final ImagePicker _picker = ImagePicker(); Future<void> _pickAndUploadImage() async { final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 65); if (pickedFile == null) return; setState(() => _isUploading = true); try { Uint8List fileBytes = await pickedFile.readAsBytes(); String base64String = base64Encode(fileBytes); await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'photoUrl': base64String}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Photo Updated!"))); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); } finally { setState(() => _isUploading = false); } } @override Widget build(BuildContext context) { if (user == null) return const Scaffold(body: Center(child: Text("Please Login"))); return Scaffold(appBar: AppBar(title: const Text("My Profile")), body: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); var userData = snapshot.data!.data() as Map<String, dynamic>?; if (userData == null) return const Center(child: Text("User data not found.")); String? photoData = userData['photoUrl']; return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [const SizedBox(height: 20), Center(child: Stack(children: [CircleAvatar(radius: 70, backgroundColor: Colors.grey[300], child: ClipOval(child: buildUniversalImage(photoData, height: 140, width: 140, fit: BoxFit.cover))), Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: const Color(0xFFB71C1C), radius: 20, child: IconButton(icon: _isUploading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.camera_alt, color: Colors.white, size: 20), onPressed: _isUploading ? null : _pickAndUploadImage)))])), const SizedBox(height: 30), Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(15.0), child: Column(children: [ListTile(leading: const Icon(Icons.person, color: Color(0xFFB71C1C)), title: Text(userData['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))), const Divider(), ListTile(leading: const Icon(Icons.email, color: Color(0xFFB71C1C)), title: Text(userData['email'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))), const Divider(), ListTile(leading: const Icon(Icons.phone, color: Color(0xFFB71C1C)), title: Text(userData['phone'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)))])))])); })); } }

class FavoritesScreen extends StatelessWidget { const FavoritesScreen({super.key}); @override Widget build(BuildContext context) { User? user = FirebaseAuth.instance.currentUser; if (user == null) return const Scaffold(body: Center(child: Text("Please Login"))); return Scaffold(appBar: AppBar(title: const Text("My Favorites")), body: StreamBuilder(stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favorites').snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); var favDocs = snapshot.data!.docs; if (favDocs.isEmpty) return const Center(child: Text("No Favorites yet")); return ListView.separated(padding: const EdgeInsets.all(12), itemCount: favDocs.length, separatorBuilder: (c, i) => const SizedBox(height: 15), itemBuilder: (context, index) { return CarCard(data: favDocs[index].data(), docId: favDocs[index].id); }); })); } }

class MyAdsScreen extends StatelessWidget { const MyAdsScreen({super.key}); @override Widget build(BuildContext context) { User? user = FirebaseAuth.instance.currentUser; if (user == null) return const Scaffold(body: Center(child: Text("Please Login"))); return Scaffold(appBar: AppBar(title: const Text("My Ads")), body: StreamBuilder(stream: FirebaseFirestore.instance.collection('cars').where('userId', isEqualTo: user.uid).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); var myCars = snapshot.data!.docs; return ListView.separated(padding: const EdgeInsets.all(12), itemCount: myCars.length, separatorBuilder: (c, i) => const SizedBox(height: 15), itemBuilder: (context, index) { return CarCard(data: myCars[index].data(), docId: myCars[index].id, showDeleteButton: true); }); })); } }// --- NEW SCREENS FOR CHECKOUT & NOTIFICATIONS ---

class CartScreen extends StatefulWidget { const CartScreen({super.key}); @override State<CartScreen> createState() => _CartScreenState(); }
class _CartScreenState extends State<CartScreen> {
  double getTotal() { double total = 0; for (var item in myCart) { total += double.tryParse(item['price'].toString()) ?? 0.0; } return total; }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("My Cart")), body: myCart.isEmpty ? const Center(child: Text("Cart is Empty")) : Column(children: [Expanded(child: ListView.separated(padding: const EdgeInsets.all(10), itemCount: myCart.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (context, index) { var item = myCart[index]; return ListTile(leading: Image.asset(item['image_path'], width: 50, errorBuilder: (c,o,s)=>const Icon(Icons.image)), title: Text(item['name']), subtitle: Text("PKR ${item['price']}"), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { myCart.removeAt(index); }); })); })), Container(padding: const EdgeInsets.all(20), color: Colors.white, child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text("PKR ${getTotal()}", style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold))]), const SizedBox(height: 15), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())); }, child: const Text("PROCEED TO CHECKOUT")))]))])); }
}

class CheckoutScreen extends StatefulWidget { const CheckoutScreen({super.key}); @override State<CheckoutScreen> createState() => _CheckoutScreenState(); }
class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  
  double getTotal() { double t = 0; for(var i in myCart) t += (i['price'] as int); return t; }

  void placeOrder() async {
    if(!_formKey.currentState!.validate()) return;
    User? user = FirebaseAuth.instance.currentUser;
    // Add Order to Firebase
    await FirebaseFirestore.instance.collection('orders').add({
      'userId': user!.uid,
      'customerName': _name.text,
      'phone': _phone.text,
      'email': _email.text,
      'city': _city.text,
      'address': _address.text,
      'postalCode': _postal.text,
      'items': myCart.map((e)=>e['name']).toList(),
      'totalPrice': getTotal(),
      'paymentMethod': 'COD',
      'date': FieldValue.serverTimestamp(),
      'status': 'Pending'
    });
    // Add Notification
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': user.uid,
      'title': 'Order Placed',
      'body': 'Your order for PKR ${getTotal()} has been placed successfully.',
      'date': FieldValue.serverTimestamp(),
      'read': false
    });
    setState(() { myCart.clear(); });
    Navigator.pop(context); // Close checkout
    Navigator.pop(context); // Close cart
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Order Placed Successfully!")));
  }

  @override Widget build(BuildContext context) {
    double total = getTotal();
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout Details")),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Delivery Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)), validator: (v)=>v!.isEmpty?"Required":null),
        const SizedBox(height: 10),
        TextFormField(controller: _phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone, validator: (v)=>v!.isEmpty?"Required":null),
        const SizedBox(height: 10),
        TextFormField(controller: _email, decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress, validator: (v)=>v!.isEmpty?"Required":null),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: "City", prefixIcon: Icon(Icons.location_city)), validator: (v)=>v!.isEmpty?"Required":null)),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _postal, decoration: const InputDecoration(labelText: "Postal Code", prefixIcon: Icon(Icons.local_post_office)), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _address, decoration: const InputDecoration(labelText: "Full Address (House, Street, Area)", prefixIcon: Icon(Icons.home)), validator: (v)=>v!.isEmpty?"Required":null),
        
        const Divider(height: 30),
        const Text("Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ListTile(title: const Text("Cash on Delivery"), leading: const Icon(Icons.money, color: Colors.green), trailing: const Icon(Icons.check_circle, color: Colors.green), contentPadding: EdgeInsets.zero),
        
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Payment:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text("PKR $total", style: const TextStyle(fontSize: 20, color: Color(0xFFB71C1C), fontWeight: FontWeight.bold))]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: placeOrder, child: const Text("PLACE ORDER")))
      ]))),
    );
  }
}

class NotificationsScreen extends StatelessWidget { 
  const NotificationsScreen({super.key}); 
  
  @override Widget build(BuildContext context) { 
    User? user = FirebaseAuth.instance.currentUser; 
    
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")), 
      body: StreamBuilder(
        // FIX: Maine 'orderBy' hata diya hai taake Index ka masla na aye.
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user!.uid)
            .snapshots(), 
        builder: (c, s) { 
          // Check: Agar data load ho raha hai
          if(s.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator()); 
          }

          // Check: Agar koi notification nahi hai
          if(!s.hasData || s.data!.docs.isEmpty) {
             return const Center(child: Text("No Notifications found")); 
          }

          // Data Show Karo
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: s.data!.docs.length, 
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (c, i) {
              var data = s.data!.docs[i].data();
              return ListTile(
                leading: const Icon(Icons.notifications, color: Colors.amber), 
                title: Text(data['title'] ?? 'Alert', style: const TextStyle(fontWeight: FontWeight.bold)), 
                subtitle: Text(data['body'] ?? '')
              ); 
            }
          ); 
        }
      )
    ); 
  } 
}
// --- 9. ADMIN ORDERS SCREEN (CRASH PROOF) ---
class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Manager"),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        // FIX: 'orderBy' hata diya taake crash na ho
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var orders = snapshot.data!.docs;
          if (orders.isEmpty) return const Center(child: Text("No Pending Orders"));

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var orderData = orders[index].data();
              var orderId = orders[index].id;
              String status = orderData['status'] ?? 'Pending';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    Icons.shopping_bag, 
                    color: status == 'Pending' ? Colors.orange : Colors.green
                  ),
                  title: Text(orderData['customerName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("PKR ${orderData['totalPrice']} - $status"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(orderId: orderId, orderData: orderData)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminOrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const AdminOrderDetailScreen({super.key, required this.orderId, required this.orderData});

  @override
  Widget build(BuildContext context) {
    List items = orderData['items'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("Order Details"), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Customer Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Text("Name: ${orderData['customerName']}"),
            Text("Phone: ${orderData['phone']}"),
            Text("Address: ${orderData['address']}, ${orderData['city']}"),
            const SizedBox(height: 20),
            
            const Text("Order Items", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text("• $item", style: const TextStyle(fontSize: 16)),
            )),
            
            const SizedBox(height: 10),
            Text("Total Amount: PKR ${orderData['totalPrice']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                icon: const Icon(Icons.mail),
                label: const Text("RESPOND & NOTIFY USER"),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminResponseScreen(userId: orderData['userId'], orderId: orderId)));
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class AdminResponseScreen extends StatefulWidget {
  final String userId;
  final String orderId;
  const AdminResponseScreen({super.key, required this.userId, required this.orderId});

  @override
  State<AdminResponseScreen> createState() => _AdminResponseScreenState();
}

class _AdminResponseScreenState extends State<AdminResponseScreen> {
  final _msgController = TextEditingController();

  void sendNotification() async {
    if (_msgController.text.isEmpty) return;

    // 1. Notification bhejo
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': widget.userId,
      'title': 'Order Update',
      'body': _msgController.text,
      'date': FieldValue.serverTimestamp(),
      'read': false
    });

    // 2. Order ka status update karo
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'status': 'Processed'
    });

    if(!mounted) return;
    Navigator.pop(context); // Close Response
    Navigator.pop(context); // Close Details
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Response Sent & Order Updated!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Update"), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Message to Customer:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _msgController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "e.g., Your order has been dispatched via TCS. Tracking ID: 12345",
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
                onPressed: sendNotification,
                child: const Text("SEND NOTIFICATION"),
              ),
            )
          ],
        ),
      ),
    );
  }
}