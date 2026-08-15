const globals = require('globals')

module.exports = [
  {
    ignores: ['node_modules/**', 'gen/**', 'coverage/**', 'mta_archives/**', 'app/**/dist/**']
  },
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'commonjs',
      globals: { ...globals.node, ...globals.jest, SELECT: 'readonly', UPDATE: 'readonly' }
    },
    rules: {
      'no-undef': 'error',
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-constant-condition': 'error',
      eqeqeq: ['error', 'always', { null: 'ignore' }],
      curly: ['error', 'all']
    }
  }
]
