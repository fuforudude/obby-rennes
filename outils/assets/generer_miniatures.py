#!/usr/bin/env python3
"""Génère les sources SVG de la miniature et de l'icône d'Obby Rennes.

Première version seulement : une fois les SVG retouchés à la main (Inkscape,
Figma, éditeur de texte), on NE relance PLUS ce script, on modifie les SVG.
Les SVG de assets/miniatures/ font foi ; ce script ne sert qu'à les produire
la première fois (et à convertir un texte en chemins : voir texte_chemin).

Usage : python3 outils/assets/generer_miniatures.py
Écrit : assets/miniatures/miniature.svg et assets/miniatures/icone.svg
Export PNG : assets apercu assets/miniatures/miniature.svg assets/miniatures/miniature.png --largeur 1920
             assets apercu assets/miniatures/icone.svg assets/miniatures/icone.png --largeur 512
"""
import math
import random
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

RACINE = Path(__file__).resolve().parents[2]
SORTIE = RACINE / "assets" / "miniatures"
POLICE = "C:/Windows/Fonts/impact.ttf"

# Palette du brief
ORANGE = "#FF8C3C"
VIOLET = "#A05AFF"
ROUGE = "#EB323C"
JAUNE = "#FFC81E"
VERT = "#78E628"
ROSE = "#FF50BE"
BLEU = "#28BEFF"
CIEL = "#8CC8FF"
# Compléments
ENCRE = "#1E1646"
POUTRE = "#6A3D20"
VERT_BAC = "#3FB82A"
NEONS = [BLEU, ROSE, JAUNE, VERT, ORANGE, VIOLET]


# ---------------------------------------------------------------- texte -> chemins
_police = TTFont(POLICE)
_cmap = _police.getBestCmap()
_gs = _police.getGlyphSet()
_upm = _police["head"].unitsPerEm
_ha = _police["hmtx"]


def largeur_texte(texte, taille, espace=0.0):
    s = taille / _upm
    return sum(_ha[_cmap[ord(c)]][0] for c in texte) * s + espace * (len(texte) - 1)


def texte_chemin(texte, taille, x, y, espace=0.0):
    """Contours du texte (police Impact) en données de chemin SVG.
    x = centre, y = ligne de base."""
    s = taille / _upm
    larg = largeur_texte(texte, taille, espace)
    cx = x - larg / 2
    pen = SVGPathPen(_gs, ntos=lambda v: f"{v:.1f}")
    for c in texte:
        g = _cmap[ord(c)]
        _gs[g].draw(TransformPen(pen, (s, 0, 0, -s, cx, y)))
        cx += _ha[g][0] * s + espace
    return pen.getCommands()


def etoile4(x, y, r, fill):
    return (f'<path transform="translate({x} {y}) scale({r})" fill="{fill}" '
            f'd="M0,-1 L0.26,-0.26 L1,0 L0.26,0.26 L0,1 L-0.26,0.26 L-1,0 L-0.26,-0.26Z"/>')


