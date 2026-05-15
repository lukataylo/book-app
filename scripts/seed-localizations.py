#!/usr/bin/env python3
"""Add language stubs (and a few hand-translated seeds) to the xcstrings
catalog.

Why a script instead of editing the catalog by hand:
- The catalog has ~280 strings; multiplying by 6 languages is ~1700 entries.
- Xcode 16's auto-translate works fine but doesn't handle our short
  product strings consistently — short UI labels like "Read", "Listen",
  "Settings" benefit from a curated seed for each locale.
- This script can be re-run whenever new keys are added to the catalog;
  it preserves any existing translations and only fills in the gaps.

Usage:  python3 scripts/seed-localizations.py
"""
import json
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "BookApp" / "Resources" / "Localizable.xcstrings"
LOCALES = ["es", "fr", "de", "ja", "zh-Hans", "pt-BR"]

# Curated seed translations for the most user-visible UI chrome. Anything
# not in this map gets stubbed with state="new" + empty value, which Xcode
# surfaces as "needs translation" in its translator UI. A native-speaker
# pass via Crowdin / Lokalise / Fiverr fills the long tail.
#
# Keys here MUST match the English source strings in the catalog exactly.
SEED = {
    "Read":              {"es": "Leer",      "fr": "Lire",      "de": "Lesen",      "ja": "読む",   "zh-Hans": "阅读",     "pt-BR": "Ler"},
    "Speed":             {"es": "Velocidad", "fr": "Vitesse",   "de": "Tempo",      "ja": "速読",   "zh-Hans": "速读",     "pt-BR": "Velocidade"},
    "Listen":            {"es": "Escuchar",  "fr": "Écouter",   "de": "Hören",      "ja": "再生",   "zh-Hans": "聆听",     "pt-BR": "Ouvir"},
    "Settings":          {"es": "Ajustes",   "fr": "Réglages",  "de": "Einstellungen","ja": "設定", "zh-Hans": "设置",     "pt-BR": "Ajustes"},
    "Done":              {"es": "Listo",     "fr": "OK",        "de": "Fertig",     "ja": "完了",   "zh-Hans": "完成",     "pt-BR": "Concluir"},
    "Cancel":            {"es": "Cancelar",  "fr": "Annuler",   "de": "Abbrechen",  "ja": "キャンセル","zh-Hans": "取消",   "pt-BR": "Cancelar"},
    "Save":              {"es": "Guardar",   "fr": "Enregistrer","de": "Speichern", "ja": "保存",   "zh-Hans": "保存",     "pt-BR": "Salvar"},
    "Library":           {"es": "Biblioteca","fr": "Bibliothèque","de": "Bibliothek","ja": "ライブラリ","zh-Hans": "书库",  "pt-BR": "Biblioteca"},
    "Highlight":         {"es": "Resaltar",  "fr": "Surligner", "de": "Markieren",  "ja": "ハイライト","zh-Hans": "高亮",   "pt-BR": "Destacar"},
    "Bookmark":          {"es": "Marcador",  "fr": "Signet",    "de": "Lesezeichen","ja": "ブックマーク","zh-Hans": "书签", "pt-BR": "Favorito"},
    "Bookmarked":        {"es": "Marcado",   "fr": "Marqué",    "de": "Markiert",   "ja": "ブックマーク済み","zh-Hans": "已收藏","pt-BR": "Marcado"},
    "Highlight saved":   {"es": "Resaltado guardado","fr": "Surlignage enregistré","de": "Markierung gespeichert","ja": "ハイライトを保存しました","zh-Hans": "高亮已保存","pt-BR": "Destaque salvo"},
    "Search":            {"es": "Buscar",    "fr": "Rechercher","de": "Suchen",     "ja": "検索",   "zh-Hans": "搜索",     "pt-BR": "Buscar"},
    "Search in book":    {"es": "Buscar en el libro","fr": "Rechercher dans le livre","de": "Im Buch suchen","ja": "本の中を検索","zh-Hans": "在书中搜索","pt-BR": "Buscar no livro"},
    "Search in this book": {"es": "Buscar en este libro","fr": "Rechercher dans ce livre","de": "In diesem Buch suchen","ja": "この本の中を検索","zh-Hans": "在此书中搜索","pt-BR": "Buscar neste livro"},
    "Chapters":          {"es": "Capítulos", "fr": "Chapitres", "de": "Kapitel",    "ja": "章",     "zh-Hans": "章节",     "pt-BR": "Capítulos"},
    "Highlights and bookmarks": {"es": "Resaltados y marcadores","fr": "Surlignages et signets","de": "Markierungen und Lesezeichen","ja": "ハイライトとブックマーク","zh-Hans": "高亮和书签","pt-BR": "Destaques e marcadores"},
    "Theme":             {"es": "Tema",      "fr": "Thème",     "de": "Thema",      "ja": "テーマ","zh-Hans": "主题",     "pt-BR": "Tema"},
    "Light":             {"es": "Claro",     "fr": "Clair",     "de": "Hell",       "ja": "ライト","zh-Hans": "浅色",     "pt-BR": "Claro"},
    "Dark":              {"es": "Oscuro",    "fr": "Sombre",    "de": "Dunkel",     "ja": "ダーク","zh-Hans": "深色",     "pt-BR": "Escuro"},
    "Sepia":             {"es": "Sepia",     "fr": "Sépia",     "de": "Sepia",      "ja": "セピア","zh-Hans": "棕褐",     "pt-BR": "Sépia"},
    "Black":             {"es": "Negro",     "fr": "Noir",      "de": "Schwarz",    "ja": "ブラック","zh-Hans": "纯黑",   "pt-BR": "Preto"},
    "Font":              {"es": "Fuente",    "fr": "Police",    "de": "Schrift",    "ja": "フォント","zh-Hans": "字体",   "pt-BR": "Fonte"},
    "Family":            {"es": "Familia",   "fr": "Famille",   "de": "Familie",    "ja": "ファミリー","zh-Hans": "字族", "pt-BR": "Família"},
    "Layout":            {"es": "Diseño",    "fr": "Mise en page","de": "Layout",   "ja": "レイアウト","zh-Hans": "布局","pt-BR": "Layout"},
    "Margin":            {"es": "Margen",    "fr": "Marge",     "de": "Rand",       "ja": "余白",   "zh-Hans": "页边距",   "pt-BR": "Margem"},
    "Narrow":            {"es": "Estrecho",  "fr": "Étroit",    "de": "Schmal",     "ja": "狭い",   "zh-Hans": "窄",       "pt-BR": "Estreito"},
    "Medium":            {"es": "Medio",     "fr": "Moyen",     "de": "Mittel",     "ja": "標準",   "zh-Hans": "中",       "pt-BR": "Médio"},
    "Wide":              {"es": "Ancho",     "fr": "Large",     "de": "Breit",      "ja": "広い",   "zh-Hans": "宽",       "pt-BR": "Largo"},
    "Line spacing":      {"es": "Interlineado","fr": "Interligne","de": "Zeilenabstand","ja": "行間","zh-Hans": "行距","pt-BR": "Espaçamento de linhas"},
    "Paragraph gap":     {"es": "Espacio entre párrafos","fr": "Écart entre paragraphes","de": "Absatzabstand","ja": "段落間隔","zh-Hans": "段间距","pt-BR": "Espaço entre parágrafos"},
    "Hyphenation":       {"es": "División de palabras","fr": "Coupure des mots","de": "Silbentrennung","ja": "ハイフネーション","zh-Hans": "断字","pt-BR": "Hifenização"},
    "Drop caps at chapter starts": {"es": "Capitulares al inicio de capítulo","fr": "Lettrines en début de chapitre","de": "Initialen am Kapitelanfang","ja": "章の冒頭に大きな先頭文字","zh-Hans": "章节开头使用首字下沉","pt-BR": "Capitulares no início dos capítulos"},
    "Reader settings":   {"es": "Ajustes del lector","fr": "Réglages du lecteur","de": "Reader-Einstellungen","ja": "リーダー設定","zh-Hans": "阅读器设置","pt-BR": "Ajustes do leitor"},
    "Voice settings":    {"es": "Ajustes de voz","fr": "Réglages de voix","de": "Stimmeinstellungen","ja": "音声設定","zh-Hans": "语音设置","pt-BR": "Ajustes de voz"},
    "Voice":             {"es": "Voz",       "fr": "Voix",      "de": "Stimme",     "ja": "音声",   "zh-Hans": "语音",     "pt-BR": "Voz"},
    "Rate":              {"es": "Velocidad", "fr": "Vitesse",   "de": "Tempo",      "ja": "速度",   "zh-Hans": "语速",     "pt-BR": "Velocidade"},
    "Pitch":             {"es": "Tono",      "fr": "Hauteur",   "de": "Tonhöhe",    "ja": "ピッチ","zh-Hans": "音调",     "pt-BR": "Tom"},
    "Volume":            {"es": "Volumen",   "fr": "Volume",    "de": "Lautstärke", "ja": "音量",   "zh-Hans": "音量",     "pt-BR": "Volume"},
    "Sleep timer":       {"es": "Temporizador","fr": "Minuterie","de": "Sleeptimer","ja": "スリープタイマー","zh-Hans": "睡眠定时","pt-BR": "Timer"},
    "Almost done":       {"es": "Casi terminado","fr": "Presque fini","de": "Fast fertig","ja": "もうすぐ終わり","zh-Hans": "即将完成","pt-BR": "Quase no fim"},
    "Continue reading":  {"es": "Continuar leyendo","fr": "Reprendre la lecture","de": "Weiterlesen","ja": "続きを読む","zh-Hans": "继续阅读","pt-BR": "Continuar lendo"},
    "Resume narration":  {"es": "Reanudar narración","fr": "Reprendre la narration","de": "Narration fortsetzen","ja": "ナレーションを再開","zh-Hans": "继续朗读","pt-BR": "Retomar narração"},
    "Pause narration":   {"es": "Pausar narración","fr": "Mettre en pause","de": "Narration pausieren","ja": "ナレーションを一時停止","zh-Hans": "暂停朗读","pt-BR": "Pausar narração"},
    "Next paragraph":    {"es": "Siguiente párrafo","fr": "Paragraphe suivant","de": "Nächster Absatz","ja": "次の段落","zh-Hans": "下一段","pt-BR": "Próximo parágrafo"},
    "Previous paragraph":{"es": "Párrafo anterior","fr": "Paragraphe précédent","de": "Vorheriger Absatz","ja": "前の段落","zh-Hans": "上一段","pt-BR": "Parágrafo anterior"},
    "Read mode":         {"es": "Modo lectura","fr": "Mode lecture","de": "Lesemodus","ja": "読書モード","zh-Hans": "阅读模式","pt-BR": "Modo leitura"},
    "Speed mode":        {"es": "Modo velocidad","fr": "Mode vitesse","de": "Tempomodus","ja": "速読モード","zh-Hans": "速读模式","pt-BR": "Modo velocidade"},
    "Listen mode":       {"es": "Modo escucha","fr": "Mode écoute","de": "Hörmodus","ja": "リスニングモード","zh-Hans": "聆听模式","pt-BR": "Modo escuta"},
    "Hide controls":     {"es": "Ocultar controles","fr": "Masquer les contrôles","de": "Steuerelemente ausblenden","ja": "コントロールを隠す","zh-Hans": "隐藏控件","pt-BR": "Ocultar controles"},
    "AI transformations":{"es": "Transformaciones IA","fr": "Transformations IA","de": "KI-Transformationen","ja": "AI変換","zh-Hans": "AI 变换","pt-BR": "Transformações de IA"},
    "Privacy":           {"es": "Privacidad","fr": "Confidentialité","de": "Datenschutz","ja": "プライバシー","zh-Hans": "隐私","pt-BR": "Privacidade"},
    "Diagnostics":       {"es": "Diagnóstico","fr": "Diagnostics","de": "Diagnose", "ja": "診断",   "zh-Hans": "诊断",     "pt-BR": "Diagnósticos"},
    "About":             {"es": "Acerca de", "fr": "À propos",  "de": "Über",       "ja": "情報",   "zh-Hans": "关于",     "pt-BR": "Sobre"},
    "Version":           {"es": "Versión",   "fr": "Version",   "de": "Version",    "ja": "バージョン","zh-Hans": "版本", "pt-BR": "Versão"},
    "Reading":           {"es": "Lectura",   "fr": "Lecture",   "de": "Lesen",      "ja": "読書",   "zh-Hans": "阅读",     "pt-BR": "Leitura"},
    "Current streak":    {"es": "Racha actual","fr": "Série actuelle","de": "Aktuelle Serie","ja": "現在の連続記録","zh-Hans": "当前连读","pt-BR": "Sequência atual"},
    "This week":         {"es": "Esta semana","fr": "Cette semaine","de": "Diese Woche","ja": "今週","zh-Hans": "本周","pt-BR": "Esta semana"},
    "All time":          {"es": "Histórico", "fr": "Total",     "de": "Gesamt",     "ja": "累計",   "zh-Hans": "全部时间", "pt-BR": "Total"},
    "AI":                {"es": "IA",        "fr": "IA",        "de": "KI",         "ja": "AI",     "zh-Hans": "AI",       "pt-BR": "IA"},
    "Anthropic API key": {"es": "Clave API de Anthropic","fr": "Clé API Anthropic","de": "Anthropic-API-Schlüssel","ja": "Anthropic APIキー","zh-Hans": "Anthropic API 密钥","pt-BR": "Chave de API Anthropic"},
    "Save key":          {"es": "Guardar clave","fr": "Enregistrer la clé","de": "Schlüssel speichern","ja": "キーを保存","zh-Hans": "保存密钥","pt-BR": "Salvar chave"},
    "Stored in Keychain":{"es": "Guardada en Llavero","fr": "Stockée dans le trousseau","de": "Im Schlüsselbund gespeichert","ja": "キーチェーンに保存済み","zh-Hans": "已存储在钥匙串","pt-BR": "Armazenada no Keychain"},
    "On-device model":   {"es": "Modelo en el dispositivo","fr": "Modèle sur l'appareil","de": "Gerätemodell","ja": "オンデバイスモデル","zh-Hans": "设备端模型","pt-BR": "Modelo no dispositivo"},
    "Apple Intelligence":{"es": "Apple Intelligence","fr": "Apple Intelligence","de": "Apple Intelligence","ja": "Apple Intelligence","zh-Hans": "Apple Intelligence","pt-BR": "Apple Intelligence"},
    "Available":         {"es": "Disponible","fr": "Disponible","de": "Verfügbar",  "ja": "利用可能","zh-Hans": "可用",    "pt-BR": "Disponível"},
    "Test on-device model":{"es": "Probar modelo en dispositivo","fr": "Tester le modèle sur l'appareil","de": "Gerätemodell testen","ja": "オンデバイスモデルをテスト","zh-Hans": "测试设备端模型","pt-BR": "Testar modelo no dispositivo"},
    "Testing…":          {"es": "Probando…", "fr": "Test en cours…","de": "Teste…", "ja": "テスト中…","zh-Hans": "测试中…","pt-BR": "Testando…"},
    "Spend this month":  {"es": "Gasto este mes","fr": "Dépenses ce mois-ci","de": "Ausgaben diesen Monat","ja": "今月の利用額","zh-Hans": "本月支出","pt-BR": "Gasto este mês"},
    "Clear diagnostics": {"es": "Borrar diagnósticos","fr": "Effacer les diagnostics","de": "Diagnose löschen","ja": "診断データを消去","zh-Hans": "清除诊断","pt-BR": "Limpar diagnósticos"},
    "Welcome.":          {"es": "Bienvenido.","fr": "Bienvenue.","de": "Willkommen.","ja": "ようこそ。","zh-Hans": "欢迎。","pt-BR": "Bem-vindo."},
    "No matches in this variant.": {"es": "Sin coincidencias en esta variante.","fr": "Aucune correspondance dans cette variante.","de": "Keine Treffer in dieser Variante.","ja": "このバリアントには一致するものがありません。","zh-Hans": "此版本中没有匹配项。","pt-BR": "Sem correspondências nesta versão."},
}

def main() -> int:
    if not CATALOG.exists():
        print(f"Catalog not found: {CATALOG}", file=sys.stderr)
        return 1

    data = json.loads(CATALOG.read_text())
    if "strings" not in data:
        print("Catalog has no 'strings' key", file=sys.stderr)
        return 2

    added = 0
    skipped = 0
    seeded = 0

    for key, entry in data["strings"].items():
        locs = entry.setdefault("localizations", {})
        for locale in LOCALES:
            if locale in locs:
                skipped += 1
                continue
            seed_value = SEED.get(key, {}).get(locale)
            if seed_value is not None:
                locs[locale] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": seed_value
                    }
                }
                seeded += 1
            else:
                # Empty + state=new is the Apple-canonical signal that
                # this string needs translator attention. Xcode renders
                # it with a yellow badge in its translator UI.
                locs[locale] = {
                    "stringUnit": {
                        "state": "new",
                        "value": ""
                    }
                }
                added += 1

    CATALOG.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + "\n")

    total_keys = len(data["strings"])
    print(f"Catalog: {total_keys} keys × {len(LOCALES)} locales")
    print(f"  Seeded with translation: {seeded}")
    print(f"  Stubbed (needs review):  {added}")
    print(f"  Already present (kept):  {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
