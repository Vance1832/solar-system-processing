import processing.event.MouseEvent;

ArrayList<Planet> planets;
ArrayList<Star> stars;
ArrayList<Asteroid> asteroids;
ArrayList<Comet> comets;
ArrayList<CometTrailParticle> cometTrail;

Planet earth;
Planet saturn;
Planet selectedPlanet = null;
Planet hoveredPlanet = null;

float simSpeed = 0.25;   // realistic default
float zoomLevel = 0.42;  // wide default view
boolean paused = false;
boolean showLabels = true;
boolean showOrbits = true;
boolean showAsteroids = true;
boolean infoMode = true;
boolean cinematicMode = false;

int cameraMode = 0; // 0=angled, 1=top, 2=side

float manualRotX = -0.42;
float manualRotY = 0.35;
float autoSpin = 0.0;

boolean draggingView = false;
int lastMouseX, lastMouseY;
boolean movedDrag = false;

float sunScreenX, sunScreenY;

PFont titleFont;
PFont bodyFont;
PFont smallFont;

final int PANEL_W = 340;
final int STAR_COUNT = 450;
final int ASTEROID_COUNT = 220;

void setup() {
  size(1450, 880, P3D);
  pixelDensity(1);
  smooth(8);

  titleFont = createFont("Arial Bold", 22);
  bodyFont = createFont("Arial", 13);
  smallFont = createFont("Arial", 11);

  initStars();
  initPlanets();
  initAsteroids();
  initComets();
}

void draw() {
  background(4, 8, 18);
  drawStars();

  updateHoveredPlanet();

  hint(ENABLE_DEPTH_TEST);
  draw3DScene();

  hint(DISABLE_DEPTH_TEST);
  camera();
  noLights();

  drawSunGlowOverlay();
  drawUIPanel();

  if (showLabels) drawPlanetLabels2D();
  if (selectedPlanet != null) drawSelectedPlanetPopup();
  if (infoMode) drawEducationBanner();

  hint(ENABLE_DEPTH_TEST);
}

// =========================================================
// INITIALIZATION
// =========================================================

void initStars() {
  stars = new ArrayList<Star>();
  for (int i = 0; i < STAR_COUNT; i++) {
    stars.add(new Star(
      random(width - PANEL_W),
      random(height),
      random(1.2, 3.6),
      random(120, 255)
    ));
  }
}

void initPlanets() {
  planets = new ArrayList<Planet>();

  // Spacing scale
  float base = 60;
  float gap = 38;

  // Semi-major axis ratios
  float[] a = {0.39, 0.72, 1.00, 1.52, 5.20, 9.58, 19.2, 30.1};

  // Non-linear spacing for visual clarity
  float[] r = new float[a.length];
  for (int i = 0; i < a.length; i++) {
    float t = pow(a[i], 0.65);
    r[i] = base + t * gap * 6.0;
  }

  // Kepler-inspired angular speed
  float[] w = new float[a.length];
  for (int i = 0; i < a.length; i++) {
    w[i] = 0.06 / sqrt(pow(a[i], 3));
  }

  planets.add(new Planet("Mercury", r[0], 8, color(160, 155, 150), w[0], 0.030,
    "Rocky surface", "No moon", "Fastest orbit", "88 days", "4,880 km"));

  planets.add(new Planet("Venus", r[1], 12, color(210, 170, 90), w[1], 0.022,
    "Thick clouds", "No moon", "Very hot planet", "225 days", "12,104 km"));

  earth = new Planet("Earth", r[2], 13, color(70, 130, 255), w[2], 0.040,
    "Blue oceans", "1 moon", "Habitable world", "365 days", "12,742 km");
  earth.addMoon(new Moon("Moon", 22, 4.2, color(210, 210, 220), 0.12, 0.03));
  planets.add(earth);

  planets.add(new Planet("Mars", r[3], 10, color(220, 100, 70), w[3], 0.035,
    "Dusty red", "Small moons", "Cold desert", "687 days", "6,779 km"));

  planets.add(new Planet("Jupiter", r[4], 27, color(205, 160, 110), w[4], 0.055,
    "Gas giant", "Many moons", "Largest planet", "11.9 years", "139,820 km"));

  saturn = new Planet("Saturn", r[5], 23, color(220, 195, 130), w[5], 0.050,
    "Ring system", "Many moons", "Gas giant", "29.5 years", "116,460 km");
  saturn.hasRing = true;
  planets.add(saturn);

  planets.add(new Planet("Uranus", r[6], 18, color(125, 220, 220), w[6], 0.045,
    "Icy giant", "Tilted axis", "Cold atmosphere", "84 years", "50,724 km"));

  planets.add(new Planet("Neptune", r[7], 17, color(85, 120, 255), w[7], 0.040,
    "Deep blue", "Strong winds", "Outer ice giant", "165 years", "49,244 km"));
}

