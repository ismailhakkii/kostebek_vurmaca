import 'dart:math';
import 'dart:async' as async;
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();
  
  runApp(
    MaterialApp(
      home: Scaffold(
        body: GameWidget(
          game: KostebekOyunu(),
        ),
      ),
    ),
  );
}

class KostebekOyunu extends FlameGame with TapCallbacks {
  // Oyun değişkenleri
  int puan = 0;
  int sure = 60; // Oyun süresi (saniye)
  bool oyunBitti = false;
  final Random random = Random();
  late TimerComponent oyunSuresi;
  late TextComponent puanText;
  late TextComponent sureText;
  
  // Köstebek ve delik ayarları
  final int delikSayisi = 15; // Piramit için en uygun sayı
  final List<Delik> delikler = [];
  final double delikBoyutu = 80.0;
  final double aralik = 20.0;
  
  @override
  Future<void> onLoad() async {
    // Arka plan
    add(RectangleComponent(
      size: Vector2(size.x, size.y),
      paint: Paint()..color = const Color(0xFF8B4513), // Toprak rengi
    ));
    
    // Puan ve süre göstergesi
    puanText = TextComponent(
      text: 'Puan: 0',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24.0,
          color: Colors.white,
        ),
      ),
      position: Vector2(20, 20),
    );
    add(puanText);
    
    sureText = TextComponent(
      text: 'Süre: 60',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24.0,
          color: Colors.white,
        ),
      ),
      position: Vector2(size.x - 120, 20),
    );
    add(sureText);
    
    // Piramit şeklinde delikleri oluştur
    // 5 satır halinde: 1, 2, 3, 4, 5 delik şeklinde
    final List<int> satirdakiDelikSayisi = [1, 2, 3, 4, 5];
    
    // Piramit genişliği (en alt satırdaki toplam genişlik)
    final double enbuyukSatirGenislik = 
        satirdakiDelikSayisi.last * delikBoyutu + 
        (satirdakiDelikSayisi.last - 1) * aralik;
    
    // Piramidin toplam yüksekliği
    final double toplamYukseklik = 
        satirdakiDelikSayisi.length * delikBoyutu + 
        (satirdakiDelikSayisi.length - 1) * aralik;
    
    // Piramidin başlangıç koordinatları (sol üst köşesi)
    final double baslangicX = (size.x - enbuyukSatirGenislik) / 2;
    final double baslangicY = (size.y - toplamYukseklik) / 2;
    
    int delikIndex = 0;
    for (int satir = 0; satir < satirdakiDelikSayisi.length; satir++) {
      final int delikSayi = satirdakiDelikSayisi[satir];
      
      // Mevcut satırın genişliği
      final double satirGenislik = 
          delikSayi * delikBoyutu + (delikSayi - 1) * aralik;
      
      // Satırın X ofset'i (merkezlemek için)
      final double satirXOffset = 
          (enbuyukSatirGenislik - satirGenislik) / 2;
      
      for (int i = 0; i < delikSayi; i++) {
        final delik = Delik(
          position: Vector2(
            baslangicX + satirXOffset + i * (delikBoyutu + aralik),
            baslangicY + satir * (delikBoyutu + aralik),
          ),
          size: Vector2(delikBoyutu, delikBoyutu),
        );
        delikler.add(delik);
        add(delik);
        
        delikIndex++;
        if (delikIndex >= delikSayisi) break;
      }
      
      if (delikIndex >= delikSayisi) break;
    }
    
    // Oyun süresini başlat
    oyunSuresi = TimerComponent(
      period: 1,
      repeat: true,
      onTick: () {
        sure--;
        sureText.text = 'Süre: $sure';
        
        if (sure <= 0) {
          oyunBitti = true;
          oyunSuresi.timer.stop();
          add(
            TextComponent(
              text: 'OYUN BİTTİ! Puan: $puan',
              textRenderer: TextPaint(
                style: const TextStyle(
                  fontSize: 36.0,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              position: Vector2(size.x / 2, size.y / 2),
              anchor: Anchor.center,
            ),
          );
        }
      },
    );
    add(oyunSuresi);
    
    // Köstebek çıkarma zamanlayıcısı
    async.Timer.periodic(
      const Duration(milliseconds: 800),
      (timer) {
        if (!oyunBitti) {
          yeniKostebekCikar();
        } else {
          timer.cancel();
        }
      },
    );
  }
  
  void yeniKostebekCikar() {
    // Rastgele bir delik seç
    final bosDelikler = delikler.where((delik) => !delik.kostebekAktif).toList();
    if (bosDelikler.isNotEmpty) {
      final int rastgeleIndex = random.nextInt(bosDelikler.length);
      final Delik seciliDelik = bosDelikler[rastgeleIndex];
      seciliDelik.kostebekGoster();
    }
  }
  
  @override
  void onTapUp(TapUpEvent event) {
    if (oyunBitti) return;
    
    final tapPosition = event.canvasPosition;
    for (final delik in delikler) {
      if (delik.containsPoint(tapPosition) && delik.kostebekAktif) {
        delik.kostebekVur();
        puan += 10;
        puanText.text = 'Puan: $puan';
        break;
      }
    }
  }
}

class Delik extends PositionComponent {
  bool kostebekAktif = false;
  late TextComponent kostebekEmoji;
  late CircleComponent delikSprite;
  late TimerComponent kostebekTimer;
  
  Delik({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);
  
  @override
  Future<void> onLoad() async {
    // Yuvarlak delik
    delikSprite = CircleComponent(
      radius: size.x / 2,
      paint: Paint()..color = const Color(0xFF3E2723), // Koyu kahverengi
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
    add(delikSprite);
    
    // Köstebek emoji
    kostebekEmoji = TextComponent(
      text: '😶‍🌫️', // Hamster emoji (köstebeğe en yakın emoji)
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: size.x * 0.6,
        ),
      ),
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
    // Başlangıçta köstebeği ekleme
    // (görünmez olarak başlatmak için)
    
    // Köstebek zamanı
    kostebekTimer = TimerComponent(
      period: 2,
      repeat: false,
      removeOnFinish: false,
      onTick: () {
        kostebekAktif = false;
        if (children.contains(kostebekEmoji)) {
          remove(kostebekEmoji);
        }
      },
    );
    add(kostebekTimer);
  }
  
  void kostebekGoster() {
    kostebekAktif = true;
    if (!children.contains(kostebekEmoji)) {
      add(kostebekEmoji);
    }
    kostebekTimer.timer.start();
  }
  
  void kostebekVur() {
    kostebekAktif = false;
    if (children.contains(kostebekEmoji)) {
      remove(kostebekEmoji);
    }
    kostebekTimer.timer.stop();
  }
}