/// Estilos del mapa de fondo de las rutas. Todos son gratuitos y no piden clave: tres vectoriales modernos de OpenFreeMap y tres de teselas
/// ráster (OpenStreetMap, OpenTopoMap y CyclOSM). Se pide la zona que se mira, nunca datos de salud. Lógica pura (sin Flutter).
enum MapStyle {
  modern('Moderno', 'Colorido y limpio, con relieve suave', 'https://tiles.openfreemap.org/styles/liberty'),
  minimal('Minimalista', 'Gris claro: destaca la ruta', 'https://tiles.openfreemap.org/styles/positron'),
  bright('Brillante', 'Calles marcadas y colores vivos', 'https://tiles.openfreemap.org/styles/bright'),
  standard('OpenStreetMap', 'El mapa estándar', null),
  topo('Relieve', 'Curvas de nivel y senderos', null),
  cycle('Ciclismo', 'Carriles bici y rutas', null);

  final String label, hint; final String? styleUri;
  const MapStyle(this.label, this.hint, this.styleUri);

  /// ¿Mapa vectorial (se dibuja en el móvil con un estilo) o de teselas ráster?
  bool get isVector => styleUri != null;

  /// Plantilla de teselas ráster; vacía en los estilos vectoriales.
  String get rasterUrl => switch (this) {
        MapStyle.topo => 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
        MapStyle.cycle => 'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
        MapStyle.standard => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        _ => '',
      };

  /// Zoom máximo de las teselas ráster del servidor.
  int get maxNativeZoom => this == MapStyle.topo ? 17 : 19;

  /// Atribución obligatoria que se muestra siempre sobre el mapa.
  String get attribution => switch (this) {
        MapStyle.modern || MapStyle.minimal || MapStyle.bright => '© OpenFreeMap © OpenMapTiles · datos de OpenStreetMap',
        MapStyle.topo => '© OpenStreetMap · SRTM · OpenTopoMap',
        MapStyle.cycle => '© OpenStreetMap · CyclOSM',
        MapStyle.standard => '© OpenStreetMap',
      };

  /// Estilo del que se parte (y al que vuelve un valor guardado que no existe).
  static const MapStyle byDefault = MapStyle.modern;
  static MapStyle fromIndex(Object? i) => i is int && i >= 0 && i < MapStyle.values.length ? MapStyle.values[i] : byDefault;
}