void initAsteroids() {
  asteroids = new ArrayList<Asteroid>();
  for (int i = 0; i < ASTEROID_COUNT; i++) {
    asteroids.add(new Asteroid(
      random(165, 188),
      random(TWO_PI),
      random(-10, 10),
      random(1.2, 3.0),
      random(0.006, 0.014)
    ));
  }
}

void initComets() {
  cometTrail = new ArrayList<CometTrailParticle>();
  comets = new ArrayList<Comet>();

  comets.add(new Comet(470, -25, 0.008, 0.55, color(200, 235, 255)));
  comets.add(new Comet(520, 30, 0.006, 0.72, color(255, 220, 180)));
  comets.add(new Comet(430, -40, 0.010, 0.40, color(180, 255, 220)));
}

// =========================================================
// 3D SCENE
// =========================================================

void draw3DScene() {
  pushMatrix();
  applyCameraTransform();

  ambientLight(35, 35, 45);
  pointLight(255, 235, 170, 0, 0, 0);
  pointLight(90, 120, 255, -120, -60, 160);

  if (!paused) {
    autoSpin += 0.0025 * simSpeed;

    if (cinematicMode) {
      manualRotY += 0.0016;
      float cinematicBaseZoom = 0.46;
      zoomLevel = cinematicBaseZoom + sin(frameCount * 0.01) * 0.035;
    }

    for (Planet p : planets) p.update(simSpeed);
    if (showAsteroids) {
      for (Asteroid a : asteroids) a.update(simSpeed);
    }
    for (Comet c : comets) {
      c.update(simSpeed);
      c.emitTrail();
    }
    updateCometTrail();
  }

  if (showOrbits) {
    for (Planet p : planets) p.drawOrbit();
    if (showAsteroids) drawAsteroidBandGuide();
  }

  drawSun();
  sunScreenX = screenX(0, 0, 0);
  sunScreenY = screenY(0, 0, 0);

  if (showAsteroids) drawAsteroidBelt();
  drawCometTrail3D();
  for (Comet c : comets) c.display();

  for (Planet p : planets) p.display();

  popMatrix();
}

void applyCameraTransform() {
  float sceneCenterX = (width - PANEL_W) * 0.5;
  float sceneCenterY = height * 0.52;

  translate(sceneCenterX, sceneCenterY, 0);

  // Slight compression for huge system visibility
  scale(zoomLevel * 0.82);

  if (cameraMode == 0) {
    rotateX(manualRotX);
    rotateY(manualRotY + autoSpin);
  } else if (cameraMode == 1) {
    rotateX(-HALF_PI + 0.02);
    rotateY(manualRotY * 0.3);
  } else if (cameraMode == 2) {
    rotateY(HALF_PI + manualRotY * 0.3);
    rotateX(-0.10 + manualRotX * 0.15);
  }
}

void drawSun() {
  pushMatrix();
  noStroke();
  sphereDetail(36);
  emissive(255, 220, 120);
  ambient(255, 200, 80);
  fill(255, 210, 95);
  sphere(42);
  emissive(0, 0, 0);
  popMatrix();
}

void drawSunGlowOverlay() {
  if (Float.isNaN(sunScreenX) || Float.isNaN(sunScreenY)) return;
  if (sunScreenX < 0 || sunScreenX > width - PANEL_W || sunScreenY < 0 || sunScreenY > height) return;

  noStroke();
  blendMode(ADD);
  fill(255, 160, 40, 18);
  ellipse(sunScreenX, sunScreenY, 300, 300);
  fill(255, 180, 60, 24);
  ellipse(sunScreenX, sunScreenY, 220, 220);
  fill(255, 205, 100, 28);
  ellipse(sunScreenX, sunScreenY, 150, 150);
  fill(255, 225, 140, 55);
  ellipse(sunScreenX, sunScreenY, 95, 95);
  blendMode(BLEND);
}

