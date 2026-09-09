from html.parser import HTMLParser
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path('website')
REQUIRED = [
    ROOT / 'index.html',
    ROOT / 'verify-email' / 'index.html',
    ROOT / 'reset-password' / 'index.html',
    ROOT / 'privacy' / 'index.html',
    ROOT / 'terms' / 'index.html',
    ROOT / '404.html',
    ROOT / 'assets' / 'site.css',
]

for path in REQUIRED:
    assert path.is_file(), f'missing {path}'

config = json.loads(Path('firebase.json').read_text())
hosting = config['hosting']
assert hosting['public'] == 'website'
assert hosting['cleanUrls'] is True
assert hosting['trailingSlash'] is False
assert json.loads(Path('.firebaserc').read_text())['projects']['default'] == 'munib-f5102'

class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.scripts = []
        self._in_script = False
        self._script = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('a', 'link') and attrs.get('href'):
            self.links.append(attrs['href'])
        if tag == 'script' and not attrs.get('src'):
            self._in_script = True
            self._script = []
    def handle_data(self, data):
        if self._in_script:
            self._script.append(data)
    def handle_endtag(self, tag):
        if tag == 'script' and self._in_script:
            self.scripts.append(''.join(self._script))
            self._in_script = False

def resolve(href: str):
    if href.startswith(('http://', 'https://', 'munib://', '#', 'mailto:')):
        return None
    clean = href.split('?', 1)[0].split('#', 1)[0]
    if clean == '/':
        return ROOT / 'index.html'
    if clean.endswith('.css'):
        return ROOT / clean.lstrip('/')
    return ROOT / clean.lstrip('/') / 'index.html'

scripts = []
for html in ROOT.rglob('*.html'):
    parser = Parser()
    parser.feed(html.read_text())
    for href in parser.links:
        target = resolve(href)
        if target is not None:
            assert target.exists(), f'{html}: broken local link {href} -> {target}'
    scripts.extend((html, script) for script in parser.scripts if script.strip())

with tempfile.TemporaryDirectory() as tmp:
    for index, (html, script) in enumerate(scripts):
        js = Path(tmp) / f'{index}.js'
        js.write_text(script)
        result = subprocess.run(['node', '--check', str(js)], capture_output=True, text=True)
        assert result.returncode == 0, f'{html}: JS syntax error\n{result.stderr}'

print(f'Validated {len(list(ROOT.rglob("*.html")))} HTML files and {len(scripts)} inline scripts.')
