const test = require('node:test');
const assert = require('node:assert/strict');
const app = require('./server');
test('health endpoint is registered', () => {
  const routes = app._router.stack.map(layer => layer.route && layer.route.path).filter(Boolean);
  assert.ok(routes.includes('/health'));
});