void drawAsteroidBandGuide() {
  pushMatrix();
  rotateX(HALF_PI);
  noFill();
  stroke(100, 100, 120, 60);
  ellipse(0, 0, 350, 350);
  ellipse(0, 0, 382, 382);
  popMatrix();
}

void drawAsteroidBelt() {
  pushStyle();
  noStroke();
  for (Asteroid a : asteroids) a.display();
  popStyle();
}

void updateCometTrail() {
  for (int i = cometTrail.size() - 1; i >= 0; i--) {
    CometTrailParticle p = cometTrail.get(i);
    p.update();
    if (p.dead()) cometTrail.remove(i);
  }
}

void drawCometTrail3D() {
  pushStyle();
  noStroke();
  for (CometTrailParticle p : cometTrail) p.display();
  popStyle();
}

// =========================================================
// HOVER / LABELS / POPUPS
// =========================================================

void updateHoveredPlanet() {
  hoveredPlanet = null;
  float bestDist = 999999;

  for (Planet p : planets) {
    float d = dist(mouseX, mouseY, p.screenXCenter, p.screenYCenter);
    if (d < bestDist && d < p.screenRadius + 10) {
      bestDist = d;
      hoveredPlanet = p;
    }
  }
}

void drawPlanetLabels2D() {
  pushStyle();
  textFont(bodyFont);
  textAlign(CENTER, CENTER);

  for (Planet p : planets) {
    if (p.labelVisible &&
      p.labelX > 10 && p.labelX < width - PANEL_W - 10 &&
      p.labelY > 10 && p.labelY < height - 10) {

      if (selectedPlanet == p) fill(255, 230, 120);
      else if (hoveredPlanet == p) fill(120, 210, 255);
      else fill(255);

      text(p.name, p.labelX, p.labelY);
    }

    if (p == earth && earth.moon != null && earth.moon.labelVisible &&
      earth.moon.labelX > 10 && earth.moon.labelX < width - PANEL_W - 10 &&
      earth.moon.labelY > 10 && earth.moon.labelY < height - 10) {

      fill(220);
      text("Moon", earth.moon.labelX, earth.moon.labelY);
    }
  }

  if (hoveredPlanet != null) {
    noFill();
    stroke(120, 210, 255, 190);
    strokeWeight(2);
    ellipse(hoveredPlanet.screenXCenter, hoveredPlanet.screenYCenter,
      hoveredPlanet.screenRadius * 2.8, hoveredPlanet.screenRadius * 2.8);
  }

  popStyle();
}

void drawSelectedPlanetPopup() {
  if (!selectedPlanet.labelVisible) return;

  float w = 210;
  float h = infoMode ? 122 : 102;
  float x = selectedPlanet.labelX + 18;
  float y = selectedPlanet.labelY - h - 12;

  if (x + w > width - PANEL_W - 10) x = selectedPlanet.labelX - w - 18;
  if (x < 10) x = 10;
  if (y < 10) y = selectedPlanet.labelY + 16;
  if (y + h > height - 10) y = height - h - 10;

  noStroke();
  fill(10, 14, 28, 235);
  rect(x, y, w, h, 12);

  stroke(90, 130, 255, 180);
  strokeWeight(1.5);
  noFill();
  rect(x, y, w, h, 12);
  noStroke();

  fill(255, 230, 120);
  textFont(bodyFont);
  textAlign(LEFT, TOP);
  text(selectedPlanet.name, x + 12, y + 10);

  fill(220);
  text("Surface: " + selectedPlanet.surfaceNote, x + 12, y + 32);
  text("Moons: " + selectedPlanet.moonNote, x + 12, y + 50);
  text("Fact: " + selectedPlanet.factNote, x + 12, y + 68);

  if (infoMode) {
    text("Orbit Period: " + selectedPlanet.orbitPeriodNote, x + 12, y + 88);
    text("Diameter: " + selectedPlanet.sizeNote, x + 12, y + 106);
  }

  stroke(255, 230, 120, 150);
  line(selectedPlanet.labelX, selectedPlanet.labelY - 4, x + 14, y + h);
  noStroke();
}

