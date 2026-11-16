#!/usr/bin/env python3
"""Empacota o PWA num ZIP determinístico para anexar como asset do release.

Conteúdo pronto para soltar na raiz de QUALQUER hospedagem estática HTTPS
(GitHub Pages, Netlify, Vercel, Cloudflare Pages…). Determinístico: nomes
ordenados, timestamp fixo — mesmo input → mesmo zip (hash estável).

Uso: python3 gerador/package_pwa.py   (depois do python3 gerador/build.py)
"""
import json
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
meta = json.loads((REPO / "dados" / "meta.json").read_text(encoding="utf-8"))
VER = meta["version"]
OUT = REPO / f"agency-agents-pwa-v{VER}.zip"

HOWTO = """# Agency Agents — Specialist Guide (PWA)

App instalável e offline: o guia completo dos 283 especialistas como um "aplicativo"
do navegador/sistema (ícone próprio, janela própria, funciona sem internet).

## Como hospedar (EN)

1. Extract this ZIP and upload **all files to the root** of any static HTTPS hosting
   (GitHub Pages, Netlify, Vercel, Cloudflare Pages, your own nginx…). HTTP won't
   install — service workers require HTTPS (localhost also works for dev).
2. Open the site in a browser → use the **Install app** option (address-bar icon, or
   menu → "Install"/"Add to Home Screen").
3. First load caches everything; after that it works fully offline.
4. To update: replace the files with the new release's ZIP. The service worker
   detects the new version and swaps caches automatically (the visitor may need one
   reload).

## Como hospedar (PT-BR)

1. Extraia este ZIP e suba **todos os arquivos para a raiz** de qualquer hospedagem
   estática HTTPS (GitHub Pages, Netlify, Vercel, Cloudflare Pages, seu nginx…).
   HTTP não instala — service worker exige HTTPS (localhost vale para desenvolvimento).
2. Abra o site no navegador → use a opção **Instalar app** (ícone na barra de endereço,
   ou menu → "Instalar"/"Adicionar à tela inicial").
3. O primeiro acesso guarda tudo; depois funciona 100% offline.
4. Para atualizar: troque os arquivos pelo ZIP do release novo. O service worker
   detecta a versão nova e troca os caches sozinho (o visitante pode precisar de
   um reload).

## Files / Arquivos

- `index.html` — the guide (the whole app is this one HTML file)
- `manifest.webmanifest` — app metadata (name, icons, colors)
- `sw.js` — service worker (offline cache, per-version)
- `pwa-icons/` — app icons (any + maskable + Apple touch)

This project is MIT: https://github.com/AtamisFilho/agency-agents-store
"""

# (origem, nome-dentro-do-zip) — origem None = conteúdo da string HOWTO
FILES = [
    (REPO / "index.html", "index.html"),  # atenção: substituído pelo guia real abaixo
    (REPO / "manifest.webmanifest", "manifest.webmanifest"),
    (REPO / "sw.js", "sw.js"),
    (REPO / "pwa-icons" / "icon-192.png", "pwa-icons/icon-192.png"),
    (REPO / "pwa-icons" / "icon-512.png", "pwa-icons/icon-512.png"),
    (REPO / "pwa-icons" / "icon-maskable-512.png", "pwa-icons/icon-maskable-512.png"),
    (REPO / "pwa-icons" / "apple-touch-icon.png", "pwa-icons/apple-touch-icon.png"),
]

entries = []
for src, arc in FILES:
    if arc == "index.html":
        # no zip, o index É o guia (hospedagem raiz já abre o app direto, sem redirect)
        entries.append((REPO / "guia-especialistas-agencia.html", arc))
    else:
        entries.append((src, arc))

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for src, arc in sorted(entries, key=lambda e: e[1]):
        data = src.read_bytes() if src is not None else HOWTO.encode("utf-8")
        if arc == "sw.js":
            # o guia se chama index.html DENTRO do zip: o sw.js precisa pré-cachear
            # e fazer fallback para o entry real (senão: 404 silencioso + fallback morto)
            data = data.replace(b'"./guia-especialistas-agencia.html"', b'"./index.html"')
        zi = zipfile.ZipInfo(arc, date_time=(1980, 1, 1, 0, 0, 0))  # determinístico
        zi.compress_type = zipfile.ZIP_DEFLATED
        zi.create_system = 3        # fixo: determinismo não depende do SO que empacota
        zi.external_attr = 0o644 << 16
        z.writestr(zi, data)
    zi = zipfile.ZipInfo("COMO-HOSPEDAR.md", date_time=(1980, 1, 1, 0, 0, 0))
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.external_attr = 0o644 << 16
    z.writestr(zi, HOWTO)

print(f"{OUT.name} ({OUT.stat().st_size // 1024} KB)")