# ---------------------------------------------------------------- personnage
def etudiant():
    """Étudiant cartoon cubique, original. Origine = bassin, y vers le bas.
    Haut de la tête à y = -300, pieds vers y = +125."""
    PEAU = "#F2B27C"
    CHEVEUX = "#5A3418"
    JEAN = "#2F6FDB"
    st = f'stroke="{ENCRE}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"'
    return f"""
    <g id="etudiant">
      <g id="sac-a-dos">
        <rect x="-80" y="-168" width="160" height="150" rx="16" fill="{VIOLET}" {st}/>
        <rect x="-80" y="-80" width="160" height="62" rx="12" fill="#8440E0" {st}/>
        <path d="M-30,-168 Q0,-196 30,-168" fill="none" {st}/>
        <circle cx="72" cy="-8" r="9" fill="{JAUNE}" {st}/>
      </g>
      <g id="jambe-gauche" transform="rotate(40 -30 0)">
        <rect x="-52" y="0" width="44" height="104" rx="6" fill="{JEAN}" {st}/>
        <path d="M-58,100 L-2,100 L6,132 L-64,132 Z" fill="#FFFFFF" {st}/>
        <rect x="-64" y="122" width="70" height="12" rx="3" fill="{ROUGE}" {st}/>
      </g>
      <g id="jambe-droite" transform="rotate(-58 30 0)">
        <rect x="8" y="0" width="44" height="78" rx="6" fill="{JEAN}" {st}/>
        <g transform="rotate(88 30 70)">
          <rect x="8" y="70" width="44" height="58" rx="6" fill="{JEAN}" {st}/>
          <path d="M2,124 L58,124 L66,156 L-4,156 Z" fill="#FFFFFF" {st}/>
          <rect x="-4" y="146" width="70" height="12" rx="3" fill="{ROUGE}" {st}/>
        </g>
      </g>
      <g id="torse">
        <rect x="-62" y="-152" width="124" height="156" rx="12" fill="{ORANGE}" {st}/>
        <rect x="-38" y="-62" width="76" height="40" rx="8" fill="#F27526" {st}/>
        <path d="M-12,-152 L-12,-112 M12,-152 L12,-120" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>
        <rect x="-46" y="-152" width="16" height="140" fill="#8440E0" {st}/>
        <rect x="30" y="-152" width="16" height="140" fill="#8440E0" {st}/>
      </g>
      <g id="bras-gauche" transform="rotate(100 -60 -130)">
        <rect x="-80" y="-140" width="36" height="104" rx="8" fill="{ORANGE}" {st}/>
        <rect x="-82" y="-44" width="40" height="34" rx="8" fill="{PEAU}" {st}/>
      </g>
      <g id="copie" transform="translate(150 -262) rotate(14)">
        <rect x="-50" y="-70" width="100" height="136" rx="4" fill="#FFFFFF" {st}/>
        <path d="M-32,-46 H32 M-32,-26 H32 M-32,-6 H20 M-32,14 H32" stroke="#9AA3C7" stroke-width="5" stroke-linecap="round"/>
        <circle cx="12" cy="40" r="19" fill="none" stroke="{ROUGE}" stroke-width="7"/>
        <path d="M2,40 L10,48 L24,30" fill="none" stroke="{ROUGE}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
        <rect x="-8" y="-84" width="16" height="20" rx="3" fill="#C9C9D6" {st}/>
      </g>
      <g id="bras-droit" transform="rotate(-135 60 -130)">
        <rect x="44" y="-140" width="36" height="104" rx="8" fill="{ORANGE}" {st}/>
        <rect x="42" y="-44" width="40" height="34" rx="8" fill="{PEAU}" {st}/>
      </g>
      <g id="tete">
        <rect x="-18" y="-176" width="36" height="30" fill="{PEAU}" {st}/>
        <rect x="-54" y="-282" width="108" height="108" rx="14" fill="{PEAU}" {st}/>
        <g id="cheveux">
          <path d="M-60,-232 L-60,-292 L-34,-316 L-12,-296 L10,-322 L36,-298 L60,-300 L60,-232 L42,-258 L22,-244 L0,-262 L-22,-246 L-42,-260 Z" fill="{CHEVEUX}" {st}/>
        </g>
        <g id="visage">
          <ellipse cx="-24" cy="-230" rx="15" ry="18" fill="#FFFFFF" {st}/>
          <ellipse cx="24" cy="-230" rx="15" ry="18" fill="#FFFFFF" {st}/>
          <circle cx="-19" cy="-229" r="7" fill="{ENCRE}"/>
          <circle cx="29" cy="-229" r="7" fill="{ENCRE}"/>
          <path d="M-42,-250 L-12,-260 M42,-250 L12,-260" stroke="{ENCRE}" stroke-width="7" stroke-linecap="round"/>
          <ellipse cx="0" cy="-196" rx="20" ry="16" fill="#8A1530" {st}/>
          <path d="M-12,-190 Q0,-180 12,-190 Q0,-198 -12,-190Z" fill="{ROSE}"/>
          <circle cx="-42" cy="-208" r="8" fill="#FF8FA3" opacity="0.85"/>
          <circle cx="42" cy="-208" r="8" fill="#FF8FA3" opacity="0.85"/>
        </g>
        <path id="goutte-de-sueur" d="M-70,-260 Q-60,-282 -50,-260 Q-60,-244 -70,-260Z" fill="{BLEU}" stroke="#FFFFFF" stroke-width="3"/>
      </g>
    </g>"""