void drawEducationBanner() {
  float x = 18;
  float y = height - 72;
  float w = 380;
  float h = 46;

  noStroke();
  fill(10, 14, 28, 228);
  rect(x, y, w, h, 12);

  stroke(70, 120, 255, 90);
  noFill();
  rect(x, y, w, h, 12);
  noStroke();

  fill(210);
  textFont(smallFont);
  textAlign(LEFT, TOP);

  if (selectedPlanet != null) {
    text("Education Mode: " + selectedPlanet.name +
      " | Orbit Period: " + selectedPlanet.orbitPeriodNote +
      " | Diameter: " + selectedPlanet.sizeNote,
      x + 12, y + 10, w - 20, h - 10);
  } else {
    text("Education Mode ON: default speed is realistic and the zoom range is widened so Neptune can fit in the full system view.",
      x + 12, y + 10, w - 20, h - 10);
  }
}

// =========================================================
// UI PANEL
// =========================================================

void drawUIPanel() {
  noStroke();
  fill(12, 18, 34, 245);
  rect(width - PANEL_W, 0, PANEL_W, height);

  fill(55, 110, 255, 60);
  rect(width - PANEL_W + 14, 14, PANEL_W - 28, 70, 16);

  fill(245);
  textFont(titleFont);
  textAlign(LEFT, TOP);
  text("3D Solar System", width - PANEL_W + 22, 24);

  fill(170);
  textFont(bodyFont);
  text("Premium Interactive Demo", width - PANEL_W + 22, 54);

  String simulationText =
    "Status: " + (paused ? "Paused" : "Running") + "\n" +
    "Speed: " + nf(simSpeed, 1, 2) + "x (default)\n" +
    "Zoom: " + nf(zoomLevel, 1, 2) + "x wide view\n" +
    "Camera: " + cameraName() + "\n" +
    "Selected: " + (selectedPlanet == null ? "None" : selectedPlanet.name);

  String featuresText =
    "• Cinematic camera mode\n" +
    "• Hover highlight\n" +
    "• Education mode\n" +
    "• Multiple comets\n" +
    "• Asteroid belt\n" +
    "• Popup info near label\n" +
    "• Procedural planet textures\n" +
    "• Mouse orbit + zoom";

  String controlsText =
    "SPACE  pause/resume\n" +
    "UP/DOWN  speed +/-\n" +
    "Mouse wheel  zoom (huge range)\n" +
    "Mouse drag  rotate camera\n" +
    "Mouse click  select planet\n" +
    "1/2/3  camera preset\n" +
    "L  labels on/off\n" +
    "O  orbit lines on/off\n" +
    "B  asteroid belt on/off\n" +
    "I  education mode\n" +
    "C  cinematic mode\n" +
    "R  reset view\n" +
    "P  reset speed";

  drawUIPanelSection("Simulation", 100, simulationText, 128);
  drawUIPanelSection("Features", 246, featuresText, 172);
  drawUIPanelSection("Controls", 438, controlsText, 246);

  fill(70, 120, 255, 220);
  rect(width - PANEL_W + 20, height - 56, PANEL_W - 40, 36, 10);

  fill(255);
  textAlign(CENTER, CENTER);
  text("Processing P3D Solar System", width - PANEL_W / 2, height - 38);
}

void drawUIPanelSection(String title, float y, String content, float h) {
  float x = width - PANEL_W + 20;
  float w = PANEL_W - 40;
  float lineHeight = 18;

  fill(22, 30, 52, 220);
  rect(x - 6, y - 10, w + 12, h, 14);

  fill(240);
  textFont(bodyFont);
  textAlign(LEFT, TOP);
  text(title, x, y);

  fill(180);
  float textY = y + 24;

  String[] lines = split(content, '\n');
  for (String line : lines) {
    text(line, x, textY, w, h - 20);
    textY += lineHeight;
  }
}

String cameraName() {
  if (cameraMode == 0) return cinematicMode ? "Angled + Cinematic" : "Angled";
  if (cameraMode == 1) return "Top View";
  return "Side View";
}

