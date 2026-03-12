import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

// --- CLASE MODELO ---
class WheelItem {
  String text;
  bool isJackpot;
  int capability;

  WheelItem({
    required this.text, 
    this.isJackpot = false,
    this.capability = 5,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isJackpot': isJackpot,
    'capability': capability,
  };

  factory WheelItem.fromJson(Map<String, dynamic> json) {
    return WheelItem(
      text: json['text'],
      isJackpot: json['isJackpot'],
      capability: json['capability'],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PromoSpin',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF2C3E50),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Colors.white70),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// --- PANTALLA DE INICIO ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background/background.png"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Título
              const Text(
                "PromoSpin",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 15, offset: Offset(0, 5))
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Seleccioná tu ruleta",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 60),

              // Botón Ruleta Normal
              _WheelButton(
                label: "RULETA NORMAL",
                icon: Icons.casino,
                color: const Color(0xFFFFD700),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoulettePage(
                      title: "¡PRUEBA TU SUERTE!",
                      storageKey: "wheel_items_normal",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Ruleta Deluxe
              _WheelButton(
                label: "RULETA DELUXE",
                icon: Icons.workspace_premium,
                color: const Color(0xFF9B59B6),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoulettePage(
                      title: "✨ DELUXE ✨",
                      storageKey: "wheel_items_deluxe",
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WheelButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- RULETA (ahora recibe title y storageKey) ---
class RoulettePage extends StatefulWidget {
  final String title;
  final String storageKey;

  const RoulettePage({
    super.key,
    required this.title,
    required this.storageKey,
  });

  @override
  State<RoulettePage> createState() => _RoulettePageState();
}

class _RoulettePageState extends State<RoulettePage> with SingleTickerProviderStateMixin {
  StreamController<int> selected = StreamController<int>();
  final AudioPlayer _player = AudioPlayer();

  bool _isSpinning = false;
  double _randomOffset = 0.0;
  List<WheelItem> items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    selected.close();
    _player.dispose();
    super.dispose();
  }

  // --- DATA LOAD/SAVE ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsString = prefs.getString(widget.storageKey);

    if (itemsString != null) {
      List<dynamic> jsonList = jsonDecode(itemsString);
      setState(() {
        items = jsonList.map((item) => WheelItem.fromJson(item)).toList();
      });
    } else {
      setState(() {
        items = [
          WheelItem(text: 'Pluma Gratis', isJackpot: true, capability: 1),
          WheelItem(text: '5% OFF', capability: 7),
          WheelItem(text: 'Será la\nPróxima :(', capability: 10),
          WheelItem(text: '10% OFF', capability: 6),
          WheelItem(text: '20% OFF', capability: 2),
          WheelItem(text: 'Será la\nPróxima :(', capability: 10),
          WheelItem(text: '15% OFF', capability: 4),
          WheelItem(text: 'Será la\nPróxima :(', capability: 10),
        ];
      });
      _saveData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(widget.storageKey, encodedData);
  }

  // --- GIRO ---
  void _spinWheel() async {
    if (_isSpinning || items.length < 2) return;

    setState(() {
      _isSpinning = true;
    });

    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.release);
    await _player.play(AssetSource('drumroll.mp3'));

    int totalWeight = items.fold(0, (sum, item) => sum + item.capability);
    int randomWeight = Random().nextInt(totalWeight);
    int winnerIndex = -1;
    int currentSum = 0;
    
    for (int i = 0; i < items.length; i++) {
      currentSum += items[i].capability;
      if (randomWeight < currentSum) {
        winnerIndex = i;
        break;
      }
    }
    if (winnerIndex == -1) winnerIndex = items.length - 1;

    final double sliceAngle = 2 * pi / items.length;
    final double randomFactor = (Random().nextDouble() * 0.8) - 0.4;

    setState(() {
      _randomOffset = sliceAngle * randomFactor;
    });

    selected.add(winnerIndex);

    const durationInSeconds = 6; 

    Future.delayed(const Duration(seconds: durationInSeconds), () async {
      if (mounted) {
        await _player.stop();
        setState(() {
          _isSpinning = false;
        });
        _showResultDialog(winnerIndex);
      }
    });
  }

  // --- SETTINGS ---
  void _openSettings() {
    if (_isSpinning) return;
    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Configurar Premios", style: TextStyle(fontSize: 18)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Nuevo"),
                      onPressed: () => _addOrEditItem(context, setStateDialog),
                    )
                  ],
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              content: SizedBox(
                width: double.maxFinite,
                height: size.height * 0.6, 
                child: items.isEmpty 
                  ? const Center(child: Text("¡Agrega premios!")) 
                  : ListView.builder(
                      shrinkWrap: false,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          color: Colors.white10,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: item.isJackpot 
                                ? const BorderSide(color: Colors.amber, width: 1) 
                                : BorderSide.none
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: item.isJackpot ? Colors.amber : Colors.grey.shade800,
                                  radius: 15,
                                  child: Icon(
                                    item.isJackpot ? Icons.star : Icons.label,
                                    color: item.isJackpot ? Colors.black : Colors.white54,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              item.text.replaceAll('\n', ' / '),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: item.isJackpot ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Icon(Icons.bar_chart, size: 12, color: _getProbColor(item.capability)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    "Prob.: ${item.capability}", 
                                    style: TextStyle(fontSize: 12, color: _getProbColor(item.capability)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                  onPressed: () => _addOrEditItem(context, setStateDialog, index: index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 15),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    if (items.length <= 2) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Mínimo 2 premios necesarios."))
                                      );
                                      return;
                                    }
                                    setStateDialog(() {
                                      items.removeAt(index);
                                    });
                                    setState(() {}); 
                                    _saveData(); 
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CERRAR", style: TextStyle(color: Colors.white54)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Color _getProbColor(int cap) {
    if (cap <= 2) return Colors.redAccent;
    if (cap <= 6) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  void _addOrEditItem(BuildContext context, StateSetter setStateDialog, {int? index}) {
    TextEditingController controller = TextEditingController();
    bool isJackpotLocal = false; 
    double capabilityLocal = 5.0;

    if (index != null) {
      controller.text = items[index].text.replaceAll('\n', ' ');
      isJackpotLocal = items[index].isJackpot;
      capabilityLocal = items[index].capability.toDouble();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateForm) {
            return AlertDialog(
              title: Text(index == null ? "Nuevo Premio" : "Editar Premio"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: false,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: "Nombre del Premio",
                        hintText: "Ej: 20% OFF",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: isJackpotLocal ? Border.all(color: Colors.amber) : null
                      ),
                      child: SwitchListTile(
                        title: const Text("Premio Mayor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Saldrá dorado", style: TextStyle(fontSize: 12)),
                        secondary: Icon(Icons.star, color: isJackpotLocal ? Colors.amber : Colors.grey),
                        value: isJackpotLocal,
                        activeThumbColor: Colors.amber,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        onChanged: (val) {
                          setStateForm(() {
                            isJackpotLocal = val;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Text(
                      "Probabilidad (Peso): ${capabilityLocal.toInt()}", 
                      style: TextStyle(
                        color: _getProbColor(capabilityLocal.toInt()), 
                        fontWeight: FontWeight.bold
                      )
                    ),
                    Slider(
                      value: capabilityLocal,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: _getProbColor(capabilityLocal.toInt()),
                      label: capabilityLocal.toInt().toString(),
                      onChanged: (val) {
                        setStateForm(() {
                          capabilityLocal = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    
                    String newText = controller.text.trim();
                    int newCap = capabilityLocal.toInt();

                    setStateDialog(() {
                      if (index == null) {
                        items.add(WheelItem(text: newText, isJackpot: isJackpotLocal, capability: newCap));
                      } else {
                        items[index].text = newText;
                        items[index].isJackpot = isJackpotLocal;
                        items[index].capability = newCap;
                      }
                    });
                    setState(() {}); 
                    _saveData(); 
                    Navigator.pop(context);
                  },
                  child: const Text("GUARDAR"),
                )
              ],
            );
          }
        );
      },
    );
  }

  // --- RESULTADO ---
  void _showResultDialog(int index) async {
    final item = items[index];
    bool isBadResult = item.text.contains(":(");
    bool isJackpot = item.isJackpot;

    if (isBadResult) {
      await _player.play(AssetSource('fail.mp3'));
    } else {
      await _player.play(AssetSource('win.mp3'));
    }

    final RegExp regex = RegExp(r'(\d+)%');
    final match = regex.firstMatch(item.text);
    int? discountPercent;
    if (match != null) {
      discountPercent = int.parse(match.group(1)!);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double amount = 0.0;
        double finalPrice = 0.0;
        double discountAmount = 0.0;
        TextEditingController amountController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isJackpot ? const Color(0xFFFFD700) : (isBadResult ? Colors.redAccent : const Color(0xFFDAA520)),
                        width: isJackpot ? 4 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isJackpot ? Colors.amber.withOpacity(0.5) : Colors.black54, 
                          blurRadius: 20
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBadResult ? "¡CASI!" : (isJackpot ? "¡FELICIDADES!" : "¡GANASTE!"), 
                          style: const TextStyle(color: Colors.white54, fontSize: 16)
                        ),
                        const SizedBox(height: 10),
                        Icon(
                          isBadResult ? Icons.thumb_down : Icons.emoji_events, 
                          size: 60, 
                          color: isJackpot ? const Color(0xFFFFD700) : (isBadResult ? Colors.redAccent : const Color(0xFFDAA520))
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.text.replaceAll('\n', ' '), 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        const SizedBox(height: 20),

                        if (discountPercent != null && !isBadResult) ...[
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 10),
                          const Text("Ingresa el monto de la compra:", style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 10),
                          
                          TextField(
                            controller: amountController,
                            autofocus: false, 
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsSeparatorInputFormatter(),
                            ],
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: "\$0",
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                            ),
                            onChanged: (val) {
                              setStateDialog(() {
                                String cleanVal = val.replaceAll('.', '');
                                if (cleanVal.isEmpty) {
                                  amount = 0.0;
                                } else {
                                  amount = double.tryParse(cleanVal) ?? 0.0;
                                }
                                discountAmount = (amount * discountPercent!) / 100;
                                finalPrice = amount - discountAmount;
                              });
                            },
                          ),
                          
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Descuento:", style: TextStyle(color: Colors.redAccent)),
                              Text("- \$${_formatNumber(discountAmount)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL A COBRAR:", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                              Text("\$${_formatNumber(finalPrice)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBadResult ? Colors.grey : const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(isBadResult ? 'VOLVER A INTENTAR' : (discountPercent != null ? 'COBRAR' : 'RECLAMAR PREMIO')),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  // --- FORMATTER ---
  String _formatNumber(double number) {
    String s = number.toStringAsFixed(2); 
    List<String> parts = s.split('.');
    String wholePart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '00';

    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]}.';
    
    String formattedWhole = wholePart.replaceAllMapped(reg, mathFunc);

    if (decimalPart == "00") return formattedWhole;
    return "$formattedWhole,$decimalPart"; 
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wheelSize = min(size.width, size.height) * 0.85;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background/background.png"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black45, 
                  BlendMode.darken
                ),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD700),
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 15, offset: Offset(0, 5))
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Gira la ruleta y gana premios",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  SizedBox(
                    height: wheelSize,
                    width: wheelSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: wheelSize,
                          height: wheelSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                        
                        Transform.rotate(
                          angle: _randomOffset,
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: items.isEmpty 
                            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                            : items.length < 2
                                ? const Center(child: Text("Agrega premios"))
                                : FortuneWheel(
                                    selected: selected.stream,
                                    animateFirst: false,
                                    indicators: const <FortuneIndicator>[], 
                                    physics: CircularPanPhysics(
                                      duration: const Duration(seconds: 1),
                                      curve: Curves.decelerate,
                                    ),
                                    onFling: () {
                                      _spinWheel();
                                    },
                                    curve: Curves.easeOutQuart,
                                    duration: const Duration(seconds: 6), 
                                    rotationCount: 10,
                                    items: [
                                      for (var i = 0; i < items.length; i++)
                                        _buildFortuneItem(i),
                                    ],
                                  ),
                          ),
                        ),

                        const Positioned(
                          top: 0,
                          child: SizedBox(
                            height: 50,
                            width: 50,
                            child: TriangleIndicator(
                              color: Color(0xFFE74C3C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  GestureDetector(
                    onTap: _isSpinning || items.length < 2 ? null : _spinWheel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSpinning 
                            ? [Colors.grey, Colors.black] 
                            : [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          if (!_isSpinning)
                            BoxShadow(
                              color: const Color(0xFFFFA500).withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Text(
                        _isSpinning ? 'GIRANDO...' : 'GIRAR AHORA',
                        style: TextStyle(
                          color: _isSpinning ? Colors.white54 : Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón volver
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
                tooltip: "Volver",
              ),
            ),
          ),

          // Botón settings
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: _openSettings,
                tooltip: "Configurar Premios",
              ),
            ),
          ),
        ],
      ),
    );
  }

  FortuneItem _buildFortuneItem(int i) {
    if (i >= items.length) return const FortuneItem(child: Text(""));
    final item = items[i];
    final bool isJackpot = item.isJackpot;

    return FortuneItem(
      child: Padding(
        padding: const EdgeInsets.only(left: 40.0), 
        child: Text(
          item.text.toUpperCase(),
          textAlign: TextAlign.start,
          style: TextStyle(
            color: isJackpot ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isJackpot ? 13 : 12, 
            shadows: [
              Shadow(
                color: isJackpot ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5), 
                blurRadius: 2, 
                offset: const Offset(1,1)
              )
            ]
          ),
        ),
      ),
      style: FortuneItemStyle(
        color: isJackpot ? const Color(0xFFFFD700) : _getSliceColor(i), 
        borderColor: isJackpot ? const Color(0xFFDAA520) : Colors.black.withOpacity(0.2),
        borderWidth: isJackpot ? 2 : 1, 
      ),
    );
  }

  Color _getSliceColor(int index) {
    const colors = [
      Color(0xFFE74C3C),
      Color(0xFF3498DB),
      Color(0xFF2ECC71),
      Color(0xFF9B59B6),
      Color(0xFFE67E22),
      Color(0xFF1ABC9C),
    ];
    return colors[index % colors.length];
  }
}

// --- CLASE PARA PONER LOS PUNTOS AUTOMÁTICAMENTE ---
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    String value = newValue.text.replaceAll('.', '');
    String newText = _formatWithDots(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  String _formatWithDots(String s) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]}.';
    return s.replaceAllMapped(reg, mathFunc);
  }
}