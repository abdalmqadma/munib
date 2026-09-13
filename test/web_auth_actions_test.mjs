import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

function inlineScript(path) {
  const html = readFileSync(path, 'utf8');
  const match = html.match(/<script>([\s\S]*?)<\/script>/i);
  assert.ok(match, `No inline script found in ${path}`);
  return match[1];
}

class FakeElement {
  constructor(hidden = false) {
    this.textContent = '';
    this.value = '';
    this.disabled = false;
    this.className = hidden ? 'hidden' : '';
    this.listeners = new Map();
    const classes = new Set(hidden ? ['hidden'] : []);
    this.classList = {
      add: (...names) => names.forEach((name) => classes.add(name)),
      remove: (...names) => names.forEach((name) => classes.delete(name)),
      contains: (name) => classes.has(name),
    };
  }

  addEventListener(type, listener) {
    this.listeners.set(type, listener);
  }
}

function fakeDocument(hiddenIds = []) {
  const elements = new Map();
  const hidden = new Set(hiddenIds);
  return {
    documentElement: { lang: 'ar', dir: 'rtl' },
    title: '',
    getElementById(id) {
      if (!elements.has(id)) {
        elements.set(id, new FakeElement(hidden.has(id)));
      }
      return elements.get(id);
    },
  };
}

function executePage(path, { search, fetchImpl, hiddenIds = [] }) {
  const document = fakeDocument(hiddenIds);
  let replacement = null;
  const location = {
    search,
    replace(value) {
      replacement = value;
    },
  };
  const context = vm.createContext({
    URLSearchParams,
    encodeURIComponent,
    navigator: { language: 'ar' },
    document,
    location,
    fetch: fetchImpl,
    console,
  });

  vm.runInContext(inlineScript(path), context, { filename: path });
  return {
    document,
    location,
    replacement: () => replacement,
  };
}

async function flushAsyncWork() {
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));
}

test('auth-action router preserves Firebase parameters for email verification', () => {
  const page = executePage('website/auth-action/index.html', {
    search: '?mode=verifyEmail&oobCode=verify-code&apiKey=web-key&lang=ar',
  });

  const target = page.replacement();
  assert.ok(target?.startsWith('/verify-email?'));
  assert.match(target, /mode=verifyEmail/);
  assert.match(target, /oobCode=verify-code/);
  assert.match(target, /apiKey=web-key/);
  assert.match(target, /lang=ar/);
});

test('auth-action router preserves Firebase parameters for password reset', () => {
  const page = executePage('website/auth-action/index.html', {
    search: '?mode=resetPassword&oobCode=reset-code&apiKey=web-key&lang=en',
  });

  const target = page.replacement();
  assert.ok(target?.startsWith('/reset-password?'));
  assert.match(target, /mode=resetPassword/);
  assert.match(target, /oobCode=reset-code/);
  assert.match(target, /apiKey=web-key/);
  assert.match(target, /lang=en/);
});

for (const errorCode of ['EXPIRED_OOB_CODE', 'INVALID_OOB_CODE']) {
  test(`reset-password shows invalid state for ${errorCode}`, async () => {
    const page = executePage('website/reset-password/index.html', {
      search: '?mode=resetPassword&oobCode=bad-code&apiKey=web-key',
      hiddenIds: ['reset', 'done', 'invalid'],
      fetchImpl: async () => ({
        ok: false,
        json: async () => ({ error: { message: errorCode } }),
      }),
    });

    await flushAsyncWork();

    assert.equal(
      page.document.getElementById('invalid').classList.contains('hidden'),
      false,
    );
    assert.equal(
      page.document.getElementById('reset').classList.contains('hidden'),
      true,
    );
  });
}

test('reset-password verifies oobCode then confirms the new password', async () => {
  const requests = [];
  const page = executePage('website/reset-password/index.html', {
    search: '?mode=resetPassword&oobCode=valid-code&apiKey=web-key',
    hiddenIds: ['reset', 'done', 'invalid'],
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      if (requests.length === 1) {
        return {
          ok: true,
          json: async () => ({
            email: 'user@example.com',
            requestType: 'PASSWORD_RESET',
          }),
        };
      }
      return { ok: true, json: async () => ({}) };
    },
  });

  await flushAsyncWork();
  assert.equal(
    page.document.getElementById('reset').classList.contains('hidden'),
    false,
  );
  assert.equal(
    page.document.getElementById('accountEmail').textContent,
    'user@example.com',
  );

  page.document.getElementById('password').value = 'StrongPass123';
  page.document.getElementById('confirm').value = 'StrongPass123';
  const submit = page.document.getElementById('resetForm').listeners.get('submit');
  assert.equal(typeof submit, 'function');
  await submit({ preventDefault() {} });

  assert.equal(requests.length, 2);
  const confirmBody = JSON.parse(requests[1].options.body);
  assert.deepEqual(confirmBody, {
    oobCode: 'valid-code',
    newPassword: 'StrongPass123',
  });
  assert.equal(
    page.document.getElementById('done').classList.contains('hidden'),
    false,
  );
});

for (const errorCode of ['EXPIRED_OOB_CODE', 'INVALID_OOB_CODE']) {
  test(`verify-email shows invalid state for ${errorCode}`, async () => {
    const page = executePage('website/verify-email/index.html', {
      search: '?mode=verifyEmail&oobCode=bad-code&apiKey=web-key',
      hiddenIds: ['success', 'invalid'],
      fetchImpl: async () => ({
        ok: false,
        json: async () => ({ error: { message: errorCode } }),
      }),
    });

    await flushAsyncWork();

    assert.equal(
      page.document.getElementById('invalid').classList.contains('hidden'),
      false,
    );
    assert.equal(
      page.document.getElementById('success').classList.contains('hidden'),
      true,
    );
  });
}

test('verify-email reaches success state for a valid action code', async () => {
  const page = executePage('website/verify-email/index.html', {
    search: '?mode=verifyEmail&oobCode=valid-code&apiKey=web-key',
    hiddenIds: ['success', 'invalid'],
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({ emailVerified: true }),
    }),
  });

  await flushAsyncWork();

  assert.equal(
    page.document.getElementById('success').classList.contains('hidden'),
    false,
  );
  assert.equal(
    page.document.getElementById('invalid').classList.contains('hidden'),
    true,
  );
});