// =========================================================
// STAR BACKGROUND
// =========================================================

void drawStars() {
  noStroke();
  for (Star s : stars) {
    fill(255, 255, 255, s.alpha);
    ellipse(s.x, s.y, s.size, s.size);
  }
}

// =========================================================
// INPUT
// =========================================================

void keyPressed() {
  if (key == ' ') paused = !paused;

  if (keyCode == UP) {
    if (simSpeed < 0.25) simSpeed += 0.05;
    else if (simSpeed < 1.0) simSpeed += 0.10;
    else simSpeed += 0.5;
    simSpeed = min(8.0, simSpeed);
  }

  if (keyCode == DOWN) {
    if (simSpeed <= 0.25) simSpeed -= 0.05;
    else if (simSpeed <= 1.0) simSpeed -= 0.10;
    else simSpeed -= 0.5;
    simSpeed = max(0.0, simSpeed);
  }

  simSpeed = round(simSpeed * 100.0) / 100.0;

  if (key == 'l' || key == 'L') showLabels = !showLabels;
  if (key == 'o' || key == 'O') showOrbits = !showOrbits;
  if (key == 'b' || key == 'B') showAsteroids = !showAsteroids;
  if (key == 'i' || key == 'I') infoMode = !infoMode;
  if (key == 'c' || key == 'C') cinematicMode = !cinematicMode;
  if (key == '1') cameraMode = 0;
  if (key == '2') cameraMode = 1;
  if (key == '3') cameraMode = 2;

  if (key == 'r' || key == 'R') {
    zoomLevel = 0.42;
    cameraMode = 0;
    showLabels = true;
    showOrbits = true;
    manualRotX = -0.42;
    manualRotY = 0.35;
    selectedPlanet = null;
    cinematicMode = false;
  }

  if (key == 'p' || key == 'P') simSpeed = 0.25;
}

void mousePressed() {
  if (mouseX < width - PANEL_W) {
    draggingView = true;
    movedDrag = false;
    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }
}

void mouseDragged() {
  if (draggingView && mouseX < width - PANEL_W) {
    float dx = (mouseX - lastMouseX) * 0.01;
    float dy = (mouseY - lastMouseY) * 0.01;

    if (abs(mouseX - lastMouseX) > 1 || abs(mouseY - lastMouseY) > 1) {
      movedDrag = true;
    }

    manualRotY += dx;
    manualRotX += dy;
    manualRotX = constrain(manualRotX, -1.45, 0.2);

    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }
}

void mouseReleased() {
  if (draggingView && !movedDrag && mouseX < width - PANEL_W) {
    selectPlanetAtMouse();
  }
  draggingView = false;
}

void selectPlanetAtMouse() {
  Planet best = null;
  float bestDist = 999999;

  for (Planet p : planets) {
    float d = dist(mouseX, mouseY, p.screenXCenter, p.screenYCenter);
    if (d < bestDist && d < p.screenRadius + 8) {
      bestDist = d;
      best = p;
    }
  }

  selectedPlanet = best;
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  zoomLevel -= e * 0.05;
  zoomLevel = constrain(zoomLevel, 0.10, 3.4);
}

// =========================================================
// CLASSES
// =========================================================

class Planet {
  String name;
  float orbitRadius;
  float radius;
  int planetColor;
  float orbitSpeed;
  float rotationSpeed;
  float orbitAngle;
  float selfRotation;
  boolean hasRing = false;
  Moon moon;

  String surfaceNote;
  String moonNote;
  String factNote;
  String orbitPeriodNote;
  String sizeNote;

  float labelX, labelY;
  boolean labelVisible = false;
  float screenXCenter, screenYCenter, screenRadius;

  Planet(String name, float orbitRadius, float radius, int planetColor,
    float orbitSpeed, float rotationSpeed,
    String surfaceNote, String moonNote, String factNote,
    String orbitPeriodNote, String sizeNote) {

    this.name = name;
    this.orbitRadius = orbitRadius;
    this.radius = radius;
    this.planetColor = planetColor;
    this.orbitSpeed = orbitSpeed;
    this.rotationSpeed = rotationSpeed;
    this.surfaceNote = surfaceNote;
    this.moonNote = moonNote;
    this.factNote = factNote;
    this.orbitPeriodNote = orbitPeriodNote;
    this.sizeNote = sizeNote;
    this.orbitAngle = random(TWO_PI);
    this.selfRotation = random(TWO_PI);
  }

