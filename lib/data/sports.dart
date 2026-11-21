import 'package:flutter/material.dart';

/// Modos deportivos de la SDK Veepoo (`ESportType`, vpprotocol 2.3.96.15). Los nombres [key] coinciden con la enum del .aar
/// (comprobado leyendo la propia clase). Los identificadores (id) vienen de la documentación api_en.md; los marcados
/// `idVerified: false` NO aparecen en el documento y se han deducido por el hueco en la numeración: no verificados.
/// La SDK no ofrece una lista de modos soportados por la pulsera: se muestran todos y la banda decide (ver [SportMode]).
enum SportGroup {
  run('Carrera', Icons.directions_run),
  walk('Caminata y montaña', Icons.hiking),
  bike('Ciclismo y ruedas', Icons.directions_bike),
  gym('Gimnasio y fitness', Icons.fitness_center),
  mind('Mente y cuerpo', Icons.self_improvement),
  dance('Baile', Icons.music_note),
  combat('Combate', Icons.sports_martial_arts),
  ball('Pelota y equipo', Icons.sports_soccer),
  racket('Raqueta', Icons.sports_tennis),
  water('Agua', Icons.pool),
  snow('Nieve y hielo', Icons.downhill_skiing),
  other('Otros', Icons.sports);

  final String label; final IconData icon;
  const SportGroup(this.label, this.icon);
}

class SportMode {
  final int id; final String key, name; final SportGroup group; final IconData icon;
  /// Se practica normalmente al aire libre (el GPS solo lo aporta la pulsera si el modo lo usa: no verificado por modo).
  final bool outdoor;
  final bool idVerified;
  /// Modo de recorrido: lo principal es la ruta (GPS), la distancia y el ritmo. Si no, es de interior / sin GPS: duración, pulso, calorías.
  bool get tracksRoute => outdoor && const {SportGroup.run, SportGroup.walk, SportGroup.bike, SportGroup.water, SportGroup.snow}.contains(group);
  const SportMode(this.id, this.key, this.name, this.group, this.icon, {this.outdoor = false, this.idVerified = true});
}

