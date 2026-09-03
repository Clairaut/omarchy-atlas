// Parsing for `atlas` output. Rich pads columns with runs of 2+ spaces, so that is the field separator.

.pragma library

var GROUPS = [
  { label: "LUMINARIES",    names: ["Sun", "Moon"] },
  { label: "PERSONAL",      names: ["Mercury", "Venus", "Mars"] },
  { label: "SOCIAL",        names: ["Jupiter", "Saturn"] },
  { label: "TRANSPERSONAL", names: ["Uranus", "Neptune", "Pluto"] },
  { label: "POINTS",        names: ["Lilith"] }
];

// Bodies in the order the groups read, which is the order we ask the CLI for.
function requestOrder() {
  var out = [];
  for (var i = 0; i < GROUPS.length; i++)
    for (var j = 0; j < GROUPS[i].names.length; j++)
      out.push(GROUPS[i].names[j].toLowerCase());
  return out;
}

// The one contract both views share with the CLI, and the reason they live together.
function fields(line) {
  return String(line).trim().split(/\s{2,}/).filter(function (f) { return f !== ""; });
}

function isRule(line) {
  return /^[─-╿\s]+$/.test(String(line)) && String(line).trim() !== "";
}

// Illuminated fraction from phase angle. 0 degrees is full, 180 is new.
function illuminated(phaseAngle) {
  return (1 + Math.cos(phaseAngle * Math.PI / 180)) / 2;
}

// ---------------------------------------------------------------------------
// Concise moon line: "☽  ♈︎ 28.71°  🌖︎ 49.93° wan."
// ---------------------------------------------------------------------------

// Sign sits in the field holding a degree mark but no waxing mark, phase in the one holding the waxing mark.
function parseMoon(text) {
  var line = String(text || "").trim().split("\n")[0] || "";
  var f = fields(line);
  if (f.length === 0) return null;

  var out = { glyph: f[0], signGlyph: "", orb: "", angle: -1, waxing: false };

  for (var i = 1; i < f.length; i++) {
    var isPhase = f[i].indexOf("wax.") !== -1 || f[i].indexOf("wan.") !== -1;
    var parts = f[i].split(" ");

    if (isPhase) {
      out.waxing = f[i].indexOf("wax.") !== -1;
      for (var p = 0; p < parts.length; p++) {
        var a = parseFloat(parts[p]);
        if (!isNaN(a)) { out.angle = a; break; }
      }
    } else if (f[i].indexOf("°") !== -1) {
      out.signGlyph = parts[0];
      out.orb = parts.length > 1 ? parts[1] : "";
    }
  }
  return out;
}

// Phase name from illumination and direction, matching how the CLI buckets the cycle.
function phaseName(k, waxing) {
  if (k < 0.02) return "New";
  if (k > 0.98) return "Full";
  var side = waxing ? "Waxing" : "Waning";
  if (k < 0.46) return side + " Crescent";
  if (k < 0.54) return waxing ? "First Quarter" : "Last Quarter";
  return side + " Gibbous";
}

// The phase field moves with which attributes were requested, so find the field carrying the waxing mark.
function parsePhase(text) {
  var line = String(text || "").trim().split("\n")[0] || "";
  var f = fields(line);

  for (var i = 0; i < f.length; i++) {
    if (f[i].indexOf("wax.") === -1 && f[i].indexOf("wan.") === -1) continue;
    var parts = f[i].split(" ");
    for (var j = 0; j < parts.length; j++) {
      var angle = parseFloat(parts[j]);
      if (isNaN(angle)) continue;
      return {
        glyph: parts[0],
        angle: angle,
        waxing: f[i].indexOf("wax.") !== -1
      };
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// `atlas observe` tables
// ---------------------------------------------------------------------------

// Rows are glyph, name, sign glyph, sign name, orb, and with only -a zodiac a 6th field can only be retrograde.
function parseBody(line) {
  var f = fields(line);
  if (f.length < 5) return null;
  if (!/^[-\d]/.test(f[4]) && !/\d/.test(f[4])) return null;
  return {
    glyph: f[0],
    name: f[1],
    signGlyph: f[2],
    signName: f[3],
    orb: f[4],
    retro: f.length > 5 && f[5].indexOf("℞") !== -1
  };
}

// Aspect rows are: aspect glyph, aspect name, "glyph Body", "glyph Body", orb.
function parseAspect(line) {
  var f = fields(line);
  if (f.length < 5) return null;
  var orb = parseFloat(f[4]);
  if (isNaN(orb)) return null;
  return {
    glyph: f[0],
    name: f[1],
    aGlyph: f[2].split(" ")[0],
    aName: f[2].split(" ").slice(1).join(" "),
    bGlyph: f[3].split(" ")[0],
    bName: f[3].split(" ").slice(1).join(" "),
    orb: orb,
    orbText: f[4],
    exact: orb < 1.0
  };
}

// One pass over the combined output: the positions table, then the aspects table after the blank line.
function parseObserve(text) {
  var lines = String(text || "").split("\n");
  var bodies = [];
  var aspects = [];
  var inAspects = false;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.trim() === "" || isRule(line)) continue;

    if (line.indexOf("Aspect") !== -1 && line.indexOf("Orb") !== -1) { inAspects = true; continue; }
    if (line.indexOf("Name") !== -1 && line.indexOf("Sign") !== -1) continue;

    var row = inAspects ? parseAspect(line) : parseBody(line);
    if (row) (inAspects ? aspects : bodies).push(row);
  }

  aspects.sort(function (a, b) { return a.orb - b.orb; });
  return { bodies: bodies, aspects: aspects };
}

function groupedBodies(bodies) {
  var byName = {};
  for (var i = 0; i < bodies.length; i++) byName[bodies[i].name] = bodies[i];

  var out = [];
  for (var g = 0; g < GROUPS.length; g++) {
    var rows = [];
    for (var n = 0; n < GROUPS[g].names.length; n++) {
      var b = byName[GROUPS[g].names[n]];
      if (b) rows.push(b);
    }
    if (rows.length > 0) out.push({ label: GROUPS[g].label, rows: rows });
  }
  return out;
}
