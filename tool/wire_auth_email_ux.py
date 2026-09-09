from html.parser import HTMLParser
from pathlib import Path
import subprocess
import tempfile


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text and old not in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    path.write_text(text.replace(old, new, 1))


auth = Path('lib/presentation/screens/auth_screen.dart')
replace_once(
    auth,
    "              acceptedLegal: acceptedLegal,\n            );",
    "              acceptedLegal: acceptedLegal,\n              emailLanguageCode:\n                  Localizations.localeOf(context).languageCode,\n            );",
    'registration language',
)
replace_once(
    auth,
    "      await _auth.resendVerification();",
    "      await _auth.resendVerification(\n        languageCode: Localizations.localeOf(context).languageCode,\n      );",
    'verification resend language',
)

forgot = Path('lib/presentation/screens/forgot_password_screen.dart')
replace_once(
    forgot,
    "      await _auth.sendPasswordResetEmail(_emailController.text);",
    "      await _auth.sendPasswordResetEmail(\n        _emailController.text,\n        languageCode: Localizations.localeOf(context).languageCode,\n      );",
    'password reset language',
)

reset = Path('website/reset-password/index.html')
replace_once(
    reset,
    "  async function post(url,body){const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await response.json().catch(()=>({}));if(!response.ok)throw new Error(errorCode(data));return data;}",
    "  async function post(url,body,headers={}){const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json',...headers},body:JSON.stringify(body)});const data=await response.json().catch(()=>({}));if(!response.ok)throw new Error(errorCode(data));return data;}",
    'web post locale headers',
)
replace_once(
    reset,
    "try{await post(`https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`,{requestType:'PASSWORD_RESET',email});}",
    "try{await post(`https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`,{requestType:'PASSWORD_RESET',email},{'X-Firebase-Locale':english?'en':'ar'});}",
    'web resend locale',
)


class ScriptParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.scripts = []
        self.in_script = False
        self.current = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'script' and not attrs.get('src'):
            self.in_script = True
            self.current = []

    def handle_data(self, data):
        if self.in_script:
            self.current.append(data)

    def handle_endtag(self, tag):
        if tag == 'script' and self.in_script:
            self.scripts.append(''.join(self.current))
            self.in_script = False


with tempfile.TemporaryDirectory() as tmp:
    for html in [
        Path('website/auth-action/index.html'),
        Path('website/verify-email/index.html'),
        Path('website/reset-password/index.html'),
    ]:
        parser = ScriptParser()
        parser.feed(html.read_text())
        for index, script in enumerate(parser.scripts):
            target = Path(tmp) / f'{html.parent.name}-{index}.js'
            target.write_text(script)
            result = subprocess.run(
                ['node', '--check', str(target)],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                raise SystemExit(f'{html}: JavaScript syntax error\n{result.stderr}')

router = Path('website/auth-action/index.html').read_text()
for required in ["mode === 'verifyEmail'", "mode === 'resetPassword'", '/verify-email', '/reset-password']:
    if required not in router:
        raise SystemExit(f'auth action router missing: {required}')

reset_source = reset.read_text()
for required in ["newPassword: password", "'X-Firebase-Locale':english?'en':'ar'"]:
    if required not in reset_source:
        raise SystemExit(f'reset handler contract missing: {required}')

print('Auth email UX wiring and web JavaScript validation passed.')