const sportModes = <SportMode>[
  SportMode(1, 'OUTDOOR_RUNNING', 'Correr al aire libre', SportGroup.run, Icons.directions_run, outdoor: true),
  SportMode(2, 'OUTDOOR_WALK', 'Caminar al aire libre', SportGroup.walk, Icons.directions_walk, outdoor: true),
  SportMode(3, 'INDOOR_RUNNING', 'Correr en interior', SportGroup.run, Icons.directions_run),
  SportMode(4, 'INDOOR_WALK', 'Caminar en interior', SportGroup.walk, Icons.directions_walk),
  SportMode(5, 'HIKE', 'Senderismo', SportGroup.walk, Icons.hiking, outdoor: true),
  SportMode(6, 'TREADMILLS', 'Stepper (escaladora)', SportGroup.gym, Icons.stairs),
  SportMode(7, 'OUTDOOR_RIDING', 'Ciclismo al aire libre', SportGroup.bike, Icons.directions_bike, outdoor: true),
  SportMode(8, 'INDOOR_RIDING', 'Ciclismo en interior', SportGroup.bike, Icons.pedal_bike),
  SportMode(9, 'ELLIPTICAL', 'Elíptica', SportGroup.gym, Icons.fitness_center),
  SportMode(10, 'ROWING_MACHINE', 'Máquina de remo', SportGroup.gym, Icons.rowing),
  SportMode(11, 'Mountaineering', 'Montañismo', SportGroup.walk, Icons.terrain, outdoor: true),
  SportMode(12, 'SWIM', 'Natación', SportGroup.water, Icons.pool),
  SportMode(13, 'Sit_Ups', 'Abdominales', SportGroup.gym, Icons.self_improvement),
  SportMode(14, 'SKI', 'Esquí', SportGroup.snow, Icons.downhill_skiing, outdoor: true),
  SportMode(15, 'JUMP_ROPE', 'Comba', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(16, 'YOGA', 'Yoga', SportGroup.mind, Icons.self_improvement),
  SportMode(17, 'PING_PONG', 'Tenis de mesa', SportGroup.racket, Icons.sports_tennis),
  SportMode(18, 'BASKETBALL', 'Baloncesto', SportGroup.ball, Icons.sports_basketball),
  SportMode(19, 'VOLLEYBALL', 'Voleibol', SportGroup.ball, Icons.sports_volleyball),
  SportMode(20, 'FOOTBALL', 'Fútbol', SportGroup.ball, Icons.sports_soccer, outdoor: true),
  SportMode(21, 'BADMINTON', 'Bádminton', SportGroup.racket, Icons.sports_tennis),
  SportMode(22, 'TENNIS', 'Tenis', SportGroup.racket, Icons.sports_tennis, outdoor: true),
  SportMode(23, 'CLIMB_STAIRS', 'Subir escaleras', SportGroup.gym, Icons.stairs),
  SportMode(24, 'FITNESS', 'Fitness', SportGroup.gym, Icons.fitness_center),
  SportMode(25, 'WEIGHTLIFTING', 'Halterofilia', SportGroup.gym, Icons.fitness_center),
  SportMode(26, 'DIVING', 'Buceo', SportGroup.water, Icons.scuba_diving),
  SportMode(27, 'BOXING', 'Boxeo', SportGroup.combat, Icons.sports_mma),
  SportMode(28, 'GYM_BALL', 'Pelota de fitness', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(29, 'SQUAT_TRAINING', 'Sentadillas', SportGroup.gym, Icons.fitness_center),
  SportMode(30, 'TRIATHLON', 'Triatlón', SportGroup.run, Icons.emoji_events, outdoor: true),
  SportMode(31, 'DANCE', 'Baile', SportGroup.dance, Icons.music_note),
  SportMode(32, 'HIIT', 'HIIT', SportGroup.gym, Icons.bolt),
  SportMode(33, 'ROCK_CLIMBING', 'Escalada', SportGroup.walk, Icons.terrain),
  SportMode(34, 'SPORTS', 'Deporte general', SportGroup.other, Icons.sports),
  SportMode(35, 'BALLS', 'Deportes de pelota', SportGroup.ball, Icons.sports_handball),
  SportMode(36, 'FITNESS_GAME', 'Juego de fitness', SportGroup.other, Icons.sports_esports),
  SportMode(37, 'FREE_TIME', 'Tiempo libre', SportGroup.other, Icons.park),
  SportMode(38, 'AEROBICS', 'Aeróbic', SportGroup.gym, Icons.directions_run),
  SportMode(39, 'GYMNASTICS', 'Gimnasia', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(40, 'FLOOR_EXERCISE', 'Gimnasia de suelo', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(41, 'HORIZONTALBAR', 'Barra fija', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(42, 'PARALLELBARS', 'Barras paralelas', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(43, 'TRAMPOLINE', 'Cama elástica', SportGroup.gym, Icons.sports_gymnastics),
  SportMode(44, 'TRACKANDFIELD', 'Atletismo', SportGroup.run, Icons.directions_run, outdoor: true),
  SportMode(45, 'MARATHON', 'Maratón', SportGroup.run, Icons.directions_run, outdoor: true),
  SportMode(46, 'PUSH_UPS', 'Flexiones', SportGroup.gym, Icons.fitness_center),
  SportMode(47, 'DUMBBELL', 'Mancuernas', SportGroup.gym, Icons.fitness_center),
  SportMode(48, 'RUGBY_FOOTBALL', 'Rugby', SportGroup.ball, Icons.sports_rugby, outdoor: true, idVerified: false),
  SportMode(49, 'HANDBALL', 'Balonmano', SportGroup.ball, Icons.sports_handball),
  SportMode(50, 'BASEBALL_SOFTBALL', 'Béisbol/sóftbol', SportGroup.ball, Icons.sports_baseball, outdoor: true, idVerified: false),
  SportMode(51, 'BASEBALL', 'Béisbol', SportGroup.ball, Icons.sports_baseball, outdoor: true),
  SportMode(52, 'HOCKEY', 'Hockey', SportGroup.ball, Icons.sports_hockey, outdoor: true),
  SportMode(53, 'GOLF', 'Golf', SportGroup.ball, Icons.sports_golf, outdoor: true),
  SportMode(54, 'BOWLING', 'Bolos', SportGroup.ball, Icons.sports_cricket),
  SportMode(55, 'BILLIARDS', 'Billar', SportGroup.other, Icons.sports_bar),
  SportMode(56, 'ROWING', 'Remo', SportGroup.water, Icons.rowing, outdoor: true),
  SportMode(57, 'SAILBOAT', 'Vela', SportGroup.water, Icons.sailing, outdoor: true),
  SportMode(58, 'SKATE', 'Patinaje', SportGroup.snow, Icons.ice_skating, outdoor: true),
  SportMode(59, 'CURLING', 'Curling', SportGroup.snow, Icons.ice_skating),
  SportMode(60, 'PUCK', 'Hockey (disco)', SportGroup.snow, Icons.sports_hockey),
  SportMode(61, 'SLEIGH', 'Trineo', SportGroup.snow, Icons.sledding, outdoor: true),
  SportMode(62, 'StrongWalk', 'Marcha rápida', SportGroup.walk, Icons.directions_walk, outdoor: true),
  SportMode(63, 'Treadmill', 'Cinta de correr', SportGroup.run, Icons.directions_run),
  SportMode(64, 'TrailRunning', 'Trail running', SportGroup.run, Icons.directions_run, outdoor: true),
  SportMode(65, 'RaceWalking', 'Marcha atlética', SportGroup.walk, Icons.directions_walk, outdoor: true),
  SportMode(66, 'MountainBiking', 'Bicicleta de montaña', SportGroup.bike, Icons.directions_bike, outdoor: true),
  SportMode(67, 'Bmx', 'BMX', SportGroup.bike, Icons.pedal_bike, outdoor: true),
  SportMode(68, 'Orienteering', 'Orientación', SportGroup.walk, Icons.explore, outdoor: true),
  SportMode(69, 'Fishing', 'Pesca', SportGroup.other, Icons.set_meal, outdoor: true),
  SportMode(70, 'Hunt', 'Caza', SportGroup.other, Icons.park, outdoor: true),
  SportMode(71, 'Skateboard', 'Monopatín', SportGroup.bike, Icons.skateboarding, outdoor: true),
  SportMode(72, 'RollerSkating', 'Patines en línea', SportGroup.bike, Icons.roller_skating, outdoor: true),
  SportMode(73, 'Parkour', 'Parkour', SportGroup.other, Icons.directions_run, outdoor: true),
  SportMode(74, 'Atv', 'Quad (ATV)', SportGroup.other, Icons.two_wheeler, outdoor: true),
  SportMode(75, 'Motocross', 'Motocross', SportGroup.other, Icons.two_wheeler, outdoor: true, idVerified: false),
  SportMode(76, 'ClimbingMachine', 'Máquina de escalada', SportGroup.gym, Icons.stairs),
  SportMode(77, 'SpinningBike', 'Ciclismo indoor (spinning)', SportGroup.bike, Icons.pedal_bike, idVerified: false),
  SportMode(78, 'IndoorFitness', 'Fitness en interior', SportGroup.gym, Icons.fitness_center),
  SportMode(79, 'MixedAerobic', 'Aeróbico mixto', SportGroup.gym, Icons.directions_run),
  SportMode(80, 'CrossTraining', 'Entrenamiento cruzado', SportGroup.gym, Icons.fitness_center),
  SportMode(81, 'BodybuildingExercise', 'Musculación', SportGroup.gym, Icons.fitness_center),
  SportMode(82, 'GroupGymnastics', 'Gimnasia en grupo', SportGroup.gym, Icons.sports_gymnastics, idVerified: false),
  SportMode(83, 'Kickboxing', 'Kickboxing', SportGroup.combat, Icons.sports_mma),
  SportMode(84, 'StrengthTraining', 'Entrenamiento de fuerza', SportGroup.gym, Icons.fitness_center),
  SportMode(85, 'SteppingTraining', 'Entrenamiento con step', SportGroup.gym, Icons.stairs),
  SportMode(86, 'CoreTraining', 'Core', SportGroup.gym, Icons.self_improvement),
  SportMode(87, 'FlexibilityTraining', 'Flexibilidad', SportGroup.mind, Icons.self_improvement),
  SportMode(88, 'FreeTraining', 'Entrenamiento libre', SportGroup.gym, Icons.fitness_center),
  SportMode(89, 'Pilates', 'Pilates', SportGroup.mind, Icons.self_improvement),
  SportMode(90, 'BattleRope', 'Cuerdas de batalla', SportGroup.gym, Icons.fitness_center),
  SportMode(91, 'Stretch', 'Estiramientos', SportGroup.mind, Icons.self_improvement),
  SportMode(92, 'SquareDance', 'Baile en plaza', SportGroup.dance, Icons.music_note),
  SportMode(93, 'BallroomDancing', 'Baile de salón', SportGroup.dance, Icons.music_note),
  SportMode(94, 'BellyDance', 'Danza del vientre', SportGroup.dance, Icons.music_note),
  SportMode(95, 'Ballet', 'Ballet', SportGroup.dance, Icons.music_note),
  SportMode(96, 'HipHop', 'Hip hop', SportGroup.dance, Icons.music_note),
  SportMode(97, 'Zumba', 'Zumba', SportGroup.dance, Icons.music_note),
  SportMode(98, 'LatinDance', 'Baile latino', SportGroup.dance, Icons.music_note),
  SportMode(99, 'Jazz', 'Jazz', SportGroup.dance, Icons.music_note),
  SportMode(100, 'HipHopDance', 'Danza hip hop', SportGroup.dance, Icons.music_note),
  SportMode(101, 'PoleDancing', 'Pole dance', SportGroup.dance, Icons.music_note),
  SportMode(102, 'BreakDance', 'Breakdance', SportGroup.dance, Icons.music_note),
  SportMode(103, 'NationalDance', 'Danza folclórica', SportGroup.dance, Icons.music_note),
  SportMode(104, 'ModernDance', 'Danza moderna', SportGroup.dance, Icons.music_note),
  SportMode(105, 'Disco', 'Disco', SportGroup.dance, Icons.music_note),
  SportMode(106, 'TapDance', 'Claqué', SportGroup.dance, Icons.music_note),
  SportMode(107, 'Wrestling', 'Lucha', SportGroup.combat, Icons.sports_kabaddi),
  SportMode(108, 'MartialArts', 'Artes marciales', SportGroup.combat, Icons.sports_martial_arts),
  SportMode(109, 'TaiChi', 'Tai chi', SportGroup.mind, Icons.self_improvement),
  SportMode(110, 'MuayThai', 'Muay thai', SportGroup.combat, Icons.sports_mma),
  SportMode(111, 'Judo', 'Judo', SportGroup.combat, Icons.sports_martial_arts),
  SportMode(112, 'Taekwondo', 'Taekwondo', SportGroup.combat, Icons.sports_martial_arts),
  SportMode(113, 'Karate', 'Kárate', SportGroup.combat, Icons.sports_martial_arts),
  SportMode(114, 'FreeSparring', 'Combate libre', SportGroup.combat, Icons.sports_mma),
  SportMode(115, 'Swordsmanship', 'Esgrima con espada', SportGroup.combat, Icons.sports_martial_arts),
  SportMode(116, 'Jujitsu', 'Jiu-jitsu', SportGroup.combat, Icons.sports_kabaddi),
  SportMode(117, 'Fencing', 'Esgrima', SportGroup.combat, Icons.sports_martial_arts),
  SportMode(118, 'BeachSoccer', 'Fútbol playa', SportGroup.ball, Icons.sports_soccer, outdoor: true),
  SportMode(119, 'BeachVolleyball', 'Voley playa', SportGroup.ball, Icons.sports_volleyball, outdoor: true),
  SportMode(120, 'Softball', 'Sóftbol', SportGroup.ball, Icons.sports_baseball, outdoor: true),
  SportMode(121, 'Squash', 'Squash', SportGroup.racket, Icons.sports_tennis),
  SportMode(122, 'Croquet', 'Croquet', SportGroup.ball, Icons.sports_golf, outdoor: true, idVerified: false),
  SportMode(123, 'Cricket', 'Críquet', SportGroup.ball, Icons.sports_cricket, outdoor: true),
  SportMode(124, 'Polo', 'Polo', SportGroup.ball, Icons.sports_score, outdoor: true),
  SportMode(125, 'Wallball', 'Pelota a pared', SportGroup.ball, Icons.sports_handball),
  SportMode(126, 'TakrawBall', 'Sepak takraw', SportGroup.ball, Icons.sports_volleyball),
  SportMode(127, 'Dodgeball', 'Balón prisionero', SportGroup.ball, Icons.sports_handball),
  SportMode(128, 'WaterPolo', 'Waterpolo', SportGroup.water, Icons.pool),
  SportMode(129, 'Shuttlecock', 'Volante', SportGroup.racket, Icons.sports_tennis),
  SportMode(130, 'IndoorSoccer', 'Fútbol sala', SportGroup.ball, Icons.sports_soccer),
  SportMode(131, 'SandbagBall', 'Pelota de arena', SportGroup.ball, Icons.sports_handball),
  SportMode(132, 'BocceBall', 'Bochas', SportGroup.ball, Icons.sports_baseball, outdoor: true),
  SportMode(133, 'Jaileyball', 'Jai alai', SportGroup.racket, Icons.sports_tennis),
  SportMode(134, 'Floorball', 'Floorball', SportGroup.ball, Icons.sports_hockey),
  SportMode(135, 'OutdoorBoating', 'Paseo en barca', SportGroup.water, Icons.directions_boat, outdoor: true),
  SportMode(136, 'Kayak', 'Kayak', SportGroup.water, Icons.kayaking, outdoor: true),
  SportMode(137, 'DragonBoat', 'Barco dragón', SportGroup.water, Icons.rowing, outdoor: true),
  SportMode(138, 'PaddleBoard', 'Paddle surf', SportGroup.water, Icons.surfing, outdoor: true),
  SportMode(139, 'IndoorFillingWaves', 'Olas en interior', SportGroup.water, Icons.surfing, idVerified: false),
  SportMode(140, 'Drifting', 'Rafting', SportGroup.water, Icons.kayaking, outdoor: true),
  SportMode(141, 'WaterSkiing', 'Esquí acuático', SportGroup.water, Icons.kitesurfing, outdoor: true),
  SportMode(142, 'Snowboarding', 'Snowboard (modo 1)', SportGroup.snow, Icons.snowboarding, outdoor: true),
  SportMode(143, 'Snowboard', 'Snowboard (modo 2)', SportGroup.snow, Icons.snowboarding, outdoor: true),
  SportMode(144, 'AlpineSkiing', 'Esquí alpino', SportGroup.snow, Icons.downhill_skiing, outdoor: true),
  SportMode(145, 'CrossCountrySkiing', 'Esquí de fondo', SportGroup.snow, Icons.downhill_skiing, outdoor: true),
  SportMode(146, 'OrienteeringSki', 'Orientación en esquí', SportGroup.snow, Icons.explore, outdoor: true, idVerified: false),
  SportMode(147, 'Bathlon', 'Biatlón', SportGroup.snow, Icons.downhill_skiing, outdoor: true),
  SportMode(148, 'OutdoorSkating', 'Patinaje al aire libre', SportGroup.snow, Icons.ice_skating, outdoor: true),
  SportMode(149, 'IndoorSkating', 'Patinaje en interior', SportGroup.snow, Icons.ice_skating),
  SportMode(150, 'SnowCar', 'Vehículo de nieve', SportGroup.snow, Icons.sledding, outdoor: true),
  SportMode(151, 'Snowmobile', 'Moto de nieve', SportGroup.snow, Icons.sledding, outdoor: true),
  SportMode(152, 'Snowshoeing', 'Raquetas de nieve', SportGroup.snow, Icons.snowshoeing, outdoor: true),
  SportMode(153, 'HulaHoop', 'Aro (hula hoop)', SportGroup.other, Icons.sports_gymnastics),
  SportMode(154, 'Frisbee', 'Frisbee', SportGroup.other, Icons.sports, outdoor: true),
  SportMode(155, 'Dart', 'Dardos', SportGroup.other, Icons.sports_score),
  SportMode(156, 'FlyAKite', 'Cometa', SportGroup.other, Icons.paragliding, outdoor: true),
  SportMode(157, 'TugOfWar', 'Tira y afloja', SportGroup.other, Icons.sports_kabaddi),
  SportMode(158, 'ShuttlecockKicking', 'Gallito (volante con el pie)', SportGroup.other, Icons.sports, idVerified: false),
  SportMode(159, 'ESports', 'Esports', SportGroup.mind, Icons.sports_esports),
  SportMode(160, 'WanderingMachine', 'Máquina de paseo', SportGroup.walk, Icons.directions_walk),
  SportMode(161, 'Swing', 'Columpio', SportGroup.other, Icons.sports),
  SportMode(162, 'Shuffleboard', 'Shuffleboard', SportGroup.other, Icons.sports_score),
  SportMode(163, 'TableSoccer', 'Futbolín', SportGroup.other, Icons.sports_soccer),
  SportMode(164, 'SomatosensoryGame', 'Juego de movimiento', SportGroup.other, Icons.sports_esports, idVerified: false),
  SportMode(165, 'InternationalChess', 'Ajedrez', SportGroup.mind, Icons.extension),
  SportMode(167, 'Draughts', 'Damas', SportGroup.mind, Icons.extension, idVerified: false),
  SportMode(168, 'Bridge', 'Bridge', SportGroup.mind, Icons.casino),
  SportMode(169, 'BoardGame', 'Juego de mesa', SportGroup.mind, Icons.extension),
  SportMode(170, 'Archery', 'Tiro con arco', SportGroup.other, Icons.sports_score, outdoor: true),
  SportMode(171, 'EquestrianSports', 'Hípica', SportGroup.other, Icons.sports_score, outdoor: true, idVerified: false),
  SportMode(172, 'ClimbingTheStairs', 'Subir escaleras (alternativa)', SportGroup.gym, Icons.stairs),
  SportMode(173, 'Drive', 'Conducción', SportGroup.other, Icons.two_wheeler, outdoor: true),
  SportMode(174, 'SeatedPush', 'Empuje sentado', SportGroup.gym, Icons.fitness_center, idVerified: false),
  SportMode(175, 'SeatedChestPress', 'Press de pecho sentado', SportGroup.gym, Icons.fitness_center),
  SportMode(176, 'Barbell', 'Barra de pesas', SportGroup.gym, Icons.fitness_center),
  SportMode(177, 'LongDistanceRunning', 'Carrera de fondo', SportGroup.run, Icons.directions_run, outdoor: true, idVerified: false),
  SportMode(178, 'FullSpeedRun', 'Carrera a máxima velocidad', SportGroup.run, Icons.directions_run, outdoor: true),
  SportMode(179, 'VariableSpeedRun', 'Carrera con cambios de ritmo', SportGroup.run, Icons.directions_run, outdoor: true),
  SportMode(180, 'RaceRiding', 'Ciclismo de carrera', SportGroup.bike, Icons.directions_bike, outdoor: true),
  SportMode(181, 'MilitaryChess', 'Ajedrez militar', SportGroup.mind, Icons.extension),
  SportMode(182, 'Mahjong', 'Mahjong', SportGroup.mind, Icons.casino),
  SportMode(183, 'Poker', 'Póker', SportGroup.mind, Icons.casino),
  SportMode(184, 'Gobang', 'Gobang', SportGroup.mind, Icons.extension),
  SportMode(185, 'ChineseChess', 'Ajedrez chino', SportGroup.mind, Icons.extension),
  SportMode(186, 'HighJump', 'Salto de altura', SportGroup.run, Icons.sports_score, outdoor: true),
  SportMode(187, 'LongJump', 'Salto de longitud', SportGroup.run, Icons.sports_score, outdoor: true),
  SportMode(188, 'SpinningTop', 'Peonza', SportGroup.other, Icons.sports),
];

final Map<int, SportMode> _byId = {for (final m in sportModes) m.id: m};
final Map<String, SportMode> _byKey = {for (final m in sportModes) m.key: m};

SportMode? sportById(int id) => _byId[id];
SportMode? sportByKey(String key) => _byKey[key];

/// Nombre en español de un `sportType` guardado; desconocido -> «Actividad (n)» (nunca se inventa).
/// true = recorrido (GPS), false = interior, null = tipo desconocido.
bool? sportTracksRoute(int id) => _byId[id]?.tracksRoute;

String sportLabel(int id) => _byId[id]?.name ?? 'Actividad ($id)';
IconData sportIcon(int id) => _byId[id]?.icon ?? Icons.directions_run;

/// Modos agrupados en el orden de [SportGroup]; [query] filtra por nombre sin distinguir mayúsculas ni tildes.
/// [kind]: 0 todos, 1 solo recorrido, 2 solo interior / sin GPS.
Map<SportGroup, List<SportMode>> sportsByGroup({String query = '', int kind = 0}) {
  final q = _fold(query.trim());
  final out = <SportGroup, List<SportMode>>{};
  for (final g in SportGroup.values) {
    final l = [for (final m in sportModes) if (m.group == g && (kind == 0 || (kind == 1) == m.tracksRoute) && (q.isEmpty || _fold(m.name).contains(q))) m];
    if (l.isNotEmpty) out[g] = l;
  }
  return out;
}

String _fold(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ', to = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) { final i = from.indexOf(ch); b.write(i >= 0 ? to[i] : ch); }
  return b.toString();
}

/// Atajos de actividad: los modos que más ha practicado el usuario (por número de sesiones guardadas; a igualdad, el más reciente primero),
/// completados con [defaults] hasta [n]. Los tipos desconocidos (sin modo en la SDK) no se ofrecen. Lógica pura.
List<SportMode> frequentSportModes(Iterable<({int type, DateTime start})> sessions, {int n = 4, List<String> defaults = const ['OUTDOOR_RUNNING', 'OUTDOOR_WALK', 'OUTDOOR_RIDING', 'FITNESS']}) {
  final count = <int, int>{}; final last = <int, DateTime>{};
  for (final s in sessions) { count[s.type] = (count[s.type] ?? 0) + 1; final l = last[s.type]; if (l == null || s.start.isAfter(l)) last[s.type] = s.start; }
  final ids = count.keys.where((t) => _byId[t] != null).toList()
    ..sort((a, b) { final c = count[b]!.compareTo(count[a]!); return c != 0 ? c : last[b]!.compareTo(last[a]!); });
  final out = <SportMode>[for (final t in ids.take(n)) _byId[t]!];
  for (final k in defaults) { if (out.length >= n) break; final m = _byKey[k]; if (m != null && !out.contains(m)) out.add(m); }
  return out;
}

/// ¿La sesión empezó el mismo día natural que [now]? (la pantalla de Actividad solo muestra lo de hoy)
bool startedOnSameDay(DateTime start, DateTime now) => start.year == now.year && start.month == now.month && start.day == now.day;
