module.exports = {
    "env": {
        "browser": true,
        "commonjs": true,
        "es2021": true
    },
    "parserOptions": {
        "ecmaVersion": 12
    },
    "rules": {
    },
    "plugins": [
      "mocha"
    ],
    "extends": [
      "eslint:recommended",
      "plugin:mocha/recommended"
  ]
};