# ---------------------------------------------------------------- décor
def maison(ident, largeur, etages, toit):
    h_et = 80
    haut_toit = 96 if toit == "pignon" else 26
    corps_h = etages * h_et
    w = largeur
    p = []
    p.append(f'<g id="{ident}">')
    if toit == "pignon":
        p.append(f'<polygon id="toit-gauche" points="-14,{haut_toit} {w/2},0 {w/2},{haut_toit}" fill="#55618A"/>')
        p.append(f'<polygon id="toit-droit" points="{w/2},0 {w+14},{haut_toit} {w/2},{haut_toit}" fill="#46517A"/>')
        p.append(f'<rect x="{w*0.7}" y="8" width="22" height="50" fill="#8D6C5A"/>')
    else:
        p.append(f'<polygon id="toit" points="-10,{haut_toit} 14,2 {w-14},2 {w+10},{haut_toit}" fill="#B5532F"/>')
        p.append(f'<polygon id="toit-ombre" points="{w/2},2 {w-14},2 {w+10},{haut_toit} {w/2},{haut_toit}" fill="#9C4527"/>')
    y0 = haut_toit
    p.append(f'<rect id="facade" x="0" y="{y0}" width="{w}" height="{corps_h}" fill="currentColor"/>')
    # fenêtres et croisillons
    for e in range(etages):
        ya = y0 + e * h_et
        if e == etages - 1:
            # rez-de-chaussée : porte + vitrine
            p.append(f'<path d="M{w/2-24},{ya+h_et} V{ya+26} Q{w/2},{ya+8} {w/2+24},{ya+26} V{ya+h_et}Z" fill="#5A3322"/>')
            p.append(f'<rect x="{w*0.1}" y="{ya+24}" width="{w*0.22}" height="{h_et-34}" fill="#3C5A9A"/>')
            p.append(f'<rect x="{w*0.68}" y="{ya+24}" width="{w*0.22}" height="{h_et-34}" fill="#3C5A9A"/>')
        else:
            for fx in (0.17, 0.62):
                x = w * fx
                p.append(f'<rect x="{x-5}" y="{ya+14}" width="{w*0.21+10:.0f}" height="{h_et-28}" fill="#FFFFFF"/>')
                p.append(f'<rect x="{x}" y="{ya+19}" width="{w*0.21:.0f}" height="{h_et-38}" fill="#3C5A9A"/>')
                p.append(f'<rect x="{x}" y="{ya+19}" width="{w*0.21:.0f}" height="12" fill="#7FB2F0"/>')
                col = ("#2E9E6B", "#E0553D")[e % 2]
                p.append(f'<rect x="{x-14}" y="{ya+19}" width="9" height="{h_et-38}" fill="{col}"/>')
                p.append(f'<rect x="{x+w*0.21+5:.0f}" y="{ya+19}" width="9" height="{h_et-38}" fill="{col}"/>')
    # poutres (colombages)
    b = f'stroke="{POUTRE}" stroke-width="9" stroke-linecap="square" fill="none"'
    p.append(f'<g id="colombages" {b}>')
    for e in range(etages + 1):
        p.append(f'<path d="M0,{y0+e*h_et} H{w}"/>')
    for fx in (0, 0.5, 1):
        p.append(f'<path d="M{w*fx},{y0} V{y0+corps_h}"/>')
    for e in range(etages - 1):
        ya = y0 + e * h_et
        if e % 2 == 0:
            p.append(f'<path d="M0,{ya+h_et} L{w*0.5},{ya} M{w},{ya+h_et} L{w*0.5},{ya}" stroke-width="7"/>')
        else:
            p.append(f'<path d="M{w*0.5},{ya+h_et} L0,{ya} M{w*0.5},{ya+h_et} L{w},{ya}" stroke-width="7"/>')
    p.append("</g></g>")
    return "\n".join(p)


def poubelle():
    st = f'stroke="{ENCRE}" stroke-width="4" stroke-linejoin="round"'
    return f"""
    <g id="poubelle">
      <circle cx="30" cy="150" r="12" fill="#2A2740" {st}/>
      <circle cx="86" cy="150" r="12" fill="#2A2740" {st}/>
      <polygon points="8,42 112,42 102,150 18,150" fill="{VERT_BAC}" {st}/>
      <polygon points="60,42 112,42 102,150 60,150" fill="#2F9A1E"/>
      <path d="M8,42 L112,42 L102,150 L18,150Z" fill="none" {st}/>
      <rect x="18" y="86" width="84" height="14" fill="{JAUNE}" {st}/>
      <rect x="0" y="22" width="120" height="26" rx="8" fill="{JAUNE}" {st}/>
      <path d="M12,30 H108" stroke="#FFE98A" stroke-width="5" stroke-linecap="round"/>
    </g>"""


def sac(x, y, r, couleur="#2C2C3C"):
    return (f'<g><circle cx="{x}" cy="{y}" r="{r}" fill="{couleur}" stroke="{ENCRE}" stroke-width="4"/>'
            f'<path d="M{x-r*0.2},{y-r} L{x},{y-r*1.35} L{x+r*0.25},{y-r}Z" fill="{couleur}" stroke="{ENCRE}" stroke-width="4" stroke-linejoin="round"/>'
            f'<ellipse cx="{x-r*0.35}" cy="{y-r*0.35}" rx="{r*0.22}" ry="{r*0.14}" fill="#FFFFFF" opacity="0.35"/></g>')


def nuage(x, y, s=1.0):
    return f"""<g transform="translate({x} {y}) scale({s})">
      <polygon points="0,64 28,30 78,24 108,0 160,10 186,36 240,46 250,64" fill="#FFFFFF"/>
      <polygon points="0,64 250,64 218,52 130,44 64,54" fill="#D6EBFF"/>
    </g>"""