  void addMoon(Moon moon) {
    this.moon = moon;
  }

  void update(float speedFactor) {
    orbitAngle += orbitSpeed * speedFactor;
    selfRotation += rotationSpeed * speedFactor;
    if (moon != null) moon.update(speedFactor);
  }

  void drawOrbit() {
    pushMatrix();
    rotateX(HALF_PI);
    noFill();
    stroke(100, 120, 170, 120);
    strokeWeight(1);
    ellipse(0, 0, orbitRadius * 2, orbitRadius * 2);
    popMatrix();
  }

  void display() {
    pushMatrix();
    rotateY(orbitAngle);
    translate(orbitRadius, 0, 0);

    screenXCenter = screenX(0, 0, 0);
    screenYCenter = screenY(0, 0, 0);
    float edgeX = screenX(radius, 0, 0);
    screenRadius = abs(edgeX - screenXCenter);

    labelX = screenX(0, radius + 18, 0);
    labelY = screenY(0, radius + 18, 0);
    labelVisible = true;

    pushMatrix();
    rotateY(selfRotation);
    noStroke();
    applyPlanetMaterial();
    sphereDetail(26);
    sphere(radius);
    resetMaterial();
    if (hasRing) drawSaturnRing();
    popMatrix();

    if (moon != null) moon.display();
    popMatrix();
  }

  void applyPlanetMaterial() {
    if (name.equals("Earth")) {
      fill(planetColor);
      ambient(40, 90, 170);
      specular(180, 210, 255);
      shininess(18.0);
      drawProceduralBands(color(30, 160, 80), color(220, 230, 240), 4, 0.18);
    } else if (name.equals("Jupiter")) {
      fill(planetColor);
      ambient(160, 120, 80);
      specular(255, 240, 200);
      shininess(10.0);
      drawProceduralBands(color(230, 200, 150), color(160, 110, 70), 6, 0.15);
    } else if (name.equals("Saturn")) {
      fill(planetColor);
      ambient(150, 125, 70);
      specular(255, 240, 200);
      shininess(10.0);
      drawProceduralBands(color(240, 220, 160), color(170, 140, 90), 5, 0.13);
    } else if (name.equals("Neptune") || name.equals("Uranus")) {
      fill(planetColor);
      ambient((planetColor >> 16) & 0xFF, (planetColor >> 8) & 0xFF, planetColor & 0xFF);
      specular(220, 220, 220);
      shininess(14.0);
      drawProceduralBands(color(180, 240, 255), color((planetColor >> 16) & 0xFF, (planetColor >> 8) & 0xFF, planetColor & 0xFF), 4, 0.08);
    } else {
      fill(planetColor);
      ambient((planetColor >> 16) & 0xFF, (planetColor >> 8) & 0xFF, planetColor & 0xFF);
      specular(220, 220, 220);
      shininess(12.0);
      sphere(radius);
    }
  }

  void drawProceduralBands(int c1, int c2, int count, float alpha) {
    sphere(radius);
    noFill();
    strokeWeight(2);
    for (int i = 0; i < count; i++) {
      float yy = map(i, 0, count - 1, -radius * 0.6, radius * 0.6);
      stroke(lerpColor(c1, c2, i / float(max(1, count - 1))), 255 * alpha);
      pushMatrix();
      translate(0, yy, 0);
      ellipse(0, 0, radius * 1.8, radius * 0.55);
      popMatrix();
    }
    noStroke();
  }

  void resetMaterial() {
    emissive(0, 0, 0);
    ambient(255, 255, 255);
    specular(0, 0, 0);
  }

  void drawSaturnRing() {
    pushMatrix();
    rotateX(1.1);
    noFill();
    stroke(210, 190, 140, 180);
    strokeWeight(3);
    ellipse(0, 0, radius * 3.2, radius * 3.2);
    stroke(180, 165, 120, 130);
    ellipse(0, 0, radius * 2.55, radius * 2.55);
    popMatrix();
  }
}

