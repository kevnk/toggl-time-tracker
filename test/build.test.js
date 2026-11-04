const test = require('node:test');
const assert = require('node:assert/strict');
const coffee = require('coffee-script');
const { read } = require('./harness');

// The page loads the compiled .js files, so they must match their .coffee source.
for (const name of ['main', 'extend-moment']) {
  test(`assets/scripts/${name}.js is the compiled ${name}.coffee (run npm run build)`, () => {
    const compiled = coffee.compile(read(`assets/scripts/${name}.coffee`), { header: true });
    assert.equal(read(`assets/scripts/${name}.js`), compiled);
  });
}