# ---------------------------------------------------------------- plateformes
def dalle(x, y, w, h, prof, neon, ident=None):
    """Plateforme vue d'en dessous : face avant + sous-face qui rétrécit vers le bas."""
    ret = prof * 0.16
    idat = f' id="{ident}"' if ident else ""
    face = f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{h*0.18:.1f}"/>'
    dessous = (f'<polygon points="{x:.1f},{y+h:.1f} {x+w:.1f},{y+h:.1f} '
               f'{x+w-w*ret/prof*0.5:.1f},{y+h+prof:.1f} {x+w*ret/prof*0.5:.1f},{y+h+prof:.1f}"/>')
    sw = max(3, h * 0.2)
    return f"""<g{idat}>
      <g class="lueur" filter="url(#lueur)" fill="none" stroke="{neon}" stroke-width="{sw*2.2:.1f}" stroke-linejoin="round" opacity="0.9">{face}</g>
      <g fill="#17113F">{dessous}</g>
      <g fill="#2A2060" stroke="{neon}" stroke-width="{sw:.1f}" stroke-linejoin="round">{face}</g>
      <polygon points="{x+4:.1f},{y+h+2:.1f} {x+w-4:.1f},{y+h+2:.1f} {x+w-w*ret/prof*0.5-2:.1f},{y+h+prof-3:.1f} {x+w*ret/prof*0.5+2:.1f},{y+h+prof-3:.1f}" fill="none" stroke="{neon}" stroke-width="{sw*0.45:.1f}" stroke-linejoin="round" opacity="0.8"/>
    </g>"""


def tour_et_spirale():
    CX = 960
    def hw(y):
        return 150 + 80 * y / 1080
    pts = lambda f: f
    out = []
    plats = []
    N = 12
    for i in range(N):
        y = 800 - i * 38
        th = math.radians(20 + i * 68)
        s, c = math.sin(th), math.cos(th)
        echelle = 0.78 + 0.25 * c
        w = 200 * echelle
        h = 26 * echelle
        prof = 36 * echelle
        amp = 270 - (800 - y) * 0.16
        x = CX + amp * s - w / 2
        plats.append((c, dalle(x, y, w, h, prof, NEONS[i % 6], f"balcon-{i+1:02d}")))
    dos = [p for c, p in plats if c <= 0]
    face = [p for c, p in plats if c > 0]
    out.append('<g id="balcons-arriere" opacity="0.92">' + "\n".join(dos) + "</g>")
    # tour
    yb, yh = 1000, -10
    g = (CX - hw(yb), CX + hw(yb), CX - hw(yh), CX + hw(yh))
    tour = [f'<g id="tour">',
            f'<polygon id="tour-face-gauche" points="{g[0]:.0f},{yb} {CX},{yb} {CX},{yh} {g[2]:.0f},{yh}" fill="#9B8CEB"/>',
            f'<polygon id="tour-face-droite" points="{CX},{yb} {g[1]:.0f},{yb} {g[3]:.0f},{yh} {CX},{yh}" fill="#7060CC"/>',
            f'<path d="M{CX},{yh} V{yb}" stroke="#FFFFFF" stroke-width="5" opacity="0.7"/>']
    # bandes d'étages et fenêtres
    fen = ['<g id="fenetres">']
    y = 960
    r = 0
    while y > 20:
        k = hw(y) / 230 * 1.15
        fen.append(f'<path d="M{CX-hw(y):.0f},{y} H{CX+hw(y):.0f}" stroke="#5547AE" stroke-width="3"/>')
        for j, off in enumerate((-160, -96, -32, 32, 96, 160)):
            wx = CX + off * k
            ww = 30 * k
            allume = (r * 3 + j * 5) % 7 == 0
            col = "#FFE9A0" if allume else ("#BFE0FF" if off < 0 else "#8FBCF0")
            fen.append(f'<rect x="{wx-ww/2:.1f}" y="{y-44*k:.1f}" width="{ww:.1f}" height="{30*k:.1f}" rx="3" fill="{col}"/>')
            fen.append(f'<rect x="{wx-ww/2:.1f}" y="{y-44*k:.1f}" width="{ww:.1f}" height="{9*k:.1f}" rx="3" fill="#8FC0F5" opacity="0.7"/>')
        y -= 66
        r += 1
    fen.append("</g>")
    tour += fen + ["</g>"]
    out.append("\n".join(tour))
    out.append('<g id="balcons-avant">' + "\n".join(face) + "</g>")
    return "\n".join(out)


# ---------------------------------------------------------------- éléments divers
def drapeau_breton(x, y, w):
    """Gwenn-ha-du : 9 bandes (5 noires, 4 blanches), canton blanc à 11 hermines.
    (x, y) = coin haut-gauche de l'étoffe."""
    h = w * 2 / 3
    bh = h / 9
    p = [f'<g id="drapeau-breton">']
    p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#FFFFFF"/>')
    for i in range(0, 9, 2):
        p.append(f'<rect x="{x}" y="{y+i*bh:.1f}" width="{w}" height="{bh:.1f}" fill="#111111"/>')
    cant = bh * 5
    p.append(f'<rect id="canton" x="{x}" y="{y}" width="{cant:.1f}" height="{cant:.1f}" fill="#FFFFFF"/>')
    # hermines : 4 + 3 + 4
    positions = []
    for row, n in enumerate((4, 3, 4)):
        for k in range(n):
            px = x + cant * ((k + 0.5) / n if n == 4 else (k + 1) / 4)
            py = y + cant * (0.2 + 0.3 * row)
            positions.append((px, py))
    hs = []
    for px, py in positions:
        hs.append(f'<g transform="translate({px:.1f} {py:.1f})"><path d="M0,-9 Q7,-3 3,2 L5,10 L0,5 L-5,10 L-3,2 Q-7,-3 0,-9Z" fill="#111111"/></g>')
    p.append('<g id="hermines">' + "".join(hs) + "</g>")
    p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" stroke="{ENCRE}" stroke-width="5"/>')
    p.append("</g>")
    return "\n".join(p)