class Moon {
  String name;
  float orbitRadius;
  float radius;
  int moonColor;
  float orbitSpeed;
  float rotationSpeed;
  float orbitAngle;
  float selfRotation;

  float labelX, labelY;
  boolean labelVisible = false;

  Moon(String name, float orbitRadius, float radius, int moonColor, float orbitSpeed, float rotationSpeed) {
    this.name = name;
    this.orbitRadius = orbitRadius;
    this.radius = radius;
    this.moonColor = moonColor;
    this.orbitSpeed = orbitSpeed;
    this.rotationSpeed = rotationSpeed;
    this.orbitAngle = random(TWO_PI);
    this.selfRotation = random(TWO_PI);
  }

  void update(float speedFactor) {
    orbitAngle += orbitSpeed * speedFactor;
    selfRotation += rotationSpeed * speedFactor;
  }

  void display() {
    pushMatrix();
    rotateY(orbitAngle);
    translate(orbitRadius, 0, 0);

    labelX = screenX(0, radius + 12, 0);
    labelY = screenY(0, radius + 12, 0);
    labelVisible = true;

    rotateY(selfRotation);
    noStroke();
    ambient(180, 180, 185);
    specular(200, 200, 210);
    shininess(8.0);
    fill(moonColor);
    sphereDetail(18);
    sphere(radius);
    popMatrix();
  }
}

class Asteroid {
  float orbitRadius;
  float angle;
  float yOffset;
  float size;
  float speed;
  float rot;

  Asteroid(float orbitRadius, float angle, float yOffset, float size, float speed) {
    this.orbitRadius = orbitRadius;
    this.angle = angle;
    this.yOffset = yOffset;
    this.size = size;
    this.speed = speed;
    this.rot = random(TWO_PI);
  }

  void update(float speedFactor) {
    angle += speed * speedFactor;
    rot += 0.02 * speedFactor;
  }

  void display() {
    pushMatrix();
    rotateY(angle);
    translate(orbitRadius, yOffset, 0);
    rotateY(rot);
    rotateX(rot * 0.7);
    fill(135, 125, 120);
    sphereDetail(6);
    sphere(size);
    popMatrix();
  }
}

class Comet {
  float angle = 0;
  float orbitRadius;
  float speed;
  float yOffset;
  float ellipseScale;
  int cometColor;

  Comet(float orbitRadius, float yOffset, float speed, float ellipseScale, int cometColor) {
    this.orbitRadius = orbitRadius;
    this.yOffset = yOffset;
    this.speed = speed;
    this.ellipseScale = ellipseScale;
    this.cometColor = cometColor;
    this.angle = random(TWO_PI);
  }

  void update(float speedFactor) {
    angle += speed * speedFactor;
  }

  PVector getPosition() {
    float x = cos(angle) * orbitRadius;
    float z = sin(angle) * orbitRadius * ellipseScale;
    return new PVector(x, yOffset, z);
  }

  void emitTrail() {
    PVector p = getPosition();
    cometTrail.add(new CometTrailParticle(p.x, p.y, p.z, cometColor));
    if (cometTrail.size() > 260) cometTrail.remove(0);
  }

  void display() {
    PVector p = getPosition();
    pushMatrix();
    translate(p.x, p.y, p.z);
    noStroke();
    fill(cometColor, 180);
    sphereDetail(12);
    sphere(5);
    popMatrix();
  }
}

class CometTrailParticle {
  float x, y, z;
  float alpha = 180;
  float size = random(2, 5);
  int trailColor;

  CometTrailParticle(float x, float y, float z, int trailColor) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.trailColor = trailColor;
  }

  void update() {
    alpha -= 2.5;
    size *= 0.992;
  }

  void display() {
    pushMatrix();
    translate(x, y, z);
    fill(red(trailColor), green(trailColor), blue(trailColor), alpha);
    sphereDetail(6);
    sphere(size);
    popMatrix();
  }

  boolean dead() {
    return alpha <= 0 || size < 0.5;
  }
}

class Star {
  float x, y, size, alpha;

  Star(float x, float y, float size, float alpha) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.alpha = alpha;
  }
}
