import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const RetroTankGameApp());
}

class RetroTankGameApp extends StatelessWidget {
  const RetroTankGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Tank Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GameScreen(),
    );
  }
}

// --- MODEL DATA GAME ---
class Tank {
  double x;
  double y;
  double w;
  double h;
  double speed;

  Tank({
    this.x = 20,
    this.y = 0,
    this.w = 36,
    this.h = 36,
    this.speed = 220,
  });
}

class Enemy {
  double x;
  double y;
  double w;
  double h;
  double speed;
  double shootTimer;

  Enemy({
    required this.x,
    required this.y,
    this.w = 32,
    this.h = 32,
    required this.speed,
    required this.shootTimer,
  });
}

class Bullet {
  double x;
  double y;
  double w;
  double h;
  double speed;

  Bullet({
    required this.x,
    required this.y,
    this.w = 8,
    this.h = 4,
    required this.speed,
  });
}

class ActiveLaser {
  double y;
  double h;
  double timer;

  ActiveLaser({
    required this.y,
    required this.h,
    this.timer = 0.4,
  });
}

class Explosion {
  double x;
  double y;
  double radius;
  double maxRadius;
  double alpha;

  Explosion({
    required this.x,
    required this.y,
    this.radius = 4,
    this.maxRadius = 18,
    this.alpha = 1.0,
  });
}

class GroundDetail {
  double x;
  double y;
  double w;
  double h;
  int type;

  GroundDetail({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.type,
  });
}

enum GameState { start, playing, paused, gameover }