def rame():
    st = f'stroke="{ENCRE}" stroke-width="4" stroke-linejoin="round"'
    return f"""
    <g id="voiture-metro">
      <rect x="0" y="0" width="300" height="104" rx="10" fill="{ROUGE}" {st}/>
      <rect x="0" y="62" width="300" height="14" fill="#FFFFFF"/>
      <rect x="0" y="0" width="300" height="12" fill="#B81E2B"/>
      <g fill="#243B7A" stroke="{ENCRE}" stroke-width="3">
        <rect x="14" y="20" width="48" height="36" rx="4"/><rect x="74" y="20" width="48" height="36" rx="4"/>
        <rect x="134" y="20" width="48" height="36" rx="4"/><rect x="194" y="20" width="48" height="36" rx="4"/>
        <rect x="254" y="20" width="34" height="36" rx="4"/>
      </g>
      <g fill="#7FB2F0" opacity="0.8">
        <rect x="18" y="24" width="40" height="9"/><rect x="78" y="24" width="40" height="9"/>
        <rect x="138" y="24" width="40" height="9"/><rect x="198" y="24" width="40" height="9"/>
      </g>
      <rect x="20" y="96" width="260" height="14" fill="#2A2740" {st}/>
    </g>"""


# ---------------------------------------------------------------- miniature
def miniature():
    rnd = random.Random(7)
    W, H = 1920, 1080
    d = []
    d.append(f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<title>Obby Rennes : Partiel maintenu - miniature</title>
<desc>Miniature 1920x1080 du jeu. Calques nommés (id) : ciel, silhouette-ville, viaduc-metro, maisons, balcons-arriere, tour, balcons-avant, banderole, rue, barricade-poubelles, drapeau-breton, plateformes-saut, etudiant, badge-aura, titre. Les textes sont convertis en chemins (police Impact) : pour les changer, régénérer avec outils/assets/generer_miniatures.py (première version) ou redessiner dans Inkscape.</desc>
<defs>
  <linearGradient id="deg-ciel" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2E96F2"/><stop offset="0.55" stop-color="{CIEL}"/><stop offset="1" stop-color="#E2F3FF"/>
  </linearGradient>
  <radialGradient id="deg-soleil"><stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/><stop offset="0.35" stop-color="#FFF3B0" stop-opacity="0.9"/><stop offset="1" stop-color="#FFF3B0" stop-opacity="0"/></radialGradient>
  <radialGradient id="deg-halo"><stop offset="0" stop-color="#FFF8C8" stop-opacity="0.95"/><stop offset="0.5" stop-color="#FFE98A" stop-opacity="0.45"/><stop offset="1" stop-color="#FFE98A" stop-opacity="0"/></radialGradient>
  <linearGradient id="deg-titre" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF27A"/><stop offset="0.5" stop-color="{JAUNE}"/><stop offset="1" stop-color="{ORANGE}"/>
  </linearGradient>
  <linearGradient id="deg-brume" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0.45"/></linearGradient>
  <filter id="lueur" x="-30%" y="-80%" width="160%" height="260%"><feGaussianBlur stdDeviation="7"/></filter>
  <filter id="ombre" x="-20%" y="-20%" width="140%" height="150%"><feGaussianBlur stdDeviation="9"/></filter>
  {maison("maison-pignon", 230, 3, "pignon")}
  {maison("maison-haute", 210, 4, "plat")}
  {poubelle()}
  {rame()}
</defs>
""")
    # ciel
    d.append('<g id="ciel">')
    d.append(f'<rect width="{W}" height="{H}" fill="url(#deg-ciel)"/>')
    d.append('<circle cx="1790" cy="300" r="190" fill="url(#deg-soleil)"/>')
    d.append('<circle cx="1790" cy="300" r="62" fill="#FFFBE0"/>')
    d.append(nuage(70, 120, 1.0) + nuage(1400, 70, 0.9) + nuage(1580, 360, 0.7) + nuage(30, 330, 0.75) + nuage(640, 400, 0.55))
    d.append('</g>')
    # silhouette ville lointaine
    d.append('<g id="silhouette-ville" fill="#9FCBFA">')
    x = 0
    while x < W:
        w = rnd.randint(70, 150)
        h = rnd.randint(110, 260)
        d.append(f'<rect x="{x}" y="{930-h}" width="{w}" height="{h}"/>')
        if rnd.random() < 0.4:
            d.append(f'<polygon points="{x},{930-h} {x+w/2},{930-h-40} {x+w},{930-h}"/>')
        x += w + rnd.randint(-10, 10)
    # cathédrale (deux tours)
    d.append('<rect x="1238" y="560" width="46" height="370"/><polygon points="1238,560 1261,490 1284,560"/>')
    d.append('<rect x="1300" y="560" width="46" height="370"/><polygon points="1300,560 1323,490 1346,560"/>')
    d.append('</g>')
    # viaduc et métro (à droite)
    d.append('<g id="viaduc-metro">')
    for px in (1240, 1520, 1800):
        d.append(f'<polygon points="{px-46},492 {px+46},492 {px+30},520 {px+30},930 {px-30},930 {px-30},520" fill="#9A96BC"/>')
        d.append(f'<polygon points="{px},492 {px+46},492 {px+30},520 {px+30},930 {px},930" fill="#847FAA"/>')
    d.append('<rect x="1130" y="458" width="800" height="38" fill="#B5B1D4"/><rect x="1130" y="486" width="800" height="10" fill="#8C87B3"/>')
    d.append('<rect x="1130" y="446" width="800" height="12" fill="#6E6A97"/>')
    d.append('<use xlink:href="#voiture-metro" x="1208" y="344"/>')
    d.append('<use xlink:href="#voiture-metro" x="1516" y="344"/>')
    d.append('<use xlink:href="#voiture-metro" x="1824" y="344"/>')
    # nez de la rame, à gauche
    d.append(f'<path d="M1208,344 H1226 L1196,448 H1208Z" fill="{ROUGE}"/>')
    d.append(f'<path d="M1222,356 H1250 V400 H1214Z" fill="#243B7A" stroke="{ENCRE}" stroke-width="3"/>')
    d.append(f'<circle cx="1216" cy="430" r="7" fill="#FFF3A0" stroke="{ENCRE}" stroke-width="2"/>')
    d.append('</g>')
    # maisons (fond)
    d.append('<g id="maisons">')
    d.append(f'<use xlink:href="#maison-pignon" x="-30" y="600" color="#FFF1D6"/>')
    d.append(f'<use xlink:href="#maison-haute" x="190" y="510" color="#FFE0C2"/>')
    d.append(f'<use xlink:href="#maison-pignon" x="415" y="567" color="#EBDDFF" transform="translate(0 0)"/>')
    d.append(f'<g transform="translate(1210 690) scale(0.77)"><use xlink:href="#maison-pignon" color="#D6F2DE"/></g>')
    d.append(f'<g transform="translate(1385 595) scale(0.9)"><use xlink:href="#maison-haute" color="#FFF1D6"/></g>')
    d.append(f'<use xlink:href="#maison-pignon" x="1590" y="600" color="#FFE0C2"/>')
    d.append('</g>')
    d.append('<rect x="0" y="470" width="1920" height="470" fill="url(#deg-brume)" opacity="0.35"/>')
    # tour + balcons
    d.append(tour_et_spirale())
    # banderole (à gauche)
    bt = "NON AUX PARTIELS \u00c0 8H"
    ch = texte_chemin(bt, 50, 0, 18, espace=2)
    lb = largeur_texte(bt, 50, 2) + 70
    d.append(f"""<g id="banderole">
      <g stroke="#3A2A55" stroke-width="7" stroke-linecap="round"><path d="M40,380 V660"/><path d="M{40+lb+40:.0f},362 V640"/></g>
      <g transform="translate(60 392) rotate(-1.8)">
        <path d="M-6,-8 L{lb+12:.0f},-8" stroke="#3A2A55" stroke-width="5"/>
        <path d="M0,0 Q{lb/2:.0f},14 {lb:.0f},0 V92 Q{lb/2:.0f},106 0,92Z" fill="#FFFFFF" stroke="{ENCRE}" stroke-width="5" stroke-linejoin="round"/>
        <path d="M10,8 Q{lb/2:.0f},21 {lb-10:.0f},8" fill="none" stroke="{ROUGE}" stroke-width="5"/>
        <path d="M10,84 Q{lb/2:.0f},98 {lb-10:.0f},84" fill="none" stroke="{ROUGE}" stroke-width="5"/>
        <g transform="translate({lb/2:.0f} 40)"><path id="texte-banderole" transform="translate(0 3)" d="{ch}" fill="{ROUGE}" stroke="{ROUGE}" stroke-width="1"/></g>
      </g>
    </g>""")
    # rue
    d.append('<g id="rue">')
    d.append('<rect x="0" y="925" width="1920" height="160" fill="#5E5B86"/>')
    d.append('<rect x="0" y="925" width="1920" height="14" fill="#8D8AB8"/>')
    for i in range(70):
        cx = rnd.randint(0, 1920)
        cy = rnd.randint(950, 1075)
        w = rnd.randint(40, 100)
        h = rnd.randint(14, 30)
        col = rnd.choice(["#6B6894", "#555279", "#726FA0"])
        d.append(f'<polygon points="{cx},{cy} {cx+w},{cy+4} {cx+w-6},{cy+h} {cx-4},{cy+h-3}" fill="{col}"/>')
    d.append('</g>')
    # barricade de poubelles (à gauche)
    d.append('<g id="barricade-poubelles">')
    d.append('<ellipse cx="230" cy="1040" rx="250" ry="26" fill="#2A2650" opacity="0.5"/>')
    for (x, y, s) in [(30, 800, 1.0), (150, 790, 1.0), (270, 805, 1.0)]:
        d.append(f'<use xlink:href="#poubelle" transform="translate({x} {y}) scale({s})"/>')
    d.append(sac(105, 822, 28) + sac(230, 806, 24, "#3B3B52") + sac(345, 824, 26))
    for (x, y, s) in [(0, 905, 1.1), (130, 920, 1.1), (270, 912, 1.1)]:
        d.append(f'<use xlink:href="#poubelle" transform="translate({x} {y}) scale({s})"/>')
    d.append(sac(80, 930, 30) + sac(205, 936, 24, "#3B3B52") + sac(355, 930, 30))
    d.append('</g>')
    # drapeau breton (à droite, au premier plan)
    d.append(f'<g id="mat-drapeau"><rect x="1622" y="520" width="14" height="520" rx="5" fill="#E8E4F5" stroke="{ENCRE}" stroke-width="5"/><circle cx="1629" cy="516" r="14" fill="{JAUNE}" stroke="{ENCRE}" stroke-width="5"/></g>')
    d.append(f'<g transform="translate(0 0)">' + drapeau_breton(1638, 540, 270) + '</g>')
    # plateformes de saut
    d.append('<g id="plateformes-saut">')
    d.append(dalle(400, 858, 400, 44, 66, BLEU, "plateforme-depart"))
    d.append(dalle(1120, 818, 400, 44, 66, ROSE, "plateforme-arrivee"))
    d.append('</g>')
    # halo derrière le personnage
    d.append('<circle id="halo" cx="960" cy="570" r="300" fill="url(#deg-halo)" opacity="0.5"/>')
    # étudiant
    d.append('<ellipse cx="968" cy="1010" rx="210" ry="22" fill="#2A2650" opacity="0.0"/>')
    d.append(f'<g id="etudiant-saut" transform="translate(955 715) scale(0.92) rotate(-4)">{etudiant()}</g>')
    # étincelles
    d.append('<g id="etincelles">')
    for (x, y, r, c) in [(770, 470, 26, "#FFFFFF"), (1170, 420, 20, JAUNE), (790, 640, 16, JAUNE), (1215, 640, 24, "#FFFFFF"), (880, 360, 14, "#FFFFFF"), (1090, 330, 12, JAUNE)]:
        d.append(etoile4(x, y, r, c))
    d.append('</g>')
    # badge +1000 AURA
    a1 = texte_chemin("+1000", 52, 0, 16)
    a2 = texte_chemin("AURA", 44, 0, 62)
    star = []
    for i in range(20):
        r = 112 if i % 2 == 0 else 88
        an = math.pi * 2 * i / 20
        star.append(f"{r*math.cos(an):.1f},{r*math.sin(an):.1f}")
    d.append(f"""<g id="badge-aura" transform="translate(1385 580) rotate(9)">
      <polygon points="{' '.join(star)}" fill="{ROSE}" stroke="{ENCRE}" stroke-width="7" stroke-linejoin="round"/>
      <circle r="70" fill="none" stroke="#FFFFFF" stroke-width="4" opacity="0.7"/>
      <g stroke="{ENCRE}" stroke-width="9" stroke-linejoin="round" fill="{ENCRE}"><path d="{a1}"/><path d="{a2}"/></g>
      <g fill="#FFFFFF"><path d="{a1}"/></g><g fill="{JAUNE}"><path d="{a2}"/></g>
    </g>""")
    # titre
    t1 = texte_chemin("OBBY RENNES", 262, 960, 244, espace=8)
    t2 = texte_chemin("PARTIEL MAINTENU", 74, 960, 337, espace=5)
    lt2 = largeur_texte("PARTIEL MAINTENU", 74, 5) + 110
    d.append(f"""<g id="titre">
      <g id="titre-obby-rennes">
        <path transform="translate(0 20)" d="{t1}" fill="#5B2BC9" stroke="#5B2BC9" stroke-width="34" stroke-linejoin="round"/>
        <path transform="translate(0 20)" d="{t1}" fill="none" stroke="{ENCRE}" stroke-width="34" stroke-linejoin="round" opacity="0.0"/>
        <path d="{t1}" fill="{ENCRE}" stroke="{ENCRE}" stroke-width="34" stroke-linejoin="round"/>
        <path d="{t1}" fill="url(#deg-titre)"/>
        <path d="{t1}" fill="none" stroke="#FFFFFF" stroke-width="3" opacity="0.55"/>
      </g>
      <g id="bandeau-partiel-maintenu" transform="rotate(-2 960 306)">
        <rect x="{960-lt2/2+10:.0f}" y="272" width="{lt2:.0f}" height="94" rx="12" fill="{ENCRE}" opacity="0.55" transform="translate(0 10)"/>
        <rect x="{960-lt2/2:.0f}" y="262" width="{lt2:.0f}" height="94" rx="12" fill="{ROUGE}" stroke="{ENCRE}" stroke-width="8"/>
        <rect x="{960-lt2/2+10:.0f}" y="272" width="{lt2-20:.0f}" height="74" rx="6" fill="none" stroke="{JAUNE}" stroke-width="4"/>
        <path id="texte-partiel-maintenu" d="{t2}" fill="#FFFFFF" stroke="{ENCRE}" stroke-width="9" stroke-linejoin="round" paint-order="stroke"/>
      </g>
    </g>""")
    d.append("</svg>")
    return "\n".join(d)


# ---------------------------------------------------------------- icône
def icone():
    CX = 256
    d = [f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512" viewBox="0 0 512 512">
<title>Obby Rennes - icone</title>
<desc>Icône d'expérience 512x512. Calques nommés (id) : fond, tour, balcons, plateforme, etudiant, titre. Textes convertis en chemins (police Impact).</desc>
<defs>
  <linearGradient id="deg-fond" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1F8CF0"/><stop offset="0.6" stop-color="#7CC4FF"/><stop offset="1" stop-color="#C9A8FF"/></linearGradient>
  <radialGradient id="deg-halo"><stop offset="0" stop-color="#FFF8C8" stop-opacity="0.95"/><stop offset="0.55" stop-color="#FFE98A" stop-opacity="0.4"/><stop offset="1" stop-color="#FFE98A" stop-opacity="0"/></radialGradient>
  <linearGradient id="deg-titre" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF27A"/><stop offset="0.5" stop-color="{JAUNE}"/><stop offset="1" stop-color="{ORANGE}"/></linearGradient>
  <filter id="lueur" x="-30%" y="-80%" width="160%" height="260%"><feGaussianBlur stdDeviation="4"/></filter>
</defs>
<rect id="fond" width="512" height="512" fill="url(#deg-fond)"/>
<g id="tour">
  <polygon points="170,512 342,512 324,0 188,0" fill="#7060CC"/>
  <polygon points="190,512 {CX},512 {CX},0 206,0" fill="#9B8CEB"/>
  <path d="M{CX},0 V512" stroke="#FFFFFF" stroke-width="4" opacity="0.7"/>
  <g fill="#BFE0FF">"""]
    for y in range(40, 330, 56):
        for dx in (-34, 14):
            d.append(f'<rect x="{CX+dx}" y="{y}" width="20" height="26" rx="3"/>')
    d.append('  </g>\n</g>')
    plats = []
    for i, (y, dx, c) in enumerate([(250, -118, ROSE), (206, 116, BLEU), (160, -112, JAUNE), (116, 110, VERT), (72, -104, ORANGE), (30, 100, VIOLET)]):
        w = 110
        plats.append(dalle(CX + dx - w / 2, y, w, 16, 20, c, f"balcon-{i+1}"))
    d.append('<g id="balcons">' + "".join(plats) + "</g>")
    d.append(f'<g id="etudiant-saut" transform="translate({CX} 230) scale(0.55) rotate(-4)">{etudiant()}</g>')
    for (x, y, r, c) in [(120, 150, 14, "#FFFFFF"), (400, 120, 12, JAUNE), (110, 300, 9, JAUNE), (410, 250, 12, "#FFFFFF")]:
        d.append(etoile4(x, y, r, c))
    t1 = texte_chemin("OBBY", 128, CX, 400, espace=6)
    t2 = texte_chemin("RENNES", 104, CX, 494, espace=5)
    d.append(f"""<g id="titre">
      <g transform="translate(0 9)" fill="#5B2BC9" stroke="#5B2BC9" stroke-width="20" stroke-linejoin="round"><path d="{t1}"/><path d="{t2}"/></g>
      <g fill="{ENCRE}" stroke="{ENCRE}" stroke-width="20" stroke-linejoin="round"><path d="{t1}"/><path d="{t2}"/></g>
      <g fill="url(#deg-titre)"><path d="{t1}"/><path d="{t2}"/></g>
    </g>""")
    d.append("</svg>")
    return "\n".join(d)


if __name__ == "__main__":
    SORTIE.mkdir(parents=True, exist_ok=True)
    (SORTIE / "miniature.svg").write_text(miniature(), encoding="utf-8")
    (SORTIE / "icone.svg").write_text(icone(), encoding="utf-8")
    print("SVG écrits dans", SORTIE)