// --- SCREEN UTAMA ---
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  Duration _lastElapsed = Duration.zero;

  GameState gameState = GameState.start;
  int score = 0;
  int baseHp = 3;
  double laserGauge = 0.0;
  double spawnTimer = 0.0;

  Tank tank = Tank();
  List<Enemy> enemies = [];
  List<Bullet> bullets = [];
  List<Bullet> enemyBullets = [];
  List<Explosion> explosions = [];
  List<GroundDetail> groundDetails = [];
  ActiveLaser? activeLaser;

  bool isUpPressed = false;
  bool isDownPressed = false;

  Size canvasSize = Size.zero;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _generateGroundDetails(Size size) {
    groundDetails.clear();
    int numDetails = ((size.width * size.height) / 3000).floor();
    for (int i = 0; i < numDetails; i++) {
      groundDetails.add(GroundDetail(
        x: _random.nextDouble() * size.width,
        y: 12 + _random.nextDouble() * (size.height - 24),
        w: _random.nextBool() ? 4 : 8,
        h: _random.nextBool() ? 4 : 8,
        type: _random.nextInt(3),
      ));
    }
  }

  void startGame() {
    setState(() {
      score = 0;
      baseHp = 3;
      laserGauge = 0.0;
      enemies.clear();
      bullets.clear();
      enemyBullets.clear();
      explosions.clear();
      activeLaser = null;
      spawnTimer = 0.0;
      if (canvasSize.height > 0) {
        tank.y = canvasSize.height / 2 - tank.h / 2;
      }
      gameState = GameState.playing;
    });

    _lastElapsed = Duration.zero;
    if (!_ticker.isTicking) {
      _ticker.start();
    }
  }

  void togglePause() {
    setState(() {
      if (gameState == GameState.playing) {
        gameState = GameState.paused;
      } else if (gameState == GameState.paused) {
        gameState = GameState.playing;
      }
    });
  }

  void addGauge(double val) {
    setState(() {
      laserGauge = (laserGauge + val).clamp(0.0, 100.0);
    });
  }

  void takeDamage() {
    setState(() {
      baseHp--;
      createExplosion(tank.x + tank.w / 2, tank.y + tank.h / 2);
      if (baseHp <= 0) {
        gameState = GameState.gameover;
      }
    });
  }

  void shootBullet() {
    if (gameState != GameState.playing) return;
    SystemSound.play(SystemSoundType.click); // Sound Feedback Sederhana
    setState(() {
      bullets.add(Bullet(
        x: tank.x + tank.w + 4,
        y: tank.y + tank.h / 2 - 2,
        speed: 450,
      ));
    });
  }

  void fireLaser() {
    if (gameState != GameState.playing || laserGauge < 100) return;
    setState(() {
      laserGauge = 0.0;
      double laserHeight = 30.0;
      double laserY = tank.y + tank.h / 2 - laserHeight / 2;

      activeLaser = ActiveLaser(y: laserY, h: laserHeight, timer: 0.4);

      // Hancurkan musuh & peluru musuh di area laser
      for (int i = enemies.length - 1; i >= 0; i--) {
        var e = enemies[i];
        if (e.y + e.h >= laserY && e.y <= laserY + laserHeight) {
          createExplosion(e.x + e.w / 2, e.y + e.h / 2);
          enemies.removeAt(i);
          score += 150;
        }
      }
      for (int i = enemyBullets.length - 1; i >= 0; i--) {
        var eb = enemyBullets[i];
        if (eb.y + eb.h >= laserY && eb.y <= laserY + laserHeight) {
          enemyBullets.removeAt(i);
        }
      }
    });
  }

  void createExplosion(double x, double y) {
    explosions.add(Explosion(x: x, y: y));
  }

  void _onTick(Duration elapsed) {
    if (gameState != GameState.playing) {
      _lastElapsed = elapsed;
      return;
    }

    double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt > 0.1) dt = 0.1;

    setState(() {
      // Gauge Pasif
      if (laserGauge < 100) addGauge(3 * dt);

      // Pergerakan Player
      if (isUpPressed) tank.y -= tank.speed * dt;
      if (isDownPressed) tank.y += tank.speed * dt;

      double minY = 12;
      double maxY = canvasSize.height - tank.h - 12;
      tank.y = tank.y.clamp(minY, maxY);

      // Spawn Musuh
      spawnTimer += dt;
      if (spawnTimer > 1.8) {
        spawnTimer = 0.0;
        enemies.add(Enemy(
          x: canvasSize.width,
          y: _random.nextDouble() * (canvasSize.height - 56) + 14,
          speed: _random.nextDouble() * 20 + 35,
          shootTimer: _random.nextDouble() * 1.5 + 0.5,
        ));
      }

      // AI Musuh (Menembak)
      for (var e in enemies) {
        e.shootTimer -= dt;
        if (e.shootTimer <= 0) {
          e.shootTimer = _random.nextDouble() * 2.5 + 1.5;
          enemyBullets.add(Bullet(
            x: e.x - 6,
            y: e.y + e.h / 2 - 2,
            speed: 250,
          ));
        }
      }

      // Update Peluru Player
      for (int i = bullets.length - 1; i >= 0; i--) {
        bullets[i].x += bullets[i].speed * dt;
        if (bullets[i].x > canvasSize.width) {
          bullets.removeAt(i);
        }
      }

      // Update Peluru Musuh
      for (int i = enemyBullets.length - 1; i >= 0; i--) {
        var eb = enemyBullets[i];
        eb.x -= eb.speed * dt;

        // Kena Player
        if (eb.x <= tank.x + tank.w &&
            eb.x + eb.w >= tank.x &&
            eb.y + eb.h >= tank.y &&
            eb.y <= tank.y + tank.h) {
          enemyBullets.removeAt(i);
          takeDamage();
          continue;
        }

        // Tangkis Peluru Player
        for (int j = bullets.length - 1; j >= 0; j--) {
          var pb = bullets[j];
          if (pb.x + pb.w >= eb.x &&
              pb.x <= eb.x + eb.w &&
              pb.y + pb.h >= eb.y &&
              pb.y <= eb.y + eb.h) {
            createExplosion(eb.x, eb.y);
            bullets.removeAt(j);
            enemyBullets.removeAt(i);
            break;
          }
        }

        if (i < enemyBullets.length && enemyBullets[i].x < 0) {
          enemyBullets.removeAt(i);
        }
      }

      // Update Musuh & Tabrakan
      for (int i = enemies.length - 1; i >= 0; i--) {
        enemies[i].x -= enemies[i].speed * dt;

        // Tembus garis player
        if (enemies[i].x <= tank.x + tank.w) {
          enemies.removeAt(i);
          takeDamage();
          continue;
        }

        // Kena peluru player
        for (int j = bullets.length - 1; j >= 0; j--) {
          var b = bullets[j];
          var e = enemies[i];

          if (b.x + b.w >= e.x &&
              b.x <= e.x + e.w &&
              b.y + b.h >= e.y &&
              b.y <= e.y + e.h) {
            createExplosion(e.x + e.w / 2, e.y + e.h / 2);
            enemies.removeAt(i);
            bullets.removeAt(j);
            score += 100;
            addGauge(15);
            break;
          }
        }
      }

      // Update Laser
      if (activeLaser != null) {
        activeLaser!.timer -= dt;
        if (activeLaser!.timer <= 0) activeLaser = null;
      }

      // Update Ledakan
      for (int i = explosions.length - 1; i >= 0; i--) {
        explosions[i].radius += 40 * dt;
        explosions[i].alpha -= 2 * dt;
        if (explosions[i].alpha <= 0) {
          explosions.removeAt(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // GAME VIEW (65%)
            Expanded(
              flex: 65,
              child: Container(
                color: const Color(0xFF5C4033),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (canvasSize.width != constraints.maxWidth ||
                        canvasSize.height != constraints.maxHeight) {
                      canvasSize =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      _generateGroundDetails(canvasSize);
                      if (gameState == GameState.start) {
                        tank.y = canvasSize.height / 2 - tank.h / 2;
                      }
                    }

                    return Stack(
                      children: [
                        // RENDER CANVAS GAME
                        CustomPaint(
                          size: canvasSize,
                          painter: GamePainter(
                            tank: tank,
                            enemies: enemies,
                            bullets: bullets,
                            enemyBullets: enemyBullets,
                            explosions: explosions,
                            groundDetails: groundDetails,
                            activeLaser: activeLaser,
                          ),
                        ),

                        // HUD OVERLAY
                        Positioned(
                          top: 10,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "LIFE: ${"❤️" * baseHp}",
                                    style: const TextStyle(
                                      color: Color(0xFFFF5555),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF222222),
                                      foregroundColor: const Color(0xFFFFFF55),
                                      side: const BorderSide(
                                          color: Color(0xFFFFFF55), width: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                    onPressed: togglePause,
                                    child: Text(
                                      gameState == GameState.paused
                                          ? "RESUME"
                                          : "PAUSE",
                                      style: const TextStyle(fontSize: 8),
                                    ),
                                  ),
                                  Text(
                                    "SCORE: $score",
                                    style: const TextStyle(
                                      color: Color(0xFFFFFF55),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text(
                                    "LASER GAUGE: ",
                                    style: TextStyle(
                                      color: Color(0xFF00FFFF),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF222222),
                                        border: Border.all(
                                            color: const Color(0xFF00FFFF),
                                            width: 1.5),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: laserGauge / 100.0,
                                        child: Container(
                                          color: const Color(0xFF00FFFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // START OVERLAY
                        if (gameState == GameState.start)
                          _buildOverlay(
                            title: "RETRO TANK BATTLE",
                            titleColor: const Color(0xFFFFCC00),
                            desc:
                                "Awas! Tank musuh berjalan pelan tapi bisa menembak balik! Hancurkan mereka dan gunakan Super Laser!",
                            btnText: "START GAME",
                            onPressed: startGame,
                          ),

                        // PAUSE OVERLAY
                        if (gameState == GameState.paused)
                          _buildOverlay(
                            title: "GAME PAUSED",
                            titleColor: const Color(0xFFFFFF55),
                            desc: "",
                            btnText: "RESUME",
                            onPressed: togglePause,
                          ),

                        // GAMEOVER OVERLAY
                        if (gameState == GameState.gameover)
                          _buildOverlay(
                            title: "MISSION FAILED",
                            titleColor: const Color(0xFFFF3333),
                            desc: "TOTAL SCORE: $score",
                            btnText: "TRY AGAIN",
                            onPressed: startGame,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // CONTROLS (35%)
            Expanded(
              flex: 35,
              child: Container(
                color: const Color(0xFF111111),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // MOVE BUTTONS
                    SizedBox(
                      width: 100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                            label: "▲",
                            onTapDown: () => isUpPressed = true,
                            onTapUp: () => isUpPressed = false,
                          ),
                          const SizedBox(height: 8),
                          _buildControlButton(
                            label: "▼",
                            onTapDown: () => isDownPressed = true,
                            onTapUp: () => isDownPressed = false,
                          ),
                        ],
                      ),
                    ),

                    // ACTION BUTTONS
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFFFF6666), width: 3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size.fromHeight(90),
                              ),
                              onPressed: shootBullet,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("FIRE!",
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 4),
                                  Text("💣", style: TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: laserGauge >= 100
                                    ? const Color(0xFF0088CC)
                                    : const Color(0xFF333333),
                                foregroundColor: laserGauge >= 100
                                    ? Colors.white
                                    : const Color(0xFF888888),
                                side: BorderSide(
                                  color: laserGauge >= 100
                                      ? const Color(0xFF00FFFF)
                                      : const Color(0xFF555555),
                                  width: 3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size.fromHeight(90),
                              ),
                              onPressed: laserGauge >= 100 ? fireLaser : null,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("ULTIMATE",
                                      style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 4),
                                  Text("⚡", style: TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      child: Container(
        height: 46,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          border: Border.all(color: const Color(0xFF444444), width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
                color: Color(0xFF55FF55),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay({
    required String title,
    required Color titleColor,
    required String desc,
    required String btnText,
    required VoidCallback onPressed,
  }) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: titleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00AA00),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF55FF55), width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: onPressed,
            child: Text(
              btnText,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// --- RENDERER CUSTOM PAINTER ---
class GamePainter extends CustomPainter {
  final Tank tank;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<Bullet> enemyBullets;
  final List<Explosion> explosions;
  final List<GroundDetail> groundDetails;
  final ActiveLaser? activeLaser;

  GamePainter({
    required this.tank,
    required this.enemies,
    required this.bullets,
    required this.enemyBullets,
    required this.explosions,
    required this.groundDetails,
    required this.activeLaser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Tanah (Background)
    paint.color = const Color(0xFF6E4726);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Detail Tanah
    for (var d in groundDetails) {
      if (d.type == 0) {
        paint.color = const Color(0xFF4A2E16);
      } else if (d.type == 1) {
        paint.color = const Color(0xFF8C8275);
      } else {
        paint.color = const Color(0xFF3B220C);
      }
      canvas.drawRect(Rect.fromLTWH(d.x, d.y, d.w, d.h), paint);
    }

    // Rumput Atas/Bawah
    paint.color = const Color(0xFF33AA33);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 10), paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 10, size.width, 10), paint);

    paint.color = const Color(0xFF55FF55);
    for (double x = 0; x < size.width; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x, 10, 4, 3), paint);
      canvas.drawRect(Rect.fromLTWH(x + 6, size.height - 13, 4, 3), paint);
    }

    // Grid Retro
    paint.color = const Color(0x26000000);
    paint.strokeWidth = 1;
    paint.style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    paint.style = PaintingStyle.fill;

    // 2. Tank Player (Hijau)
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(tank.x, tank.y, tank.w, 6), paint);
    canvas.drawRect(Rect.fromLTWH(tank.x, tank.y + tank.h - 6, tank.w, 6), paint);

    paint.color = const Color(0xFF00AA00);
    canvas.drawRect(Rect.fromLTWH(tank.x + 4, tank.y + 4, tank.w - 8, tank.h - 8), paint);

    paint.color = const Color(0xFF55FF55);
    canvas.drawRect(Rect.fromLTWH(tank.x + 10, tank.y + 10, 14, 14), paint);

    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(tank.x + 20, tank.y + 15, 16, 6), paint);

    // 3. Tank Musuh (Merah)
    for (var e in enemies) {
      paint.color = const Color(0xFF333333);
      canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, 5), paint);
      canvas.drawRect(Rect.fromLTWH(e.x, e.y + e.h - 5, e.w, 5), paint);

      paint.color = const Color(0xFFAA0000);
      canvas.drawRect(Rect.fromLTWH(e.x + 4, e.y + 3, e.w - 8, e.h - 6), paint);

      paint.color = const Color(0xFFFF5555);
      canvas.drawRect(Rect.fromLTWH(e.x + 10, e.y + 9, 12, 12), paint);

      // Meriam Musuh
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(e.x - 8, e.y + 13, 12, 5), paint);
    }

    // 4. Peluru Player (Kuning)
    paint.color = const Color(0xFFFFFF00);
    for (var b in bullets) {
      canvas.drawRect(Rect.fromLTWH(b.x, b.y, b.w, b.h), paint);
    }

    // 5. Peluru Musuh (Merah Cerah)
    paint.color = const Color(0xFFFF3300);
    for (var eb in enemyBullets) {
      canvas.drawRect(Rect.fromLTWH(eb.x, eb.y, eb.w, eb.h), paint);
    }

    // 6. Super Laser
    if (activeLaser != null) {
      paint.color = const Color(0x6600FFFF);
      canvas.drawRect(
          Rect.fromLTWH(
              tank.x + tank.w, activeLaser!.y - 6, size.width, activeLaser!.h + 12),
          paint);

      paint.color = const Color(0xFF00FFFF);
      canvas.drawRect(
          Rect.fromLTWH(
              tank.x + tank.w, activeLaser!.y, size.width, activeLaser!.h),
          paint);

      paint.color = Colors.white;
      canvas.drawRect(
          Rect.fromLTWH(
              tank.x + tank.w, activeLaser!.y + 6, size.width, activeLaser!.h - 12),
          paint);
    }

    // 7. Ledakan
    for (var exp in explosions) {
      paint.color = const Color(0xFFFF5500).withOpacity(exp.alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(exp.x, exp.y), exp.radius, paint);

      paint.color = const Color(0xFFFFFF00).withOpacity(exp.alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(exp.x, exp.y), exp.radius * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
